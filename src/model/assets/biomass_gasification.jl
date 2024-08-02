struct BiomassToH2 <: AbstractAsset
    biomassh2_transform::Transformation
    h2_tedge::TEdge{Hydrogen}
    biomass_tedge::TEdge{Biomass}
    co2_tedge::TEdge{CO2}
end

struct BiomassToPower <: AbstractAsset
    biomass_power_transform::Transformation
    elec_tedge::TEdge{Electricity}
    biomass_tedge::TEdge{Biomass}
    co2_tedge::TEdge{CO2}
end

function process_asset_data(::Type{BiomassToH2}, data::Dict{Symbol,Any})
    asset_data = Dict(
        :time_interval => :Biomass,
        :transform_id => :BiomassToH2,
        :stoichiometry_balance_names => [:h2production, :carbon_removal],
        :constraints => Dict{Symbol,Any}(
            :stoichiometry_balance => true
        ),
    )
    merge!(asset_data, data)
    return asset_data
end

function process_asset_data(::Type{BiomassToPower}, data::Dict{Symbol,Any})
    asset_data = Dict(
        :time_interval => :Biomass,
        :transform_id => :BiomassToPower,
        :stoichiometry_balance_names => [:elec_production, :carbon_removal],
        :constraints => Dict{Symbol,Any}(
            :stoichiometry_balance => true
        ),
    )
    merge!(asset_data, data)
    return asset_data
end

function add_capacity_factor!(g::T, capacity_factor::Vector{Float64}) where {T<:Union{BiomassToH2,BiomassToPower}}
    g.biomass_tedge.capacity_factor = capacity_factor
end

make_biomassH2(data::Dict{Symbol,Any}, time_data::Dict{Symbol,TimeData}, nodes::Dict{Symbol,Node}) = make_asset(BiomassToH2, data, time_data, nodes)
make_biomass_power(data::Dict{Symbol,Any}, time_data::Dict{Symbol,TimeData}, nodes::Dict{Symbol,Node}) = make_asset(BiomassToPower, data, time_data, nodes)

