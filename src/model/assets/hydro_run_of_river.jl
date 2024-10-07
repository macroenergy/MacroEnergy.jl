struct HydroElectric <: AbstractAsset
	id::AssetId
	hydroelectric_reservoir::Storage{Water}
	generator_transform::Transformation
	spillage_edge::Edge{Water}
	discharge_edge_water::Edge{Water}
	discharge_edge_elec::Edge{Electricity}
	inflow_edge_water::Edge{Water}
end
    
id(hs::HydroElectric) = he.id

function make(::Type{HydroElectric}, data::AbstractDict{Symbol,Any}, system::System)
	id = AssetId(data[:id])

	hydroelectric_reservoir_key = :storage

	storage_data = process_data(data[hydroelectric_reservoir_key])
	commodity_symbol = Symbol(storage_data[:commodity])
	commodity = commodity_types()[commodity_symbol]

	hydroelectric_reservoir = Storage(
        	Symbol(id, "_", hydroelectric_reservoir_key),
        	storage_data,
        	system.time_data[:Water],
        	Water,
    	)

	hydroelectric_reservoir.constraints = get(
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
	spillage_edge.unidirectional = get(generator_water_edge_data, :unidirectional, true)
##################################INFLOW EDGE WATER#################################################	
	inflow_edge_key = :inflow_edge_water
	inflow_edge_data = process_data(data[:edges][inflow_edge_key])
	inflow_start_node = find_node(system.locations, Symbol(inflow_edge_data[:start_vertex]))
	inflow_end_node = motor_transform
	inflow_edge_water = Edge(
		Symbol(id, "_", inflow_edge_key),
		inflow_edge_data,
		system.time_data[:Water],
		Water,
		inflow_start_node,
		inflow_end_node,
	)
	inflow_edge.unidirectional = get(inflow_edge_data, :unidirectional, true)
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
##################################END ALL EDGES#################################################

	hydrostor_reservoire.balance_data = Dict(
        	:storage => Dict(
			hydrostor_reservoir_discharge.id => 1 / get(discharge_edge_data, :efficiency, 1.0),
			hydrostor_reservoir_charge.id => get(charge_edge_data, :efficiency, 1.0),
        	),
    	)

    	motor_transform.balance_data = Dict(
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

	generator_transform.balance_data = Dict(
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
    
	return HydroStor(
		id, 
		hydrostor_reservoir, 
		generator_transform,
		motor_transform,
		generator_elec_edge,
		generator_water_edge,
		spillage_edge,
		inflow_edge_water,
		charge_water_edge,
		motor_elec_edge
	)
end