Base.@kwdef mutable struct MinStorageLevelConstraint <: OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    constraint_dual::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

@doc raw"""
    add_model_constraint!(ct::MinStorageLevelConstraint, g::AbstractStorage, model::Model)

Add a min storage level constraint to the storage `g`. The functional form of the constraint is:

```math
\begin{aligned}
    \text{storage\_level(g, t)} \geq \text{min\_storage\_level(g)} \times \text{capacity(g)}
\end{aligned}
```
for each time `t` in `time_interval(g)` for the storage `g`.
"""
function add_model_constraint!(ct::MinStorageLevelConstraint, g::AbstractStorage, model::Model)

    ct.constraint_ref = @constraint(
        model,
        [t in time_interval(g)],
        storage_level(g, t) >= min_storage_level(g) * capacity(g)
    )

    return nothing
end

Base.@kwdef mutable struct MinInitStorageLevelConstraint <: PlanningConstraint
    value::Union{Missing,Vector{Float64}} = missing
    constraint_dual::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

@doc raw"""
    add_model_constraint!(ct::MinInitStorageLevelConstraint, g::LongDurationStorage, model::Model)

Add a min storage level constraint to the initial storage level of `g`. The functional form of the constraint is:

```math
\begin{aligned}
    \text{storage\_initial\_level(g)} \geq \text{min\_storage\_level(g)} \times \text{capacity(g)}
\end{aligned}
```

!!! warning "Only applies to long duration energy storage"
    This constraint only applies to long duration energy storage resources. To model a storage technology as long duration energy storage, the user must set `long_duration = true` in the `Storage` component of the asset in the `.json` file.
    Check the the file `hydropower.json` in the [multisector_three_zones example](https://github.com/macroenergy/MacroEnergyExamples.jl/blob/main/examples/multisector_three_zones/assets/hydropower.json) for an example of how to model a long duration energy storage resource.

!!! note "Only applicable for problems solved with Benders decomposition"
    This constraint is redundant with `MinStorageLevelConstraint` for monolithic models. For Benders decomposition, this constraint helps the planning level master problem choose solutions that are feasible in the subproblem(s)
"""
function add_model_constraint!(ct::MinInitStorageLevelConstraint, g::LongDurationStorage, model::Model)

    ct.constraint_ref = @constraint(
        model,
        [r in modeled_subperiods(g)],
        storage_initial(g, r) >= min_storage_level(g) * capacity(g)
    )

    return nothing
end