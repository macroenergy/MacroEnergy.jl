### These additional constraints can be used to ensure that storage levels of LDES resources do not exceed capacity over non-representative subperiods 
### They are based on the paper:
### "Improved formulation for long-duration storage in capacity expansion models using representative periods"
### Federico Parolin, Paolo Colbertaldo, Ruaridh Macdonald
### 2024
### https://doi.org/10.48550/arXiv.2409.19079

Base.@kwdef mutable struct LongDurationStorageImplicitMinMaxConstraint <: OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

function add_model_constraint!(ct::LongDurationStorageImplicitMinMaxConstraint, g::LongDurationStorage, model::Model)
    W = subperiod_indices(g);
    N = setdiff(modeled_subperiods(g),W)

    if !isempty(N)
        charge_edge = g.charge_edge;
        discharge_edge = g.discharge_edge;

        max_storage_level =  @variable(model, [w ∈ W], lower_bound = 0.0, base_name = "vSTORMAX_$(id(g))_stage$(stage_index(g))")
        min_storage_level = @variable(model, [w ∈ W], lower_bound = 0.0, base_name = "vSTORMIN_$(id(g))_stage$(stage_index(g))")

        @constraint(model, [t ∈ time_interval(g)], storage_level(g,t) ≤ max_storage_level[current_subperiod(g,t)])
        @constraint(model, [t ∈ time_interval(g)], storage_level(g,t) ≥ min_storage_level[current_subperiod(g,t)])

        tstart = Dict(n => first(get_subperiod(g,period_map(g,n))) for n in N)

        stor_balance_expr = @expression(model, [n in N], 
            (1 - loss_fraction(g))*storage_initial(g, n) 
            + balance_data(charge_edge, g, :storage)*flow(charge_edge,tstart[n])
            - balance_data(discharge_edge, g, :storage)*flow(discharge_edge,tstart[n])
        )
        @constraint(model, [n in N], 
            stor_balance_expr[n] + max_storage_level[period_map(g,n)] - storage_level(g,tstart[n]) ≤ capacity(g)
        )

        @constraint(model, [n in N], 
            stor_balance_expr[n] + min_storage_level[period_map(g,n)] - storage_level(g,tstart[n]) ≥ 0
        )

    else
        @warn "LongDurationStorageImplicitMinMaxConstraint is redundant when all modeled subperiods are representative subperiods so Macro will not create this constraint"
    end

end

function add_model_constraint!(ct::LongDurationStorageImplicitMinMaxConstraint, g::Storage, model::Model)
   
    @warn "$(g.id) is not a long duration storage resource, so Macro will not create a LongDurationStorageImplicitMinMaxConstraint"
    
end