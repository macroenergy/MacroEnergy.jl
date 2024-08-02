struct H2Storage <: AbstractAsset
    h2storage_transform::Transformation
    discharge::TEdge{Hydrogen}
    charge::TEdge{Hydrogen}
    elec_tedge::TEdge{Electricity}
end

function process_asset_data(::Type{H2Storage}, data::Dict{Symbol,Any})
    asset_data = Dict(
        :time_interval => :Hydrogen,
        :transform_id => :H2Storage,
        :stoichiometry_balance_names => [:energy],
        :constraints => Dict{Symbol,Any}(
            :stoichiometry_balance => true,
            :storage_capacity => true,
        ),
    )
    merge!(asset_data, data)
    return asset_data
end

make_h2storage(data::Dict{Symbol,Any}, time_data::Dict{Symbol,TimeData}, nodes::Dict{Symbol,Node}) = make_asset(H2Storage, data, time_data, nodes)