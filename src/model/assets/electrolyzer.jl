struct Electrolyzer <: AbstractAsset
    electrolyzer_transform::Transformation
    h2_tedge::TEdge{Hydrogen}
    elec_tedge::TEdge{Electricity}
end

function process_asset_data(::Type{Electrolyzer}, data::Dict{Symbol,Any})
    asset_data = Dict(
        :time_interval => :Hydrogen,
        :transform_id => :Electrolyzer,
        :stoichiometry_balance_names => [:energy],
        :constraints => Dict{Symbol,Any}(
            :stoichiometry_balance => true
        ),
    )
    merge!(asset_data, data)
    return asset_data
end

make_electrolyzer(data::Dict{Symbol,Any}, time_data::Dict{Symbol,TimeData}, nodes::Dict{Symbol,Node}) = make_asset(Electrolyzer, data, time_data, nodes)
