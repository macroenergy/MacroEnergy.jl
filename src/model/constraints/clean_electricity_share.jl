Base.@kwdef mutable struct CleanElectricityShare <: OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    constraint_dual::Union{Missing,Vector{Float64},Dict{Symbol,Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint,Dict{Symbol,Any}} = missing
    # System-wide / per-location configuration: asset-type key => Dict(:edge => fieldname, :value => cap).
    # Populated at load time from the `constraints` block in system_data.json / locations.json.
    config::Union{Missing,Dict{Symbol,Any}} = missing
end