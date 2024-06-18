struct Battery <: AbstractAsset
    battery_transform::Transformation
    discharge_tedge::TEdge{Electricity}
    charge_tedge::TEdge{Electricity}
end

function make_battery(data::Dict{Symbol,Any}, time_data::Dict{Symbol,TimeData}, nodes::Dict{Symbol,Node})
    ## conversion process (node)
    _battery_transform = Transformation(;
        id=:Battery,
        timedata=time_data[:Electricity],
        stoichiometry_balance_names=get(data, :stoichiometry_balance_names, [:energy])
    )
    add_constraints!(_battery_transform, data)

    ## discharge edge
    _discharge_tedge_data = get_tedge_data(data, :Electricity)
    isnothing(_discharge_tedge_data) && error("No discharge edge data found for Battery")
    _discharge_tedge_data[:id] = :discharge
    _discharge_node_id = Symbol(data[:nodes][:Electricity])
    _discharge_node = nodes[_discharge_node_id]
    _discharge_tedge = make_tedge(_discharge_tedge_data, time_data, _battery_transform, _discharge_node)

    ## charge edge
    _charge_tedge_data = get_tedge_data(data, :Electricity)
    isnothing(_charge_tedge_data) && error("No charge edge data found for Battery")
    _charge_tedge_data[:id] = :charge
    _charge_node_id = Symbol(data[:nodes][:Electricity])
    _charge_node = nodes[_charge_node_id]
    _charge_tedge = make_tedge(_charge_tedge_data, time_data, _battery_transform, _charge_node)

    return Battery(_battery_transform, _discharge_tedge, _charge_tedge)
end