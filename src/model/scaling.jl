parameter_scaling_factor(settings::NamedTuple) = settings.ParameterScaling ? Float64(settings.ParameterScalingFactor) : 1.0

# ------------------------------------------------------------------------------
# Parameter scaling of model inputs.
#
# For numerical conditioning we divide the extensive input parameters (costs and
# quantities) by the scaling factor `S` *before* building the model, so the
# solver works with well-scaled variables (which come out divided by `S`) and a
# well-scaled objective (divided by `S^2`). The output writers undo this
# (quantities x S, costs x S^2, duals x S). After the run we multiply the same
# fields back by `S` so the in-memory System (and any JSON re-serialization) is
# returned to the user in original units.
#
#   scale!(x, S)   divides the scalable fields by S   (factor = 1/S)
#   unscale!(x, S) multiplies them back by S          (factor = S)
#
# Both directions share a single `scalable_fields` source of truth, so the lists
# can never drift apart. When `S == 1.0` (scaling disabled) both are no-ops.
# ------------------------------------------------------------------------------

scale!(case::Case) = scale!(case, parameter_scaling_factor(get_settings(case)))
unscale!(case::Case) = unscale!(case, parameter_scaling_factor(get_settings(case)))
# `S` may arrive as an Int (e.g. `ParameterScalingFactor` parsed from JSON), so
# accept any `Real` and convert to Float64 at the boundary.
scale!(case::Case, S::Real) = scale!(get_periods(case), S)
unscale!(case::Case, S::Real) = unscale!(get_periods(case), S)

scale!(systems::Vector{System}, S::Real) = _apply_scaling!(systems, 1.0 / S, Float64(S))
unscale!(systems::Vector{System}, S::Real) = _apply_scaling!(systems, Float64(S), Float64(S))
scale!(system::System, S::Real) = _apply_scaling!([system], 1.0 / S, Float64(S))
unscale!(system::System, S::Real) = _apply_scaling!([system], Float64(S), Float64(S))

function _apply_scaling!(systems::Vector{System}, factor::Float64, S::Float64)
    S == 1.0 && return nothing
    # `visited` guards against scaling a shared object twice (e.g. storage
    # sub-edges, or a node referenced from multiple places).
    visited = Set{UInt64}()
    for system in systems
        for e in get_edges(system)
            _scale_object!(e, factor, visited)
        end
        for g in get_storages(system)
            _scale_object!(g, factor, visited)
        end
        for n in get_nodes(system)
            _scale_object!(n, factor, visited)
        end
    end
    return nothing
end

# Scale the scalar numeric fields of an edge or storage. Only fields whose value
# is currently a `Real` are touched: this skips `nothing`/`missing` (e.g. an
# unset `annualized_investment_cost` or `wacc`) and any `AffExpr`/JuMP variable
# (e.g. `existing_capacity` after perfect-foresight carry-over).
function _scale_object!(y::Union{AbstractEdge,AbstractStorage}, factor::Float64, visited::Set{UInt64})
    objectid(y) in visited && return nothing
    push!(visited, objectid(y))
    for f in scalable_fields(y)
        hasfield(typeof(y), f) || continue
        v = getfield(y, f)
        v isa Real && setfield!(y, f, v * factor)
    end
    return nothing
end

function _scale_object!(n::Node, factor::Float64, visited::Set{UInt64})
    objectid(n) in visited && return nothing
    push!(visited, objectid(n))
    for f in (:demand, :price, :price_nsd)
        v = getfield(n, f)
        v isa AbstractVector && (v .*= factor)
    end
    _scale_dict_values!(n.price_unmet_policy, factor)
    _scale_dict_values!(n.rhs_policy, factor)
    for seg in values(n.supply)
        _scale_object!(seg, factor)
    end
    return nothing
end

# Supply segments are scaled in place (the struct is immutable but its vectors
# are not). They are reached only via their owning node, so no visited guard.
function _scale_object!(seg::SupplySegment, factor::Float64)
    seg.price .*= factor   # cost coefficient
    seg.min .*= factor     # absolute lower bound on supply flow
    seg.max .*= factor     # absolute upper bound (Inf * factor == Inf)
    return nothing
end

function _scale_dict_values!(d::AbstractDict, factor::Float64)
    for k in keys(d)
        v = d[k]
        v isa Real && (d[k] = v * factor)
    end
    return nothing
end

# Definitive scalable-field lists. Cost coefficients and extensive quantities are
# scaled; dimensionless quantities (fractions, durations, lifetimes, rates,
# efficiencies) are not.
# Note: derived fields are intentionally NOT listed here. They are recomputed by
# `prepare_case!` (which runs after `scale!`) from the already-scaled raw inputs,
# so they inherit the scaling automatically:
#   - `pv_period_*` / `cf_period_*` (from investment/O&M costs)
#   - `min_retired_capacity_track` (cumulative sum of the scaled
#     `min_retired_capacity` across periods; never a user input)
# `annualized_investment_cost` IS listed because it can be supplied directly by
# the user (otherwise it is `nothing` at scale! time and the guard skips it).
# `startup_cost` is a base attribute of every edge (not only `EdgeWithUC`). It is
# scaled like the other cost coefficients: the unit-commitment startup term is
# `startup_cost * capacity_size * ustart` with `ustart` an unscaled
# integer, so scaling both `startup_cost` and `capacity_size` by 1/S makes that
# term ~1/S^2, consistent with the other cost terms.
const _EDGE_SCALABLE_FIELDS = Symbol[
    :capacity_size, :existing_capacity, :max_capacity, :min_capacity,
    :max_new_capacity, :min_retired_capacity,
    :investment_cost, :fixed_om_cost, :variable_om_cost, :annualized_investment_cost,
    :startup_cost,
]
# Storage shares the cost/capacity attributes with edges EXCEPT `startup_cost`,
# which is a unit-commitment (edge-only) concept and is not a Storage field.
const _STORAGE_SCALABLE_FIELDS = Symbol[
    :capacity_size, :existing_capacity, :max_capacity, :min_capacity,
    :max_new_capacity, :min_retired_capacity,
    :investment_cost, :fixed_om_cost, :variable_om_cost, :annualized_investment_cost,
]

scalable_fields(::AbstractEdge) = _EDGE_SCALABLE_FIELDS
scalable_fields(::AbstractStorage) = _STORAGE_SCALABLE_FIELDS

# MacroEnergyScaling.scale_constraints!
function scale_constraints!(system::System, model::Model)
    if system.settings.ConstraintScaling
        @info "Scaling constraints and RHS"
        scale_constraints!(model)
    end
    return nothing
end

# MacroEnergyScaling.scale_constraints!
function scale_constraints!(systems::Vector{System}, models::Vector{Model})
    @assert length(systems) == length(models)
    for (system, model) in zip(systems, models)
        scale_constraints!(system, model)
    end
    return nothing
end

# MacroEnergyScaling.scale_constraints!
function scale_constraints!(case::Case, models::Vector{Model})
    scale_constraints!(case.systems, models)
    return nothing
end
