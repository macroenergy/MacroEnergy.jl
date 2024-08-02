struct NaturalGasPower <: AbstractAsset
    natgaspower_transform::Transformation
    elec_tedge::Union{TEdge{Electricity},TEdgeWithUC{Electricity}}
    ng_tedge::TEdge{NaturalGas}
    co2_tedge::TEdge{CO2}
end

function process_asset_data(::Type{NaturalGasPower}, data::Dict{Symbol,Any})
    asset_data = Dict(
        :time_interval => :Electricity,
        :transform_id => :NaturalGasPower,
        :stoichiometry_balance_names => [:energy, :emissions],
        :constraints => Dict{Symbol,Any}(
            :stoichiometry_balance => true
        ),
    )
    merge!(asset_data, data)
    return asset_data
end

function add_capacity_factor!(ng::NaturalGasPower, capacity_factor::Vector{Float64})
    ng.elec_tedge.capacity_factor = capacity_factor
end

make_natgaspower(data::Dict{Symbol,Any}, time_data::Dict{Symbol,TimeData}, nodes::Dict{Symbol,Node}) = make_asset(NaturalGasPower, data, time_data, nodes)