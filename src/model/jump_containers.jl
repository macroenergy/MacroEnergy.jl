# JuMP container types used throughout the model.
#
# Macro JuMP-related types:
#
#   * `JuMPVariable` / `JuMPConstraint` are the WIDE types. Struct fields are declared
#     with them (`flow::JuMPVariable`) because a field must accept whichever container
#     `array_container` picked at build time.
#   * `VarArrayOrDense` / `MatrixVarOrDense` / `AffExprArrayOrDense` are the NARROW
#     types. Accessors re-assert the field down to them (`(flow(e)::VarArrayOrDense)[t]`)
#     so that reads infer a concrete `VariableRef`/`AffExpr` and allocate nothing.
#
# Every member of the narrow unions must stay fully parametrized. Widening one back to
# an abstract `DenseAxisArray` makes every accessor read infer `Any` and box: the model
# stays correct and nothing errors, it just costs ~1.67 GB more on an example case.
# `test/test_accessor_allocation.jl` asserts zero allocation, and
# `test/test_container_types.jl` pins each derived type against a real model build.

const JuMPConstraint =
    Union{Array,Containers.DenseAxisArray,Containers.SparseAxisArray,ConstraintRef}
const JuMPVariable =
    Union{Array,Containers.DenseAxisArray,Containers.SparseAxisArray,VariableRef}


@doc raw"""
    array_container(interval)

This function returns the appropriate container type for JuMP variables indexed over
`interval`. For instances, when `interval` is a contiguous, one-based range
(e.g., `1:24`), it returns `Array`, which allows JuMP to optimize variable storage
and access. If `interval` is not one-based (e.g., `169:192`),
it returns `JuMP.Containers.DenseAxisArray`, which is a more general container type
that can handle non-one-based indexing.

Benders subproblems are the one case where this matters: `generate_decomposed_system`
reassigns each subproblem's `time_interval` to its own subperiod's window, and only
the first subperiod happens to start at 1 (e.g. `1:168`, `169:336`, `337:504`, ...).
The range stays contiguous but isn't one-based.
"""
array_container(interval) = first(interval) == 1 ? Array : JuMP.Containers.DenseAxisArray

"""
    _dense_axis_array_type(T, axes...)

Returns the concrete type of a `JuMP.Containers.DenseAxisArray` with element type
`T` and axes `axes...`. This is useful for defining type aliases for JuMP containers
that are indexed over specific ranges, especially when those ranges are not one-based.

JuMP parametrizes the container as `DenseAxisArray{T,N,Ax,L}` where
`L == typeof(build_lookup.(axes))`, so `L` is fully determined by the axis types and
never has to be written out. Recovering it through JuMP's own constructor, instead of
naming JuMP's internal `_AxisLookup` directly, means a change to JuMP's lookup
representation is picked up automatically rather than silently yielding a type that
matches nothing.

Only the *types* of `axes` matter, not their values or lengths. Note that `1:24` and
`Base.OneTo(24)` are `==` but give different container types.

# Examples
```julia
julia> _dense_axis_array_type(VariableRef, 1:24)
JuMP.Containers.DenseAxisArray{VariableRef, 1, Tuple{UnitRange{Int64}}, Tuple{JuMP.Containers._AxisLookup{Tuple{Int64, Int64}}}}
julia> _dense_axis_array_type(VariableRef, Base.OneTo(24))   # NOT the same as 1:24
JuMP.Containers.DenseAxisArray{VariableRef, 1, Tuple{Base.OneTo{Int64}}, Tuple{JuMP.Containers._AxisLookup{Base.OneTo{Int64}}}}
julia> _dense_axis_array_type(AffExpr, 1:3, 1:24)
JuMP.Containers.DenseAxisArray{AffExpr, 2, Tuple{UnitRange{Int64}, UnitRange{Int64}}, Tuple{JuMP.Containers._AxisLookup{Tuple{Int64, Int64}}, JuMP.Containers._AxisLookup{Tuple{Int64, Int64}}}}
```
"""
function _dense_axis_array_type(::Type{T}, axes...) where {T}
    data = Array{T}(undef, length.(axes)...)
    return typeof(JuMP.Containers.DenseAxisArray(data, axes...))
end

# Macro reaches every index set through a function call:
#
#   time_interval(y)                                    -> StepRange{Int64,Int64}
#   segments_non_served_demand(n), supply_segments(n)   -> Base.OneTo{Int64}
#
const _EMPTY_TIME_AXIS = 1:1:0              # as time_interval
const _EMPTY_SEGMENT_AXIS = Base.OneTo(0)   # as segments_non_served_demand / supply_segments

const DenseVarOverTime = _dense_axis_array_type(VariableRef, _EMPTY_TIME_AXIS)
const DenseAffExprOverTime = _dense_axis_array_type(AffExpr, _EMPTY_TIME_AXIS)
const DenseVarOverSegmentTime = _dense_axis_array_type(VariableRef, _EMPTY_SEGMENT_AXIS, _EMPTY_TIME_AXIS)

# Accessor return types for containers built with `array_container`: the plain
# `Array` fast path in the common case, or the matching `DenseAxisArray` for Benders
# subproblems beyond the first.
const VarArrayOrDense = Union{Vector{VariableRef},DenseVarOverTime}
const MatrixVarOrDense = Union{Matrix{VariableRef},DenseVarOverSegmentTime}
const AffExprArrayOrDense = Union{Vector{AffExpr},DenseAffExprOverTime}
