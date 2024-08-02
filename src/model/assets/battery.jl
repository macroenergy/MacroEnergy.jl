struct Battery <: AbstractAsset
    battery_transform::Transformation
    discharge::TEdge{Electricity}
    charge::TEdge{Electricity}
end

function process_asset_data(::Type{Battery}, data::Dict{Symbol,Any})
    asset_data = Dict(
        :time_interval => :Electricity,
        :transform_id => :Battery,
        :stoichiometry_balance_names => [:storage],
        :constraints => Dict{Symbol,Any}(
            :stoichiometry_balance => true,
            :storage_capacity => true,
        ),
    )
    merge!(asset_data, data)
    return asset_data
end

make_battery(data::Dict{Symbol,Any}, time_data::Dict{Symbol,TimeData}, nodes::Dict{Symbol,Node}) = make_asset(Battery, data, time_data, nodes)