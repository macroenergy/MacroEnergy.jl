####### Releasing the JuMP references held by a solved System #######
#
# Scalar planning quantities (capacity, new/retired capacity and units) are replaced
# by their solution values, so the System still reports what was built in that
# period; the time-indexed variables and the constraint references are reset to their 
# empty defaults.
#
# Values are stored in the same (scaled) units

"""
    release_model_references!(x)

Recursively strip the JuMP references stored in `x`, where `x` is a `System`,
`Location`, asset, edge, vertex or constraint.

Scalar capacity fields are replaced by their solution values; time-indexed
variables, balance expressions and constraint references are reset to empty.

This must only be called once the model has been solved and its results written:
it calls `value` on the capacity variables, and any JuMP reference obtained from
the System beforehand is stale afterwards.

See also [`release_model!`](@ref).
"""
function release_model_references! end

# Solution value of a scalar planning quantity. `value` of a constant `AffExpr`
# does not touch the model, so components without capacity variables are fine.
solution_value(x::Union{VariableRef,AffExpr}) = value(x)
solution_value(x::Real) = x
solution_value(::Missing) = missing

function release_model_references!(system::System)
    for asset in system.assets
        release_model_references!(asset)
    end
    for location in system.locations
        release_model_references!(location)
    end
    return nothing
end

function release_model_references!(a::AbstractAsset)
    for t in fieldnames(typeof(a))
        release_model_references!(getfield(a, t))
    end
    return nothing
end

function release_model_references!(location::Location)
    for node in values(location.nodes)
        release_model_references!(node)
    end
    return nothing
end

function release_model_references!(x::Union{AbstractArray,AbstractDict,Tuple})
    for element in values(x)
        release_model_references!(element)
    end
    return nothing
end

function release_model_references!(e::AbstractEdge)
    e.capacity = solution_value(capacity(e))
    e.existing_capacity = solution_value(existing_capacity(e))
    e.new_capacity = solution_value(new_capacity(e))
    e.retired_capacity = solution_value(retired_capacity(e))
    e.retrofitted_capacity = solution_value(retrofitted_capacity(e))
    e.new_units = solution_value(new_units(e))
    e.retired_units = solution_value(retired_units(e))
    e.retrofitted_units = solution_value(retrofitted_units(e))
    release_capacity_tracks!(e)
    e.flow = Vector{VariableRef}()
    for constraint in e.constraints
        release_model_references!(constraint)
    end
    return nothing
end

function release_model_references!(e::EdgeWithUC)
    invoke(release_model_references!, Tuple{AbstractEdge}, e)
    e.ucommit = Vector{VariableRef}()
    e.ushut = Vector{VariableRef}()
    e.ustart = Vector{VariableRef}()
    return nothing
end

function release_model_references!(g::AbstractStorage)
    g.capacity = solution_value(capacity(g))
    g.existing_capacity = solution_value(existing_capacity(g))
    g.new_capacity = solution_value(new_capacity(g))
    g.retired_capacity = solution_value(retired_capacity(g))
    release_capacity_tracks!(g)
    g.new_units = missing
    g.retired_units = missing
    g.storage_level = Vector{VariableRef}()
    release_vertex_references!(g)
    return nothing
end

function release_model_references!(g::LongDurationStorage)
    invoke(release_model_references!, Tuple{AbstractStorage}, g)
    g.storage_initial = Vector{VariableRef}()
    g.storage_change = Vector{VariableRef}()
    return nothing
end

function release_model_references!(n::Node)
    n.non_served_demand = Matrix{VariableRef}(undef, 0, 0)
    n.supply_flow = Matrix{VariableRef}(undef, 0, 0)
    empty!(n.policy_budgeting_vars)
    empty!(n.policy_budgeting_constraints)
    empty!(n.policy_slack_vars)
    release_vertex_references!(n)
    return nothing
end

release_model_references!(g::Transformation) = release_vertex_references!(g)

function release_model_references!(ct::AbstractTypeConstraint)
    hasproperty(ct, :constraint_ref) && (ct.constraint_ref = missing)
    return nothing
end

# `operation_expr` holds the balance expressions, which are `AffExpr`s over the model's variables
function release_vertex_references!(v::AbstractVertex)
    empty!(v.operation_expr)
    for constraint in v.constraints
        release_model_references!(constraint)
    end
    return nothing
end

function release_capacity_track!(track::AbstractDict)
    for (period, tracked) in track
        track[period] = solution_value(tracked)
    end
    return nothing
end

function release_capacity_tracks!(y::Union{AbstractEdge,AbstractStorage})
    release_capacity_track!(y.new_capacity_track)
    release_capacity_track!(y.retired_capacity_track)
    isa(y, AbstractEdge) && release_capacity_track!(y.retrofitted_capacity_track)
    return nothing
end

"""
    release_model!(system::System, model)

Release the model built for `system` once its results have been written.

Strips the JuMP references that `system` holds (see
[`release_model_references!`](@ref)) and then calls `empty!` on `model`, so that
the solver's copy of the problem is released immediately.

`model` is unusable afterwards; only call this when the model is not being
returned to the caller (`MyopicSettings.ReturnModels == false`).
"""
function release_model!(system::System, model::Model)
    release_model_references!(system)
    empty!(model)
    return nothing
end

function release_model!(system::System, model::BendersModel)
    release_model_references!(system)
    empty!(model.planning_problem)
    # Distributed subproblems are left to the DArray's finalizer.
    if model.subproblems isa Vector{Dict{Any,Any}}
        for subproblem in model.subproblems
            haskey(subproblem, :system_local) &&
                release_model_references!(subproblem[:system_local])
            haskey(subproblem, :model) && empty!(subproblem[:model])
        end
    end
    return nothing
end
