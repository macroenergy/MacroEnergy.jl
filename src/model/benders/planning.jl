
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

    cum_years = [sum(period_lengths[i] for i in 1:s-1; init=0) for s in 1:number_of_periods];

    discount_factor = 1 ./ ( (1 + discount_rate) .^ cum_years)

    @expression(model, eFixedCostByPeriod[s in 1:number_of_periods], discount_factor[s] * fixed_cost[s])
    @expression(model, eFixedCost, sum(eFixedCostByPeriod[s] for s in 1:number_of_periods))

    @expression(model, eInvestmentFixedCostByPeriod[s in 1:number_of_periods], discount_factor[s] * investment_cost[s])

    @expression(model, eOMFixedCostByPeriod[s in 1:number_of_periods], discount_factor[s] * om_fixed_cost[s])

    period_to_subproblem_map, subproblem_indices = get_period_to_subproblem_mapping(periods);

    @variable(model, vTHETA[w in subproblem_indices] .>= 0)

    opexmult = [sum([1 / (1 + discount_rate)^(i) for i in 1:period_lengths[s]]) for s in 1:number_of_periods]

    @expression(model, eVariableCostByPeriod[s in 1:number_of_periods], discount_factor[s] * opexmult[s] * sum(vTHETA[w] for w in period_to_subproblem_map[s]))
    @expression(model, eApproximateVariableCost, sum(eVariableCostByPeriod[s] for s in 1:number_of_periods))

    @objective(model, Min, model[:eFixedCost] + model[:eApproximateVariableCost])

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
#### Removing for now, needs more testing  
# function add_feasibility_constraints!(system::System, model::Model)
#     all_edges = edges(system.assets)
#     for n in system.locations
#         if isa(n, Node)
#             if !all(max_supply(n) .== 0)
#                 edges_that_start_from_n = all_edges[findall(start_vertex(e) == n && e.unidirectional == true for e in all_edges)]
#                 @info "Adding feasibility constraints for node $(n.id)"
#                 @constraint(model, sum(capacity(e) for e in edges_that_start_from_n) <= sum(max_supply(n)))    
#             end
#         end
#     end
#     return nothing
# end
