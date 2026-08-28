Base.@kwdef struct TDRFeatureSpec
    id::Union{Nothing,String} = nothing
    file::Union{Nothing,String} = nothing
    asset::Union{Nothing,String} = nothing
    commodity::Union{Nothing,String} = nothing
    field::String
    user_weight::Float64 = 1.0
    has_user_weight::Bool = false
end

"""A resolved physical time series and all input locations which consume it."""
mutable struct TimeSeriesSource
    key::String
    csv_path::Union{Nothing,String}
    header::Union{Nothing,Symbol}
    inline_file::Union{Nothing,String}
    inline_path::Vector{Any}
    values::Vector{Float64}
    timestep_hours::Int
    references::Vector{NamedTuple}
    occurrences::Int
    user_weight::Float64
    weight::Float64
    include_in_clustering::Bool
end

const TDR_DEFAULT_FEATURES = TDRFeatureSpec[
    TDRFeatureSpec(id="availability", field="availability"),
    TDRFeatureSpec(id="demand", field="demand"),
    TDRFeatureSpec(id="supply_price", field="supply.price"),
    TDRFeatureSpec(id="supply_min", field="supply.min"),
    TDRFeatureSpec(id="supply_max", field="supply.max"),
    TDRFeatureSpec(id="loss_fraction", field="loss_fraction"),
]
