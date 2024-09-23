struct HydroStor <: AbstractAsset
	id::AssetId
	hydrostor_reservoir::Storage{Water}
	genmotor_transform::Transformation
	spillage_edge::Edge{Water}
	charge_edge_water::Edge{Water}
	discharge_edge_elec::Edge{Electricity}
	charge_edge_elec::Edge{Electricity}
end
    
id(hs::HydroStor) = hs.id

"""
    make(::Type{HydroStor}, data::AbstractDict{Symbol, Any}, system::System) -> HydroStor

    Necessary data fields:
     - storage: Dict{Symbol, Any}
        - id: String
        - commodity: String
        - can_retire: Bool
        - can_expand: Bool
        - existing_capacity_storage: Float64
        - investment_cost_storage: Float64
        - fixed_om_cost_storage: Float64
        - storage_loss_fraction: Float64
        - min_duration: Float64
        - max_duration: Float64
        - min_storage_level: Float64
        - min_capacity_storage: Float64
        - max_capacity_storage: Float64
        - constraints: Vector{AbstractTypeConstraint}
     - edges: Dict{Symbol, Any}
        - charge: Dict{Symbol, Any}
            - id: String
            - start_vertex: String
            - unidirectional: Bool
            - has_planning_variables: Bool
            - efficiency: Float64
        - discharge: Dict{Symbol, Any}
            - id: String
            - end_vertex: String
            - unidirectional: Bool
            - has_planning_variables: Bool
            - can_retire: Bool
            - can_expand: Bool
            - efficiency
            - constraints: Vector{AbstractTypeConstraint}
"""

function make(::Type{HydroStor}, data::AbstractDict{Symbol,Any}, system::System)
	id = AssetId(data[:id])

	hydrostor_key = :storage

	storage_data = process_data(data[:hydrostor_key])
	commodity_symbol = Symbol(storage_data[:commodity])
	commodity = commodity_types()[commodity_symbol]

	hydrostor = Storage(
        	Symbol(id, "_", hydrostor_key),
        	storage_data,
        	system.time_data[:Water],
        	Water,
    	)

	hydrostor.constraints = get(
		storage_data,
		:constraints,
		[BalanceConstraint(), StorageCapacityConstraint(), MinStorageLevelConstraint()],
	)

	genmotor_key = :transforms
    	transform_data = process_data(data[genmotor_key])
    	genmotor_transform = Transformation(;
        	id = Symbol(id, "_", genmotor_key),
        	timedata = system.time_data[Symbol(transform_data[:timedata])],
        	constraints = get(transform_data, :constraints, [BalanceConstraint()]),
    	)

	genmotor_elec_edge_key = :genmotor_elec_edge
	genmotor_elec_edge_data = process_data(data[:edges][genmotor_elec_edge_key])
	elec_start_node =
		find_node(system.locations, Symbol(genmotor_elec_edge_data[:start_vertex]))
	elec_end_node = genmotor_transform
	genmotor_elec_edge = Edge(
		Symbol(id, "_", genmotor_elec_edge_key),
		genmotor_elec_edge_data,
		system.time_data[:Electricity],
		Electricity,
		elec_start_node,
		elec_end_node,
	)
	genmotor_elec_edge.unidirectional =
		get(genmotor_elec_edge_data, :unidirectional, true)
	##Should I create another unidirectional edge for discharge or make this bidirectional?
	
	genmotor_water_edge_key = :genmotor_water_edge
	genmotor_water_edge_data = process_data(data[:edges][genmotor_water_edge_key])
	water_start_node =
		find_node(system.locations, Symbol(genmotor_water_edge_data[:start_vertex]))
	water_end_node = genmotor_transform
	genmotor_water_edge = Edge(
		Symbol(id, "_", genmotor_water_edge_key),
		genmotor_water_edge_data,
		system.time_data[:Water],
		Water,
		water_start_node,
		water_end_node,
	)
	genmotor_water_edge.unidirectional = get(genmotor_water_edge_data, :unidirectional, true)
	##Should I create another unidirectional edge for discharge or make this bidirectional?

	charge_edge_key = :charge_edge
	charge_edge_data = process_data(data[:edges][charge_edge_key])
	charge_start_node = genmotor_transform
	charge_end_node = hydrostor_reservoir
	hydrostor_charge = Edge(
		Symbol(id, "_", charge_edge_key),
		charge_edge_data,
		system.time_data[:Water],
		Water,
		charge_start_node,
		charge_end_node,
	)
	hydrostor_charge.unidirectional = get(charge_edge_data, :unidirectional, true)
	hydrostor_charge.constraints =
		get(charge_edge_data, :constraints, [CapacityConstraint()])
	
	discharge_edge_key = :discharge_edge
	discharge_edge_data = process_data(data[:edges][discharge_edge_key]) #or should it be genmotor_transform?
	discharge_start_node = hydrostor_reservoir
	discharge_end_node =
		find_node(system.locations, Symbol(discharge_edge_data[:end_vertex]))
	hydrostor_discharge = Edge(
		Symbol(id, "_", discharge_edge_key),
		discharge_edge_data,
		system.time_data[:Water],
		Water,
		discharge_start_node,
		discharge_end_node,
	)
	hydrostor_discharge.constraints = get(
		discharge_edge_data,
		:constraints,
		[CapacityConstraint(), RampingLimitConstraint()],
	)
	hydrostor_discharge.unidirectional = get(discharge_edge_data, :unidirectional, true)
	
	hydrostor.discharge_edge = hydrostor_discharge
	hydrostor.charge_edge = hydrostor_charge
	
	hydrostor.balance_data = Dict(
		:storage => Dict(
			hydrostor_discharge.id => 1 / get(discharge_edge_data, :efficiency, 1.0),
			hydrostor_charge.id => get(charge_edge_data, :efficiency, 1.0),
		),
	)
	
	    compressor_transform.balance_data = Dict(
		:electricity => Dict(
		    compressor_h2_edge.id => get(transform_data, :electricity_consumption, 0.0),
		    compressor_elec_edge.id => 1.0,
		    h2storage_charge.id => 0.0,
		),
		:hydrogen => Dict(
		    h2storage_charge.id => 1.0,
		    compressor_h2_edge.id => 1.0,
		    compressor_elec_edge.id => 0.0,
		),
	    )


	### Lines of code between the two comments need further modification
	battery_storage = Storage(id, storage_data, system.time_data[commodity_symbol], commodity)
	battery_storage.constraints = get(storage_data, :constraints, [BalanceConstraint(), StorageCapacityConstraint(), StorageMaxDurationConstraint(), StorageMinDurationConstraint(), StorageSymmetricCapacityConstraint()])
    
	charge_edge_data = process_data(data[:edges][:charge_edge])
	charge_start_node = find_node(system.locations, Symbol(charge_edge_data[:start_vertex]))
	charge_end_node = battery_storage
	battery_charge = Edge(Symbol(String(id)*"_"*charge_edge_data[:id]), charge_edge_data, system.time_data[commodity_symbol], commodity, charge_start_node, charge_end_node)
	battery_charge.unidirectional = get(charge_edge_data, :unidirectional, true)
    
	discharge_edge_data = process_data(data[:edges][:discharge_edge])
	discharge_start_node = battery_storage
	discharge_end_node = find_node(system.locations, Symbol(discharge_edge_data[:end_vertex]))
	battery_discharge = Edge(Symbol(String(id)*"_"*discharge_edge_data[:id]), discharge_edge_data, system.time_data[commodity_symbol], commodity, discharge_start_node, discharge_end_node)
	battery_discharge.constraints = get(discharge_edge_data, :constraints, [CapacityConstraint(), RampingLimitConstraint()])
	battery_discharge.unidirectional = get(discharge_edge_data, :unidirectional, true)
    
	battery_storage.discharge_edge = battery_discharge
	battery_storage.charge_edge = battery_charge
	battery_storage.balance_data = Dict(:storage => Dict(battery_discharge.id => 1 / get(discharge_edge_data, :efficiency, 0.9),
	    battery_charge.id => get(charge_edge_data, :efficiency, 0.9)))
    
	return Battery(id, battery_storage, battery_discharge, battery_charge)


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
	### Lines of code between the two comments need further modification
    
	return HydroStor(
		id, 
		hydrostor, 
		generator_transform
		hydrostor_discharge_elec, 
		hydrostor_spillage, 
		hydrostor_charge_elec, 
		hydrostor_charge_water
	)
end