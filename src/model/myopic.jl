struct MyopicResults
    models::Union{Vector{Model}, Nothing}
end

function run_myopic_iteration!(case::Case, opt::Optimizer)
    periods = get_periods(case)
    num_periods = number_of_periods(case)
    fixed_cost = Dict()
    om_fixed_cost = Dict()
    investment_cost = Dict()
    variable_cost = Dict()
    
    # Get myopic settings from case
    myopic_settings = get_settings(case).MyopicSettings
    return_models = myopic_settings[:ReturnModels]
    
    # Output path for writing results during iteration
    output_path = create_output_path(case.systems[1])
    
    # Only allocate models vector if returning models
    models = return_models ? Vector{Model}(undef, num_periods) : nothing

    period_lengths = collect(get_settings(case).PeriodLengths)

    discount_rate = get_settings(case).DiscountRate

    discount_factor = present_value_factor(discount_rate, period_lengths)

    opexmult = present_value_annuity_factor.(discount_rate, period_lengths)

    if myopic_settings[:Restart][:enabled]
        if myopic_settings[:Restart][:from_period] == 1
            @warn("Restarting from the first period; no previous period to load, proceeding with normal iteration.")
        else
            restart_folder = joinpath(case.systems[1].data_dirpath,myopic_settings[:Restart][:folder])
            restart_period_idx = myopic_settings[:Restart][:from_period]
            @info("Restarting myopic iteration from period $(restart_period_idx) using capacities results in $(restart_folder)")
            capacity_results = Dict{Int,DataFrame}()
            for period_idx in 1:restart_period_idx-1
                capacity_results[period_idx] = load_previous_capacity_results(joinpath(restart_folder, "results_period_$(period_idx)", "capacity.csv"))
            end
            carry_over_capacities!(periods[restart_period_idx], capacity_results,restart_period_idx-1)
        end
    end

    for (period_idx,system) in enumerate(periods)
        if myopic_settings[:Restart][:enabled] && (period_idx < myopic_settings[:Restart][:from_period])
            continue
        end
        
        if period_idx > myopic_settings[:StopAfterPeriod]
            @info("Reached specified period termination at period $(myopic_settings[:StopAfterPeriod]). Ending myopic iteration.")
            break
        end

        @info(" -- Generating model for period $(period_idx)")
        if system.settings.EnableJuMPDirectModel
            model = create_direct_model_with_optimizer(opt)
        else
            model = Model()
            set_optimizer(model, opt)
        end

        set_string_names_on_creation(model,system.settings.EnableJuMPStringNames)

        @variable(model, vREF == 1)

        model[:eFixedCost] = AffExpr(0.0)
        model[:eInvestmentFixedCost] = AffExpr(0.0)
        model[:eOMFixedCost] = AffExpr(0.0)
        model[:eVariableCost] = AffExpr(0.0)

        @info(" -- Adding linking variables")
        add_linking_variables!(system, model) 

        @info(" -- Defining available capacity")
        define_available_capacity!(system, model)

        @info(" -- Generating planning model")
        planning_model!(system, model)

        if system.settings.Retrofitting
            @info(" -- Adding retrofit constraints")
            add_retrofit_constraints!(system, period_idx, model)
        end

        @info(" -- Including age-based retirements")
        add_age_based_retirements!.(system.assets, model)

        @info(" -- Generating operational model")
        operation_model!(system, model)

        # Express myopic cost in present value from perspective of start of modeling horizon, in consistency with Monolithic version

        model[:eFixedCost] = model[:eInvestmentFixedCost] + model[:eOMFixedCost]
        fixed_cost[period_idx] = model[:eFixedCost];
        investment_cost[period_idx] = model[:eInvestmentFixedCost];
        om_fixed_cost[period_idx] = model[:eOMFixedCost];
	    unregister(model,:eFixedCost)
        unregister(model,:eInvestmentFixedCost)
        unregister(model,:eOMFixedCost)
        
        variable_cost[period_idx] = model[:eVariableCost];
        unregister(model,:eVariableCost)
    
        @expression(model, eFixedCostByPeriod[idx in [period_idx]], discount_factor[idx] * fixed_cost[idx])
        @expression(model, eInvestmentFixedCostByPeriod[idx in [period_idx]], discount_factor[idx] * investment_cost[idx])
        @expression(model, eOMFixedCostByPeriod[idx in [period_idx]], discount_factor[idx] * om_fixed_cost[idx])
        @expression(model, eFixedCost, eFixedCostByPeriod[period_idx])
        @expression(model, eVariableCostByPeriod[idx in [period_idx]], discount_factor[idx] * opexmult[idx] * variable_cost[idx])
        @expression(model, eVariableCost, eVariableCostByPeriod[period_idx])
        @objective(model, Min, model[:eFixedCost] + model[:eVariableCost])

        scale_constraints!(system, model)

        optimize!(model)

        if period_idx < num_periods
            @info(" -- Final capacity in period $(period_idx) is being carried over to period $(period_idx+1)")
            carry_over_capacities!(periods[period_idx+1], system, perfect_foresight=false)
        end

        @info(" -- Writing outputs for period $(period_idx)")
        write_outputs_myopic(output_path, case, model, system, period_idx)

        # Store or discard the model based on settings
        if return_models
            models[period_idx] = model
        else
            # Clean up the model to free memory
            model = nothing
            GC.gc()
        end
    end

    @info("Writing settings file")
    write_settings(case, joinpath(output_path, "settings.json"))

    return return_models ? MyopicResults(models) : MyopicResults(nothing)
end

function load_previous_capacity_results(path::AbstractString)
    df = load_dataframe(path)
    if all(["component_id", "capacity", "new_capacity", "retired_capacity"] .∈ Ref(names(df)))
        #### The dataframe has wide format
        return df
    elseif all(["component_id", "variable", "value"] .∈ Ref(names(df)))
        #### The dataframe has long format, reshape to wide
        return reshape_wide(df, :variable, :value)
    else
        error("The capacity results file at $(path) does not have the expected format. It should contain either (component_id, capacity, new_capacity, retired_capacity) columns in wide format or (component_id, variable, value) columns in long format.")
    end
end

function carry_over_capacities!(system::System, prev_results::Dict{Int64,DataFrame}, last_period::Int)

    all_edges = get_edges(system)
    storages = get_storages(system)
    edges_with_capacity = edges_with_capacity_variables(all_edges)
    components_with_capacity = vcat(edges_with_capacity, storages)
    for y in components_with_capacity
        df_restart = prev_results[last_period]
        component_row = findfirst(df_restart.component_id .== String(id(y)))
        if isnothing(component_row)
            @info("Skipping component $(id(y)) as it was not present in the previous period")
        else
            y.existing_capacity = df_restart.capacity[component_row]
            for prev_period in keys(prev_results)
                df = prev_results[prev_period];
                component_row = findfirst(df.component_id .== String(id(y)))
                if !isnothing(component_row)
                    y.new_capacity_track[prev_period] = df.new_capacity[component_row]
                    y.retired_capacity_track[prev_period] = df.retired_capacity[component_row]
                    if isa(y, AbstractEdge) && "retrofitted_capacity" ∈ names(df)
                        y.retrofitted_capacity_track[prev_period] = df.retrofitted_capacity[component_row]
                    end
                end
            end
        end
    end
end
