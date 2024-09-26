struct HydroStor <: AbstractAsset
	id::AssetId
	hydrostor_reservoir::Storage{Water}
	generator_transform::Transformation
	motor_transform::Transformation
	spillage_edge::Edge{Water}
	charge_edge_water::Edge{Water}
	discharge_edge_water::Edge{Water}
	discharge_edge_elec::Edge{Electricity}
	charge_edge_elec::Edge{Electricity}
	inflow_edge_water::Edge{Water}
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

	hydrostor_reservoir_key = :storage

	storage_data = process_data(data[:hydrostor_reservoir_key])
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
	generator_elec_edge.constraints =
		get(generator_elec_edge_data, :constraints, [CapacityConstraint()])
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
	inflow_edge.constraints =
		get(inflow_edge_data, :constraints, [CapacityConstraint()])
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
	motor_elec_edge.constraints =
		get(motor_elec_edge_data, :constraints, [CapacityConstraint()])
	motor_elec_edge.unidirectional =
		get(motor_elec_edge_data, :unidirectional, true)
##################################END ALL EDGES#################################################			
    
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