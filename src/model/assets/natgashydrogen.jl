struct NaturalGasH2 <: AbstractAsset
    natgash2_transform::Transformation
    h2_tedge::Union{TEdge{Hydrogen},TEdgeWithUC{Hydrogen}}
    ng_tedge::TEdge{NaturalGas}
    co2_tedge::TEdge{CO2}
end

function process_asset_data(::Type{NaturalGasH2}, data::Dict{Symbol,Any})
    asset_data = Dict(
        :time_interval => :Hydrogen,
        :transform_id => :NaturalGasH2,
        :stoichiometry_balance_names => [:energy, :emissions],
        :constraints => Dict{Symbol,Any}(
            :stoichiometry_balance => true
        ),
    )
    merge!(asset_data, data)
    return asset_data
end

function add_capacity_factor!(ng::NaturalGasH2, capacity_factor::Vector{Float64})
    ng.h2_tedge.capacity_factor = capacity_factor
end

make_natgash2(data::Dict{Symbol,Any}, time_data::Dict{Symbol,TimeData}, nodes::Dict{Symbol,Node}) = make_asset(NaturalGasH2, data, time_data, nodes)