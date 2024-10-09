struct HydroStor <: AbstractAsset
	id::AssetId
	hydrostor_reservoir::Storage{Water}
	generator_transform::Transformation
	motor_transform::Transformation
	spillage_edge::Edge{Water}
	charge_water_edge::Edge{Water}
	generator_water_edge::Edge{Water}
	generator_elec_edge::Edge{Electricity}
	motor_elec_edge::Edge{Electricity}
	inflow_edge_water::Edge{Water}
	pump_edge_water::Edge{Water}
end
    
id(hs::HydroStor) = hs.id

function make(::Type{HydroStor}, data::AbstractDict{Symbol,Any}, system::System)
	id = AssetId(data[:id])

	hydrostor_reservoir_key = :storage

	storage_data = process_data(data[hydrostor_reservoir_key])
	commodity_symbol = Symbol(storage_data[:commodity])
	commodity = commodity_types()[commodity_symbol]

	hydrostor_reservoir = Storage(
        	Symbol(id, "_", hydrostor_reservoir_key),
        	storage_data,
        	system.time_data[:Water],
        	Water,
    	)

	hydrostor_reservoir.constraints = get(
		storage_data,
		:constraints,
		[BalanceConstraint(), StorageCapacityConstraint(), MinStorageLevelConstraint()],
	)

	generator_key = :generator_transform
    	transform_data = process_data(data[:transforms][generator_key])
    	generator_transform = Transformation(;
        	id = Symbol(id, "_", generator_key),
        	timedata = system.time_data[Symbol(transform_data[:timedata])],
        	constraints = get(transform_data, :constraints, [BalanceConstraint()]),
    	)

	motor_key = :motor_transform
    	transform_data = process_data(data[:transforms][motor_key])
    	motor_transform = Transformation(;
        	id = Symbol(id, "_", motor_key),
        	timedata = system.time_data[Symbol(transform_data[:timedata])],
        	constraints = get(transform_data, :constraints, [BalanceConstraint()]),
    	)
######################################ELECTRICITY-GENERATION EDGE##############################################
	generator_elec_edge_key = :discharge_edge_elec
	generator_elec_edge_data = process_data(data[:edges][generator_elec_edge_key])
	elec_start_node = generator_transform
	elec_end_node = find_node(system.locations, Symbol(generator_elec_edge_data[:end_vertex]))
	generator_elec_edge = Edge(
		Symbol(id, "_", generator_elec_edge_key),
		generator_elec_edge_data,
		system.time_data[:Electricity],
		Electricity,
		elec_start_node,
		elec_end_node,
	)
	generator_elec_edge.unidirectional =
		get(generator_elec_edge_data, :unidirectional, true)
	generator_elec_edge.constraints =
		get(generator_elec_edge_data, :constraints, [CapacityConstraint()])
###############################WATER DISCHARGE EDGE#############################################	
	generator_water_edge_key = :discharge_edge_water
	generator_water_edge_data = process_data(data[:edges][generator_water_edge_key])
	water_start_node = hydrostor_reservoir
	water_end_node = generator_transform
	generator_water_edge = Edge(
		Symbol(id, "_", generator_water_edge_key),
		generator_water_edge_data,
		system.time_data[:Water],
		Water,
		water_start_node,
		water_end_node,
	)
	generator_water_edge.constraints = get(
		generator_water_edge_data,
		:constraints,
		[CapacityConstraint(), RampingLimitConstraint()],
	)
	generator_water_edge.unidirectional = get(generator_water_edge_data, :unidirectional, true)
###################################SPILLAGE EDGE##############################################	
	spillage_edge_key = :spillage_edge
	spillage_edge_data = process_data(data[:edges][spillage_edge_key])
	spillage_start_node = generator_transform
	spillage_end_node = find_node(system.locations, Symbol(spillage_edge_data[:end_vertex]))
	spillage_edge = Edge(
		Symbol(id, "_", spillage_edge_key),
		spillage_edge_data,
		system.time_data[:Water],
		Water,
		spillage_start_node,
		spillage_end_node,
	)
	spillage_edge.unidirectional = get(spillage_edge_data, :unidirectional, true)

##################################INFLOW EDGE WATER#################################################	
	inflow_edge_key = :inflow_edge_water
	inflow_edge_data = process_data(data[:edges][inflow_edge_key])
	inflow_start_node = find_node(system.locations, Symbol(inflow_edge_data[:start_vertex]))
	inflow_end_node = hydrostor_reservoir
	inflow_edge_water = Edge(
		Symbol(id, "_", inflow_edge_key),
		inflow_edge_data,
		system.time_data[:Water],
		Water,
		inflow_start_node,
		inflow_end_node,
	)
	inflow_edge_water.unidirectional = get(inflow_edge_data, :unidirectional, true)	
##################################PUMP EDGE WATER#################################################	
	pump_edge_key = :pump_edge_water
	pump_edge_data = process_data(data[:edges][pump_edge_key])
	pump_start_node = find_node(system.locations, Symbol(spillage_edge_data[:end_vertex]))
	pump_end_node = motor_transform
	pump_edge_water = Edge(
		Symbol(id, "_", pump_edge_key),
		pump_edge_data,
		system.time_data[:Water],
		Water,
		pump_start_node,
		pump_end_node,
	)
	pump_edge_water.unidirectional = get(pump_edge_data, :unidirectional, true)
##################################CHARGE EDGE WATER#################################################	
	charge_water_edge_key = :charge_edge_water
	charge_water_edge_data = process_data(data[:edges][charge_water_edge_key])
	charge_water_start_node = motor_transform
	charge_water_end_node = hydrostor_reservoir
	charge_water_edge = Edge(
		Symbol(id, "_", charge_water_edge_key),
		charge_water_edge_data,
		system.time_data[:Water],
		Water,
		charge_water_start_node,
		charge_water_end_node,
	)
	charge_water_edge.constraints =
        get(charge_water_edge_data, :constraints, [CapacityConstraint()])
	charge_water_edge.unidirectional = get(charge_water_edge_data, :unidirectional, true)
##################################CHARGE EDGE ELECTRICITY#################################################
	motor_elec_edge_key = :charge_edge_elec
	motor_elec_edge_data = process_data(data[:edges][motor_elec_edge_key])
	charge_elec_start_node = find_node(system.locations, Symbol(motor_elec_edge_data[:start_vertex]))
	charge_elec_end_node = motor_transform
	motor_elec_edge = Edge(
		Symbol(id, "_", motor_elec_edge_key),
		motor_elec_edge_data,
		system.time_data[:Electricity],
		Electricity,
		charge_elec_start_node,
		charge_elec_end_node,
	)
	motor_elec_edge.unidirectional =
		get(motor_elec_edge_data, :unidirectional, true)
	motor_elec_edge.constraints = get(
		motor_elec_edge_data,
		:constraints,
		[CapacityConstraint(), RampingLimitConstraint()],
	)
##################################END ALL EDGES#################################################
	hydrostor_reservoir.discharge_edge = generator_water_edge
	hydrostor_reservoir.charge_edge = charge_water_edge


	hydrostor_reservoir.balance_data = Dict(
        	:storage => Dict(
			generator_water_edge.id => 1 / get(generator_water_edge_data, :efficiency, 0.8),
			charge_water_edge.id => get(charge_water_edge_data, :efficiency, 0.8),
			inflow_edge_water.id => 1.0,
        	),
    	)

    	motor_transform.balance_data = Dict(
        	:electricity => Dict(
			pump_edge_water.id => get(transform_data, :electricity_consumption, 0.0),
			motor_elec_edge.id => 1.0,
			charge_water_edge.id => 0.0,
        	),
        	:water => Dict(
			charge_water_edge.id => 1.0,
            		pump_edge_water.id => 1.0,
            		motor_elec_edge.id => 0.0,
        	),
    	)

	generator_transform.balance_data = Dict(
        	:electricity => Dict(
			generator_water_edge.id => get(transform_data, :electricity_consumption, 0.0),
            		generator_elec_edge.id => 1.0,
            		spillage_edge.id => 0.0,
        	),
        	:water => Dict(
			spillage_edge.id => 1.0,
            		generator_water_edge.id => 1.0,
            		generator_elec_edge.id => 0.0,
        	),
    	)
    
	return HydroStor(
		id, 
		hydrostor_reservoir, 
		generator_transform,
		motor_transform,
		spillage_edge,
		charge_water_edge,
		generator_water_edge,
		generator_elec_edge,
		motor_elec_edge,
		inflow_edge_water,
		pump_edge_water
	)
end