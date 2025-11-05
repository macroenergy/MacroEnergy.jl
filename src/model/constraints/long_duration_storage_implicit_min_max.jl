### These additional constraints can be used to ensure that storage levels of LDES resources do not exceed capacity over non-representative subperiods 
### They are based on the paper:
### "Improved formulation for long-duration storage in capacity expansion models using representative periods"
### Federico Parolin, Paolo Colbertaldo, Ruaridh Macdonald
### 2024
### https://doi.org/10.48550/arXiv.2409.19079

Base.@kwdef mutable struct LongDurationStorageImplicitMinMaxConstraint <: OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    constraint_dual::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

@doc raw"""
    add_model_constraint!(ct::LongDurationStorageImplicitMinMaxConstraint, g::LongDurationStorage, model::Model)

Adds constraints to ensure that the storage levels of long-duration storage systems do not exceed installed capacity over non-representative subperiods.

The functional form of the two constraints are:

```math
\begin{aligned}
    \text{storage\_balance(p)} + \text{max\_storage\_level(r)} - \text{storage\_level(tstart(p))} &\leq \text{capacity(g)} \\
    \text{storage\_balance(p)} + \ \text{min\_storage\_level(r)} - \text{storage\_level(tstart(p))} &\geq 0
\end{aligned}
```
where:
- `p` is a non-representative subperiod.
- `r` is the representative subperiod used to model `p`.
- `tstart(p)` is the first timestep of the representative subperiod `r` used to model the non-representative subperiod `p`.
- `storage_balance(p)` is the balance of the storage resource at the non-representative subperiod `p` and is defined as 
```math
\begin{aligned}
    \text{storage\_balance(p)} = (1 - \text{loss\_fraction}) \times \text{storage\_initial(p)} + \frac{\text{flow(discharge\_edge, tstart(p))}}{\text{efficiency(discharge\_edge)}} - \text{efficiency(charge\_edge)} \times \text{flow(charge\_edge, tstart(p))}
\end{aligned}
```

- `max_storage_level(r)` and `min_storage_level(r)` are the maximum and minimum storage levels for the representative subperiod `r`, respectively. These are used to constrain the storage levels as follows:

```math
\begin{aligned}
    \text{min\_storage\_level(t')} \leq \text{storage\_level(t)} \leq \text{max\_storage\_level(t')}
\end{aligned}
```

for each time `t` in the time interval of the storage resource `g`. `t'` is the corresponding time in the representative subperiod `r` used to model the time interval of the storage resource `g`.

!!! warning "Only applies to long duration energy storage"
    This constraint only applies to long duration energy storage resources. To model a storage technology as long duration energy storage, the user must set `long_duration = true` in the `Storage` component of the asset in the `.json` file.
    Check the the file `hydropower.json` in the [multisector_three_zones example](https://github.com/macroenergy/MacroEnergyExamples.jl/blob/main/examples/multisector_three_zones/assets/hydropower.json) for an example of how to model a long duration energy storage resource.
"""
function add_model_constraint!(ct::LongDurationStorageImplicitMinMaxConstraint, g::LongDurationStorage, model::Model)
    W = subperiod_indices(g);
    N = setdiff(modeled_subperiods(g),W)

    if !isempty(N)
        charge_edge = g.charge_edge;
        discharge_edge = g.discharge_edge;

        max_storage_level =  @variable(model, [w ∈ W], lower_bound = 0.0, base_name = "vSTORMAX_$(id(g))_period$(period_index(g))")
        min_storage_level = @variable(model, [w ∈ W], lower_bound = 0.0, base_name = "vSTORMIN_$(id(g))_period$(period_index(g))")

        @constraint(model, [t ∈ time_interval(g)], storage_level(g,t) ≤ max_storage_level[current_subperiod(g,t)])
        @constraint(model, [t ∈ time_interval(g)], storage_level(g,t) ≥ min_storage_level[current_subperiod(g,t)])

        tstart = Dict(n => first(get_subperiod(g,subperiod_map(g,n))) for n in N)

        stor_balance_expr = @expression(model, [n in N], 
            (1 - loss_fraction(g,tstart[n]))*storage_initial(g, n) 
            + balance_data(charge_edge, g, :storage)*flow(charge_edge,tstart[n])
            - balance_data(discharge_edge, g, :storage)*flow(discharge_edge,tstart[n])
        )
        @constraint(model, [n in N], 
            stor_balance_expr[n] + max_storage_level[subperiod_map(g,n)] - storage_level(g,tstart[n]) ≤ capacity(g)
        )

        @constraint(model, [n in N], 
            stor_balance_expr[n] + min_storage_level[subperiod_map(g,n)] - storage_level(g,tstart[n]) ≥ 0
        )

    else
        @warn "LongDurationStorageImplicitMinMaxConstraint is redundant when all modeled subperiods are representative subperiods so Macro will not create this constraint"
    end

end

function add_model_constraint!(ct::LongDurationStorageImplicitMinMaxConstraint, g::Storage, model::Model)
   
    @warn "$(g.id) is not a long duration storage resource, so Macro will not create a LongDurationStorageImplicitMinMaxConstraint"
    
end