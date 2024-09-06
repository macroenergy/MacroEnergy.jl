struct HydroStor <: AbstractAsset
	hydrostor_transform::Transformation
	discharge_tedge::TEdge{Electricity}
	spillage_tedge::TEdge{Water}
	charge_tedge_electricity::TEdge{Electricity}
	charge_tedge_water::TEdge{Water}
end
    
function make_hydrostor(data::Dict{Symbol,Any}, time_data::Dict{Symbol,TimeData}, nodes::Dict{Symbol,Node})
	## conversion process (node)
	_hydrostor_transform = Transformation(;
	    id=:Hydrostor,
	    timedata=time_data[:Electricity],
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
	add_constraints!(_hydrostor_transform, data)
    
	## discharge edge electricity
	_discharge_tedge_data = get_tedge_data(data, :discharge)
	isnothing(_discharge_tedge_data) && error("No discharge edge data found for Hydrostor")
	_discharge_tedge_data[:id] = :discharge
	_discharge_node_id = Symbol(data[:nodes][:Electricity])
	_discharge_node = nodes[_discharge_node_id]
	_discharge_tedge = make_tedge(_discharge_tedge_data, time_data, _hydrostor_transform, _discharge_node)
    
	## charge edge electricity
	_charge_tedge_data = get_tedge_data(data, :charge)
	isnothing(_charge_tedge_data) && error("No charge edge data found for Hydrostor")
	_charge_tedge_data[:id] = :charge
	_charge_node_id = Symbol(data[:nodes][:Electricity])
	_charge_node = nodes[_charge_node_id]
	_charge_tedge = make_tedge(_charge_tedge_data, time_data, _hydrostor_transform, _charge_node)

	## discharge edge water/spillage
	_discharge_tedge_data = get_tedge_data(data, :discharge)
	isnothing(_discharge_tedge_data) && error("No discharge edge data found for Hydrostor")
	_discharge_tedge_data[:id] = :discharge
	_discharge_node_id = Symbol(data[:nodes][:Water])
	_discharge_node = nodes[_discharge_node_id]
	_discharge_tedge = make_tedge(_discharge_tedge_data, time_data, _hydrostor_transform, _discharge_node)
    
	## charge edge water
	_charge_tedge_data = get_tedge_data(data, :charge)
	isnothing(_charge_tedge_data) && error("No charge edge data found for HydroStor")
	_charge_tedge_data[:id] = :charge
	_charge_node_id_water = Symbol(data[:nodes][:Water])
	_charge_node_water = nodes[_charge_node_id_water]
	_charge_tedge_water = make_tedge(_charge_tedge_data, time_data, _hydrostor_transform, _charge_node_water)
    
	## add reference to tedges in transformation
	_TEdges = Dict(:discharge=>_discharge_tedge, :charge=>_charge_tedge_electricity, :discharge_spill=>_spillage_tedge, :charge_water=>_charge_tedge_water)
	_hydrostor_transform.TEdges = _TEdges
    
	return HydroStor(_hydrostor_transform, _discharge_tedge, _spillage_tedge, _charge_tedge_electricity, _charge_tedge_water)
    end