function add_period_to_planning_model!(
    model::Model,
    system::System,
    next_system::Union{System, Nothing},
    fixed_cost::Dict,
    investment_cost::Dict,
    om_fixed_cost::Dict
)
    build_period_planning!(model, system, next_system)

    add_feasibility_constraints!(system, model)

    store_and_unregister_costs!(model, system, fixed_cost, investment_cost, om_fixed_cost)
end

function finalize_planning_model_objective!(
    model::Model,
    periods::Vector{System},
    settings::NamedTuple,
    fixed_cost::Dict,
    investment_cost::Dict,
    om_fixed_cost::Dict
)
    model[:eAvailableCapacity] = get_available_capacity(periods)

    period_indices = sort([s.time_data[:Electricity].period_index for s in periods])
    period_lengths = collect(settings.PeriodLengths)
    discount_rate = settings.DiscountRate
    discount_factor = present_value_factor(discount_rate, period_lengths)

    @expression(model, eFixedCostByPeriod[s in period_indices], discount_factor[s] * fixed_cost[s])
    @expression(model, eFixedCost, sum(eFixedCostByPeriod[s] for s in period_indices))

    @expression(model, eInvestmentFixedCostByPeriod[s in period_indices], discount_factor[s] * investment_cost[s])

    @expression(model, eOMFixedCostByPeriod[s in period_indices], discount_factor[s] * om_fixed_cost[s])

    _, number_of_subperiods = get_period_to_subproblem_mapping(periods)
    @expression(model, eLowerBoundOperatingCost[w in 1:number_of_subperiods], AffExpr(0.0))

    @objective(model, Min, model[:eFixedCost])

    return nothing
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
        curr_period = period_index(g)
        g.new_capacity_track[curr_period] = g.new_capacity
        g.retired_capacity_track[curr_period] = g.retired_capacity
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
        curr_period = period_index(e)
        e.new_capacity_track[curr_period] = e.new_capacity
        e.retired_capacity_track[curr_period] = e.retired_capacity
        e.retrofitted_capacity_track[curr_period] = e.retrofitted_capacity
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
