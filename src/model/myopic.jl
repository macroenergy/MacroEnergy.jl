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

    cum_years = [sum(period_lengths[i] for i in 1:s-1; init=0) for s in 1:num_periods];

    discount_factor = 1 ./ ( (1 + discount_rate) .^ cum_years)

    opexmult = [sum([1 / (1 + discount_rate)^(i) for i in 1:period_lengths[s]]) for s in 1:num_periods]

    for (period_idx,system) in enumerate(periods)
        @info(" -- Generating model for period $(period_idx)")
        model = Model()

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
    
        @expression(model, eFixedCostByPeriod[period_idx], discount_factor[period_idx] * fixed_cost[period_idx])

        @expression(model, eInvestmentFixedCostByPeriod[period_idx], discount_factor[period_idx] * investment_cost[period_idx])

        @expression(model, eOMFixedCostByPeriod[period_idx], discount_factor[period_idx] * om_fixed_cost[period_idx])
    
        @expression(model, eFixedCost, eFixedCostByPeriod[period_idx])
        
        @expression(model, eVariableCostByPeriod[period_idx], discount_factor[period_idx] * opexmult[period_idx] * variable_cost[period_idx])
    
        @expression(model, eVariableCost, eVariableCostByPeriod[period_idx])

        @objective(model, Min, model[:eFixedCost] + model[:eVariableCost])

        @info(" -- Including age-based retirements")
        add_age_based_retirements!.(system.assets, model)

        set_optimizer(model, opt)

        scale_constraints!(system, model)

        optimize!(model)

        if period_idx < num_periods
            @info(" -- Final capacity in period $(period_idx) is being carried over to period $(period_idx+1)")
            carry_over_capacities!(periods[period_idx+1], system, perfect_foresight=false)
        end

        @info(" -- Writing outputs for period $(period_idx)")
        write_period_outputs(output_path, case, system, model, period_idx, num_periods)

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

"""
Write outputs for a single period during myopic iteration.
This function is called for every period to write outputs immediately.
"""
function write_period_outputs(output_path::AbstractString, case::Case, system::System, model::Model, period_idx::Int, num_periods::Int)
    # Create results directory to store outputs for this period
    if num_periods > 1
        results_dir = joinpath(output_path, "results_period_$period_idx")
    else
        results_dir = joinpath(output_path, "results")
    end
    mkpath(results_dir)
    
    # Set up cost expressions before writing cost outputs
    create_discounted_cost_expressions!(model, system, get_settings(case))
    compute_undiscounted_costs!(model, system, get_settings(case))
    
    # Write LP file if requested
    myopic_settings = get_settings(case).MyopicSettings
    if myopic_settings[:WriteModelLP]
        @info(" -- Writing LP file for period $(period_idx)")
        lp_filename = joinpath(results_dir, "model_period_$(period_idx).lp")
        write_to_file(model, lp_filename)
    end
    
    # Scaling factor for variable cost portion of objective function
    discount_scaling = compute_variable_cost_discount_scaling(period_idx, get_settings(case))

    # Write all outputs for this period
    write_outputs(results_dir, system, model, discount_scaling)
end