struct H2Storage <: AbstractAsset
    h2storage_transform::Transformation
    discharge_tedge::TEdge{Hydrogen}
    charge_tedge::TEdge{Hydrogen}
    elec_tedge::TEdge{Electricity}
end

function make_h2storage(data::Dict{Symbol,Any}, time_data::Dict{Symbol,TimeData}, nodes::Dict{Symbol,Node})
    ## conversion process (node)
    _h2storage_transform = Transformation(;
        id=:H2Storage,
        timedata=time_data[:Hydrogen],
        stoichiometry_balance_names=get(data, :stoichiometry_balance_names, [:energy]),
        can_retire = get(data, :can_retire, false),
        can_expand = get(data, :can_expand, false),
        existing_capacity_storage = get(data, :existing_capacity_storage, 0.0),
        investment_cost_storage = get(data, :investment_cost_storage, 0.0),
        fixed_om_cost_storage = get(data, :fixed_om_cost_storage, 0.0),
        storage_loss_fraction = get(data, :storage_loss_fraction, 0.0),
        min_duration = get(data, :min_duration, 0.0),
        max_duration = get(data, :max_duration, 0.0),
        min_storage_level = get(data, :min_storage_level, 0.0),
        min_capacity_storage = get(data, :min_capacity_storage, 0.0),
        max_capacity_storage = get(data, :max_capacity_storage, Inf),
    )
    add_constraints!(_h2storage_transform, data)

    ## discharge edge
    _discharge_tedge_data = get_tedge_data(data, :discharge)
    isnothing(_discharge_tedge_data) && error("No discharge edge data found for H2Storage")
    _discharge_tedge_data[:id] = :discharge
    _discharge_node_id = Symbol(data[:nodes][:Hydrogen])
    _discharge_node = nodes[_discharge_node_id]
    _discharge_tedge = make_tedge(_discharge_tedge_data, time_data, _h2storage_transform, _discharge_node)

    ## charge edge
    _charge_tedge_data = get_tedge_data(data, :charge)
    isnothing(_charge_tedge_data) && error("No charge edge data found for H2Storage")
    _charge_tedge_data[:id] = :charge
    _charge_node_id = Symbol(data[:nodes][:Hydrogen])
    _charge_node = nodes[_charge_node_id]
    _charge_tedge = make_tedge(_charge_tedge_data, time_data, _h2storage_transform, _charge_node)

    _elec_tedge_data = get_tedge_data(data, :elec)
    isnothing(_elec_tedge_data) && error("No charge edge data found for H2Storage")
    _elec_tedge_data[:id] = :elec
    _elec_node_id = Symbol(data[:nodes][:Electricity])
    _elec_node = nodes[_elec_node_id]
    _elec_tedge = make_tedge(_elec_tedge_data, time_data, _h2storage_transform, _elec_node)
    ## add reference to tedges in transformation
    _TEdges = Dict(:discharge=>_discharge_tedge, :charge=>_charge_tedge,:elec=>_elec_tedge)
    _h2storage_transform.TEdges = _TEdges

    return H2Storage(_h2storage_transform, _discharge_tedge, _charge_tedge,_elec_tedge)
end