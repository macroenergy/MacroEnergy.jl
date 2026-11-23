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
    set_operating_cost_lower_bounds!(model, periods, settings)

    @objective(model, Min, model[:eFixedCost])

    return nothing
end

"""
Set Benders lower bounds before the solver creates its theta constraints.
By default each bound is `default_operating_cost_lower_bounds`, affine in the planning capacities.
`BendersSettings[:OperatingCostLowerBounds]`, if given, replaces it: it maps period IDs to vectors,
ordered by that period's representative subperiods, of annual weighted operating-cost lower bounds
in original currency, valid for all allowed capacities. User bounds are converted with parameter
scaling, period annuity, and case-start discounting.
"""
function set_operating_cost_lower_bounds!(model::Model, periods::Vector{System}, settings::NamedTuple)
    bounds = get(settings.BendersSettings, :OperatingCostLowerBounds, nothing)
    if isnothing(bounds)
        unbounded = String[]
        default_bounds = default_operating_cost_lower_bounds(periods, settings, unbounded)
        isempty(unbounded) || throw(ArgumentError(
            "Benders cannot bound the operating cost automatically: these negative costs are not limited " *
            "by a CapacityConstraint or a finite max_supply: $(join(unbounded, ", ")). " *
            "Add such a limit or set OperatingCostLowerBounds for every modeled period."))
        for (w, bound) in default_bounds
            model[:eLowerBoundOperatingCost][w] = bound
        end
        return nothing
    end
    bounds isa Union{AbstractDict,NamedTuple} || throw(ArgumentError("OperatingCostLowerBounds must map period IDs to vectors."))
    bounds = Dict(string(k) => v for (k, v) in pairs(bounds))
    mapping, _ = get_period_to_subproblem_mapping(periods)
    factors = present_value_factor(settings.DiscountRate, collect(settings.PeriodLengths))
    scaling = parameter_scaling_factor(settings)
    for system in periods
        p = period_index(system)
        entries = get(bounds, string(p), nothing)
        indices = mapping[p]
        if !(entries isa AbstractVector) || length(entries) != length(indices)
            throw(ArgumentError("OperatingCostLowerBounds period $p requires $(length(indices)) entries."))
        end
        multiplier = factors[p] * present_value_annuity_factor(settings.DiscountRate, settings.PeriodLengths[p]) / scaling^2
        for (w, bound) in zip(indices, entries)
            if !(bound isa Real) || bound isa Bool || !isfinite(bound)
                throw(ArgumentError("OperatingCostLowerBounds period $p contains a non-finite or nonnumeric bound."))
            end
            model[:eLowerBoundOperatingCost][w] = AffExpr(Float64(bound) * multiplier)
        end
    end
    return nothing
end

"""
    default_operating_cost_lower_bounds(periods, settings, unbounded)

Lower bound on each subproblem's discounted operating cost, in model units, keyed by subproblem index.
Only negative unit costs can push the cost below zero: edge flows with `variable_om_cost < flow_credit_rate`,
bounded by `availability × capacity` through a `CapacityConstraint`, and supply segments with a negative
price, bounded by `max_supply`. All other operating cost terms are nonnegative. Components whose negative
cost has no such limit are appended to `unbounded`.
"""
function default_operating_cost_lower_bounds(periods::Vector{System}, settings::NamedTuple, unbounded::Vector{String})
    mapping, _ = get_period_to_subproblem_mapping(periods)
    factors = present_value_factor(settings.DiscountRate, collect(settings.PeriodLengths))
    bounds = Dict{Int64,AffExpr}()
    for system in periods
        p = period_index(system)
        multiplier = factors[p] * present_value_annuity_factor(settings.DiscountRate, settings.PeriodLengths[p])
        # Subproblems use the Electricity subperiods and weights for every commodity (generate_decomposed_system).
        td = system.time_data[:Electricity]
        for (i, w) in enumerate(mapping[p])
            steps = td.subperiods[i]
            weight = multiplier * td.subperiod_weights[td.subperiod_indices[i]]
            bound = AffExpr(0.0)
            for e in get_edges(system)
                # BidirectionalEdge VOM is charged on |flow| and must be nonnegative; credits are rejected.
                unit_cost = e isa BidirectionalEdge ? 0.0 : variable_om_cost(e) - flow_credit_rate(e)
                unit_cost < 0 || continue
                if has_capacity(e) && any(c -> c isa CapacityConstraint, e.constraints)
                    add_to_expression!(bound, weight * unit_cost * sum(availability(e, t) for t in steps), capacity(e))
                else
                    push!(unbounded, string(id(e)))
                end
            end
            for n in get_nodes(system), s in supply_segments(n), t in steps
                price = price_supply(n, s, t)
                price < 0 || continue
                limit = max_supply(n, s, t)
                isfinite(limit) ? add_to_expression!(bound, weight * price * limit) :
                    push!(unbounded, "$(id(n)) supply segment $(supply_segment_name(n, s))")
            end
            bounds[w] = bound
        end
    end
    unique!(unbounded)
    return bounds
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

function get_available_capacity!(::Nothing, AvailableCapacity::Dict{Tuple{Symbol,Int64}, Union{JuMPVariable,AffExpr}})

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

function update_with_planning_solution!(::Nothing, planning_variable_values::Dict)

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
