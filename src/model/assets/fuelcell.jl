struct FuelCell <: AbstractAsset
    fuelcell_transform::Transformation
    h2_tedge::TEdge{Hydrogen}
    elec_tedge::TEdge{Electricity}
end

function process_asset_data(::Type{FuelCell}, data::Dict{Symbol,Any})
    asset_data = Dict(
        :time_interval => :Hydrogen,
        :transform_id => :FuelCell,
        :stoichiometry_balance_names => [:energy],
        :constraints => Dict{Symbol,Any}(
            :stoichiometry_balance => true
        ),
    )
    merge!(asset_data, data)
    return asset_data
end

make_fuelcell(data::Dict{Symbol,Any}, time_data::Dict{Symbol,TimeData}, nodes::Dict{Symbol,Node}) = make_asset(FuelCell, data, time_data, nodes)
