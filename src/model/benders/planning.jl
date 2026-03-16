
function initialize_planning_problem!(case::Case,opt::Dict)
    
    planning_problem = generate_planning_problem(case);

    optimizer = create_optimizer(opt[:solver], opt_env(opt[:solver]), opt[:attributes])

    set_optimizer(planning_problem, optimizer)

    set_silent(planning_problem)

    if case.systems[1].settings.ConstraintScaling
        @info "Scaling constraints and RHS"
        scale_constraints!(planning_problem)
    end

    return planning_problem

end

function generate_planning_problem(case::Case)

    @info("Generating planning problem")

    periods = case.systems
    settings = case.settings

    start_time = time();

    model = Model()

    @variable(model, vREF == 1)

    number_of_periods = length(periods)

    fixed_cost = Dict()
    om_fixed_cost = Dict()
    investment_cost = Dict()

    for (period_idx,system) in enumerate(periods)

        @info(" -- Period $period_idx")

        model[:eFixedCost] = AffExpr(0.0)
        model[:eInvestmentFixedCost] = AffExpr(0.0)
        model[:eOMFixedCost] = AffExpr(0.0)

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

        if period_idx < number_of_periods
            @info(" -- Available capacity in period $(period_idx) is being carried over to period $(period_idx+1)")
            carry_over_capacities!(periods[period_idx+1], system)
        end

        add_feasibility_constraints!(system, model)

        model[:eFixedCost] = model[:eInvestmentFixedCost] + model[:eOMFixedCost]
        fixed_cost[period_idx] = model[:eFixedCost];
        investment_cost[period_idx] = model[:eInvestmentFixedCost];
        om_fixed_cost[period_idx] = model[:eOMFixedCost];
	    unregister(model,:eFixedCost)
        unregister(model,:eInvestmentFixedCost)
        unregister(model,:eOMFixedCost)

    end

    model[:eAvailableCapacity] = get_available_capacity(periods);

    #The settings are the same in all case, we have a single settings file that gets copied into each system struct
    period_lengths = collect(settings.PeriodLengths)

    discount_rate = settings.DiscountRate

    discount_factor = present_value_factor(discount_rate, period_lengths)

    @expression(model, eFixedCostByPeriod[s in 1:number_of_periods], discount_factor[s] * fixed_cost[s])
    @expression(model, eFixedCost, sum(eFixedCostByPeriod[s] for s in 1:number_of_periods))

    @expression(model, eInvestmentFixedCostByPeriod[s in 1:number_of_periods], discount_factor[s] * investment_cost[s])

    @expression(model, eOMFixedCostByPeriod[s in 1:number_of_periods], discount_factor[s] * om_fixed_cost[s])

    _, number_of_subperiods = get_period_to_subproblem_mapping(periods);

    @expression(model, eLowerBoundOperatingCost[w in 1:number_of_subperiods], AffExpr(0.0))

    @objective(model, Min, model[:eFixedCost])

    @info(" -- Planning problem generation complete, it took $(time() - start_time) seconds")

    return model

end

function get_available_capacity(periods::Vector{System})
    
    AvailableCapacity = Dict{Tuple{Symbol,Int64}, Union{JuMPVariable,AffExpr}}();

    for system in periods
        AvailableCapacity = get_available_capacity!(system,AvailableCapacity)
    end

    return AvailableCapacity
end

function get_available_capacity!(system::System, AvailableCapacity::Dict{Tuple{Symbol,Int64}, Union{JuMPVariable,AffExpr}})
    
    for a in system.assets
        get_available_capacity!(a, AvailableCapacity)
    end

    return AvailableCapacity
end

function get_available_capacity!(a::AbstractAsset, AvailableCapacity::Dict{Tuple{Symbol,Int64}, Union{JuMPVariable,AffExpr}})

    for t in fieldnames(typeof(a))
        get_available_capacity!(getfield(a, t), AvailableCapacity)
    end

end

function get_available_capacity!(n::Node, AvailableCapacity::Dict{Tuple{Symbol,Int64}, Union{JuMPVariable,AffExpr}})

    return nothing

end


function get_available_capacity!(g::Transformation, AvailableCapacity::Dict{Tuple{Symbol,Int64}, Union{JuMPVariable,AffExpr}})

    return nothing

end

function get_available_capacity!(g::AbstractStorage, AvailableCapacity::Dict{Tuple{Symbol,Int64}, Union{JuMPVariable,AffExpr}})

    AvailableCapacity[g.id,period_index(g)] = g.capacity;

end


function get_available_capacity!(e::AbstractEdge, AvailableCapacity::Dict{Tuple{Symbol,Int64}, Union{JuMPVariable,AffExpr}})

    AvailableCapacity[e.id,period_index(e)] = e.capacity;

end

function update_with_planning_solution!(case::Case, planning_variable_values::Dict)

    for system in case.systems
        update_with_planning_solution!(system, planning_variable_values)
    end
end

function update_with_planning_solution!(system::System, planning_variable_values::Dict)

    for a in system.assets
        update_with_planning_solution!(a, planning_variable_values)
    end

end
function update_with_planning_solution!(a::AbstractAsset, planning_variable_values::Dict)

    for t in fieldnames(typeof(a))
        update_with_planning_solution!(getfield(a, t), planning_variable_values)
    end

end
function update_with_planning_solution!(n::Node, planning_variable_values::Dict)

    if any(isa.(n.constraints, PolicyConstraint))
        ct_all = findall(isa.(n.constraints, PolicyConstraint))
        for ct in ct_all
            ct_type = typeof(n.constraints[ct])
            variable_ref = copy(n.policy_budgeting_vars[Symbol(string(ct_type) * "_Budget")]);
            n.policy_budgeting_vars[Symbol(string(ct_type) * "_Budget")] = [planning_variable_values[name(variable_ref[w])] for w in subperiod_indices(n)]
        end
    end

end
function update_with_planning_solution!(g::Transformation, planning_variable_values::Dict)

    return nothing

end
function update_with_planning_solution!(g::AbstractStorage, planning_variable_values::Dict)

    if has_capacity(g)
        g.capacity = planning_variable_values[name(g.capacity)]
        g.new_capacity = value(x->planning_variable_values[name(x)], g.new_capacity)
        g.retired_capacity = value(x->planning_variable_values[name(x)], g.retired_capacity)
    end

    if isa(g,LongDurationStorage)
        variable_ref = g.storage_initial;
        g.storage_initial = Dict{Int64,Float64}();
        for r in modeled_subperiods(g)
            g.storage_initial[r] = planning_variable_values[name(variable_ref[r])]
        end
        variable_ref = g.storage_change;
        g.storage_change = Dict{Int64,Float64}();
        for w in subperiod_indices(g)
            g.storage_change[w] = planning_variable_values[name(variable_ref[w])]
        end
    end

end
function update_with_planning_solution!(e::AbstractEdge, planning_variable_values::Dict)
    if has_capacity(e)
        e.capacity = planning_variable_values[name(e.capacity)]
        e.new_capacity = value(x->planning_variable_values[name(x)], e.new_capacity)
        e.retired_capacity = value(x->planning_variable_values[name(x)], e.retired_capacity)
        e.retrofitted_capacity = value(x->planning_variable_values[name(x)], e.retrofitted_capacity)
    end
end

function add_feasibility_constraints!(system::System, model::Model)
    all_storages = get_storages(system)
    for g in all_storages
        if isa(g, LongDurationStorage)
            has_storage_max_level_constraint = any(isa.(g.constraints, MaxStorageLevelConstraint))
            has_storage_min_level_constraint = any(isa.(g.constraints, MinStorageLevelConstraint))
            has_init_storage_max_level_constraint = any(isa.(g.constraints, MaxInitStorageLevelConstraint))
            has_init_storage_min_level_constraint = any(isa.(g.constraints, MinInitStorageLevelConstraint))
            
            if has_storage_max_level_constraint && !has_init_storage_max_level_constraint
                @info("Adding max initial storage level constraint to storage $(id(g)) for feasibility")
                push!(g.constraints,  MaxInitStorageLevelConstraint())
                add_model_constraint!(g.constraints[end], g, model)
            end

            if has_storage_min_level_constraint && !has_init_storage_min_level_constraint
                @info("Adding min initial storage level constraint to storage $(id(g)) for feasibility")
                push!(g.constraints,  MinInitStorageLevelConstraint())
                add_model_constraint!(g.constraints[end], g, model)
            end
        end
    end
    return nothing
end
