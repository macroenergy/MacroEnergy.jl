module TestOutput

using Test
using Random
using MacroEnergy
using DataFrames
import MacroEnergy:
    TimeData,
    capacity,
    new_capacity,
    retired_capacity,
    flow,
    new_capacity,
    storage_level,
    non_served_demand,
    max_non_served_demand,
    edges_with_capacity_variables,
    get_commodity_name,
    get_commodity_subtype,
    get_edges,
    get_nodes,
    get_transformations,
    get_resource_id,
    get_component_id,
    get_zone_name,
    get_node_in,
    get_node_out,
    get_type,
    get_unit,
    get_optimal_vars,
    get_optimal_vars_timeseries,
    get_optimal_capacity_by_field,
    get_optimal_flow,
    convert_to_dataframe, 
    empty_system, 
    create_output_path,
    find_available_path,
    add!, 
    get_output_layout,
    filter_edges_by_asset_type!,
    value,
    Electricity,
    Node,
    Storage,
    Transformation,
    Edge,
    filter_edges_by_commodity!


function test_writing_output()

    # Mock objects to use in tests
    node1 = Node{Electricity}(;
        id=:node1,
        timedata=TimeData{Electricity}(;
            time_interval=1:3,
            hours_per_timestep=10,
            subperiods=[1:10, 11:20, 21:30],
            subperiod_indices=[1, 2, 3],
            subperiod_weights=Dict(1 => 0.3, 2 => 0.5, 3 => 0.2)
        ),
        max_nsd=[0.0, 1.0, 2.0]
    )
    node2 = Node{Electricity}(;
        id=:node2,
        timedata=TimeData{Electricity}(;
            time_interval=1:3,
            hours_per_timestep=10,
            subperiods=[1:10, 11:20, 21:30],
            subperiod_indices=[1, 2, 3],
            subperiod_weights=Dict(1 => 0.3, 2 => 0.5, 3 => 0.2)
        ),
        max_nsd=[3.0, 4.0, 5.0]
    )

    storage = Storage{Electricity}(;
        id=:storage1,
        timedata=TimeData{Electricity}(;
            time_interval=1:3,
            hours_per_timestep=10,
            subperiods=[1:10, 11:20, 21:30],
            subperiod_indices=[1, 2, 3],
            subperiod_weights=Dict(1 => 0.3, 2 => 0.5, 3 => 0.2)
        ),
        new_capacity=100.0,
        storage_level=[1.0, 2.0, 3.0]
    )

    transformation = Transformation(;
        id=:transformation1,
        timedata=TimeData{Electricity}(;
            time_interval=1:100,
            hours_per_timestep=10,
            subperiods=[1:10, 11:20, 21:30],
            subperiod_indices=[1, 2, 3],
            subperiod_weights=Dict(1 => 0.3, 2 => 0.5, 3 => 0.2)
        )
    )

    edge_between_nodes = Edge{Electricity}(;
        id=:edge1,
        start_vertex=node1,
        end_vertex=node2,
        timedata=TimeData{Electricity}(;
            time_interval=1:3,
            hours_per_timestep=10,
            subperiods=[1:10, 11:20, 21:30],
            subperiod_indices=[1, 2, 3],
            subperiod_weights=Dict(1 => 0.3, 2 => 0.5, 3 => 0.2)
        ),
        capacity=100.0,
        flow=[1.0, 2.0, 3.0]
    )

    edge_to_storage = Edge{Electricity}(;
        id=:edge2,
        start_vertex=node1,
        end_vertex=storage,
        timedata=TimeData{Electricity}(;
            time_interval=1:3,
            hours_per_timestep=10,
            subperiods=[1:10, 11:20, 21:30],
            subperiod_indices=[1, 2, 3],
            subperiod_weights=Dict(1 => 0.3, 2 => 0.5, 3 => 0.2)
        ),
        capacity=101.0,
        flow=[4.0, 5.0, 6.0]
    )

    edge_to_transformation = Edge{Electricity}(;
        id=:edge3,
        start_vertex=node1,
        end_vertex=transformation,
        has_capacity=true,
        timedata=TimeData{Electricity}(;
            time_interval=1:3,
            hours_per_timestep=10,
            subperiods=[1:10, 11:20, 21:30],
            subperiod_indices=[1, 2, 3],
            subperiod_weights=Dict(1 => 0.3, 2 => 0.5, 3 => 0.2)
        ),
        capacity=102.0,
        flow=[7.0, 8.0, 9.0]
    )

    edge_from_storage = Edge{Electricity}(;
        id=:edge4,
        start_vertex=storage,
        end_vertex=node2,
        timedata=TimeData{Electricity}(;
            time_interval=1:3,
            hours_per_timestep=10,
            subperiods=[1:10, 11:20, 21:30],
            subperiod_indices=[1, 2, 3],
            subperiod_weights=Dict(1 => 0.3, 2 => 0.5, 3 => 0.2)
        ),
        capacity=103.0,
        flow=[10.0, 11.0, 12.0]
    )

    edge_from_transformation = Edge{Electricity}(;
        id=:edge5,
        start_vertex=transformation,
        end_vertex=node2,
        timedata=TimeData{Electricity}(;
            time_interval=1:3,
            hours_per_timestep=10,
            subperiods=[1:10, 11:20, 21:30],
            subperiod_indices=[1, 2, 3],
            subperiod_weights=Dict(1 => 0.3, 2 => 0.5, 3 => 0.2)
        ),
        capacity=104.0,
        flow=[13.0, 14.0, 15.0]
    )

    edge_storage_transformation = Edge{Electricity}(;
        id=:edge6,
        start_vertex=storage,
        end_vertex=transformation,
        timedata=TimeData{Electricity}(;
            time_interval=1:3,
            hours_per_timestep=10,
            subperiods=[1:10, 11:20, 21:30],
            subperiod_indices=[1, 2, 3],
            subperiod_weights=Dict(1 => 0.3, 2 => 0.5, 3 => 0.2)
        ),
        capacity=105.0,
        flow=[16.0, 17.0, 18.0]
    )

    edge_from_transformation1 = Edge{NaturalGas}(;
        id=:edge3ng,
        start_vertex=transformation,
        end_vertex=node1,
        timedata=TimeData{NaturalGas}(;
            time_interval=1:3,
            hours_per_timestep=10,
            subperiods=[1:10, 11:20, 21:30],
            subperiod_indices=[1, 2, 3],
            subperiod_weights=Dict(1 => 0.3, 2 => 0.5, 3 => 0.2)
        ),
        capacity=102.0,
        flow=[7.0, 8.0, 9.0]
    )

    edge_from_transformation2 = Edge{CO2}(;
        id=:edge3co2,
        start_vertex=transformation,
        end_vertex=node1,
        timedata=TimeData{CO2}(;
            time_interval=1:3,
            hours_per_timestep=10,
            subperiods=[1:10, 11:20, 21:30],
            subperiod_indices=[1, 2, 3],
            subperiod_weights=Dict(1 => 0.3, 2 => 0.5, 3 => 0.2)
        ),
        capacity=102.0,
        flow=[7.0, 8.0, 9.0]
    )

    asset1 = ThermalPower(:asset1, transformation, edge_to_transformation, edge_from_transformation1, edge_from_transformation2)
    asset_ref = Ref(asset1)
    asset_map = Dict{Symbol, Base.RefValue{<: AbstractAsset}}(
        :edge3 => asset_ref,
        :edge3ng => asset_ref,
        :edge3co2 => asset_ref
    )

    asset2 = Battery(:asset2, storage, edge_to_storage, edge_from_storage)
    asset_ref2 = Ref(asset2)
    asset_map2 = Dict{Symbol, Base.RefValue{<: AbstractAsset}}(
        :edge2 => asset_ref2,
        :edge4 => asset_ref2,
        :storage1 => asset_ref2
    )

    system = empty_system(@__DIR__)
    add!(system, node1)
    add!(system, node2)
    add!(system, asset1)
    add!(system, asset2)

    @testset "Helper Functions Tests" begin
        # Test get_commodity_name for a vertex
        @test get_commodity_name(node1) == :Electricity
        @test get_commodity_name(node2) == :Electricity
        @test get_commodity_name(storage) == :Electricity

        # Test get_commodity_name for an edge
        @test get_commodity_name(edge_between_nodes) == :Electricity
        @test get_commodity_name(edge_to_storage) == :Electricity
        @test get_commodity_name(edge_to_transformation) == :Electricity
        @test get_commodity_name(edge_from_storage) == :Electricity
        @test get_commodity_name(edge_from_transformation) == :Electricity
        @test get_commodity_name(edge_storage_transformation) == :Electricity

        # Test get_commodity_subtype for a vertex
        @test get_commodity_subtype(capacity) == :capacity
        @test get_commodity_subtype(new_capacity) == :capacity
        @test get_commodity_subtype(retired_capacity) == :capacity
        @test get_commodity_subtype(flow) == :flow
        @test get_commodity_subtype(storage_level) == :storage_level
        @test get_commodity_subtype(non_served_demand) == :non_served_demand

        # Test get_resource_id for a vertex
        @test get_resource_id(node1) == :node1
        @test get_resource_id(node2) == :node2
        @test get_resource_id(storage, asset_map2) == :asset2
        @test get_resource_id(edge_from_storage, asset_map2) == :asset2
        @test get_resource_id(edge_to_storage, asset_map2) == :asset2
        @test get_resource_id(edge_to_transformation, asset_map) == :asset1
        @test get_resource_id(edge_from_transformation1, asset_map) == :asset1

        # Test get_component_id for a vertex
        @test get_component_id(node1) == :node1
        @test get_component_id(node2) == :node2
        @test get_component_id(storage) == :storage1

        # Test get_component_id for an edge
        @test get_component_id(edge_between_nodes) == :edge1
        @test get_component_id(edge_to_storage) == :edge2
        @test get_component_id(edge_to_transformation) == :edge3
        @test get_component_id(edge_from_storage) == :edge4
        @test get_component_id(edge_from_transformation) == :edge5
        @test get_component_id(edge_storage_transformation) == :edge6

        # Test get_zone_name for a vertex
        @test get_zone_name(node1) == :node1
        @test get_zone_name(node2) == :node2
        @test get_zone_name(storage) == :storage1
        @test get_zone_name(transformation) == :transformation1

        # Test get_zone_name for an edge
        @test get_zone_name(edge_between_nodes) == :node1_node2
        @test get_zone_name(edge_to_storage) == :node1
        @test get_zone_name(edge_to_transformation) == :node1
        @test get_zone_name(edge_from_storage) == :node2
        @test get_zone_name(edge_from_transformation) == :node2
        @test get_zone_name(edge_storage_transformation) == :internal

        # Test new location functions for flow outputs
        @test get_node_in(edge_between_nodes) == :node1
        @test get_node_out(edge_between_nodes) == :node2
        
        @test get_node_in(edge_to_storage) == :node1
        @test get_node_out(edge_to_storage) == :storage1
        
        @test get_node_in(edge_from_storage) == :storage1
        @test get_node_out(edge_from_storage) == :node2
        
        @test get_node_in(edge_to_transformation) == :node1
        @test get_node_out(edge_to_transformation) == :transformation1
        
        @test get_node_in(edge_from_transformation1) == :transformation1
        @test get_node_out(edge_from_transformation1) == :node1
        
        @test get_node_in(edge_storage_transformation) == :storage1
        @test get_node_out(edge_storage_transformation) == :transformation1

        # Test get_type
        @test get_type(asset_ref) === Symbol("ThermalPower{NaturalGas}")
        @test get_type(asset_ref2) === Symbol("Battery")
    end

    mock_edges = [edge_between_nodes,
        edge_to_storage,
        edge_to_transformation,
        edge_from_storage,
        edge_from_transformation,
        edge_storage_transformation
    ]

    obj_asset_map = Dict{Symbol, Base.RefValue{<: AbstractAsset}}(
        :edge1 => asset_ref,
        :edge2 => asset_ref,
        :edge3 => asset_ref,
        :edge4 => asset_ref,
        :edge5 => asset_ref,
        :edge6 => asset_ref
    )

    @testset "get_optimal_vars Tests" begin
        result = get_optimal_vars(mock_edges, capacity, 2.0, obj_asset_map)
        @test size(result, 1) == 6
        @test result[1, :commodity] === :Electricity
        @test result[1, :commodity_subtype] === :capacity
        @test result[1, :zone] === :node1_node2
        @test result[1, :resource_id] === :asset1
        @test result[1, :component_id] === :edge1
        @test result[1, :type] === Symbol("ThermalPower{NaturalGas}")
        @test result[1, :variable] === :capacity
        @test result[1, :year] === missing
        @test result[1, :value] === 200.0
        @test result[2, :commodity] === :Electricity
        @test result[2, :commodity_subtype] === :capacity
        @test result[2, :zone] === :node1
        @test result[2, :resource_id] === :asset1
        @test result[2, :component_id] === :edge2
        @test result[2, :type] === Symbol("ThermalPower{NaturalGas}")
        @test result[2, :variable] === :capacity
        @test result[2, :year] === missing
        @test result[2, :value] === 202.0
        @test result[3, :commodity] === :Electricity
        @test result[3, :commodity_subtype] === :capacity
        @test result[3, :zone] === :node1
        @test result[3, :resource_id] === :asset1
        @test result[3, :component_id] === :edge3
        @test result[3, :type] === Symbol("ThermalPower{NaturalGas}")
        @test result[3, :value] === 204.0
        @test result[4, :commodity] === :Electricity
        @test result[4, :commodity_subtype] === :capacity
        @test result[4, :zone] === :node2
        @test result[4, :resource_id] === :asset1
        @test result[4, :component_id] === :edge4
        @test result[4, :type] === Symbol("ThermalPower{NaturalGas}")
        @test result[4, :value] === 206.0
        @test result[5, :commodity] === :Electricity
        @test result[5, :commodity_subtype] === :capacity
        @test result[5, :zone] === :node2
        @test result[5, :resource_id] === :asset1
        @test result[5, :component_id] === :edge5
        @test result[5, :type] === Symbol("ThermalPower{NaturalGas}")
        @test result[5, :value] === 208.0
        @test result[6, :commodity] === :Electricity
        @test result[6, :commodity_subtype] === :capacity
        @test result[6, :zone] === :internal
        @test result[6, :resource_id] === :asset1
        @test result[6, :component_id] === :edge6
        @test result[6, :type] === Symbol("ThermalPower{NaturalGas}")
        @test result[6, :value] === 210.0
        result = get_optimal_vars(Edge{Electricity}[edge_between_nodes], (new_capacity), 5.0)
        @test size(result, 1) == 1
        @test result[1, :commodity] === :Electricity
        @test result[1, :commodity_subtype] === :capacity
        @test result[1, :zone] === :node1_node2
        @test result[1, :resource_id] === :edge1
        @test result[1, :component_id] === :edge1
        @test result[1, :type] === Symbol("Edge{Electricity}")
        @test result[1, :value] === 0.0
        result = get_optimal_vars(Storage[storage], new_capacity, 5.0, Dict{Symbol, Base.RefValue{<: AbstractAsset}}(:storage1 => asset_ref2))
        @test size(result, 1) == 1
        @test result[1, :commodity] === :Electricity
        @test result[1, :commodity_subtype] === :capacity
        @test result[1, :zone] === :storage1
        @test result[1, :resource_id] === :asset2
        @test result[1, :component_id] === :storage1
        @test result[1, :type] === Symbol("Battery")
        @test result[1, :value] === 500.0
        result = get_optimal_vars(Storage[storage], (new_capacity), 5.0, Dict{Symbol, Base.RefValue{<: AbstractAsset}}(:storage1 => asset_ref2))
        @test size(result, 1) == 1
        @test result[1, :commodity] === :Electricity
        @test result[1, :commodity_subtype] === :capacity
        @test result[1, :zone] === :storage1
        @test result[1, :resource_id] === :asset2
        @test result[1, :component_id] === :storage1
        @test result[1, :type] === Symbol("Battery")
        @test result[1, :value] === 500.0
    end

    function check_output_row(row, expected_commodity, expected_commodity_subtype, expected_zone, expected_resource_id, expected_component_id, expected_type, expected_variable, expected_year, expected_segment, expected_time, expected_value)
        @test row.commodity == expected_commodity
        @test row.commodity_subtype == expected_commodity_subtype
        @test row.zone == expected_zone
        @test row.resource_id == expected_resource_id
        @test row.component_id == expected_component_id
        @test row.type == expected_type
        @test row.variable == expected_variable
        @test row.year === expected_year
        @test row.segment == expected_segment
        @test row.time == expected_time
        @test row.value == expected_value
        # @test row.unit == expected_unit
    end

    @testset "get_optimal_vars_timeseries Tests" begin
        expected_values = [
            (:Electricity, :flow, :node1_node2, :asset1, :edge1, Symbol("ThermalPower{NaturalGas}"), :flow, missing, 1, [1, 2, 3], [1.0, 2.0, 3.0]) #, :MWh),
            (:Electricity, :flow, :node1, :asset1, :edge2, Symbol("ThermalPower{NaturalGas}"), :flow, missing, 1, [1, 2, 3], [4.0, 5.0, 6.0]) #, :MWh),
            (:Electricity, :flow, :node1, :asset1, :edge3, Symbol("ThermalPower{NaturalGas}"), :flow, missing, 1, [1, 2, 3], [7.0, 8.0, 9.0]) #, :MWh),
            (:Electricity, :flow, :node2, :asset1, :edge4, Symbol("ThermalPower{NaturalGas}"), :flow, missing, 1, [1, 2, 3], [10.0, 11.0, 12.0]) #, :MWh),
            (:Electricity, :flow, :node2, :asset1, :edge5, Symbol("ThermalPower{NaturalGas}"), :flow, missing, 1, [1, 2, 3], [13.0, 14.0, 15.0]) #, :MWh),
            (:Electricity, :flow, :internal, :asset1, :edge6, Symbol("ThermalPower{NaturalGas}"), :flow, missing, 1, [1, 2, 3], [16.0, 17.0, 18.0]) #, :MWh)
        ]
        result = get_optimal_vars_timeseries(mock_edges, flow, 1.0, obj_asset_map)
        @test size(result, 1) == 18
        index = 1
        for (commodity, commodity_subtype, zone, resource_id, component_id, type, variable, year, segment, times, values) in expected_values
            for i in eachindex(times)
                check_output_row(result[index, :], commodity, commodity_subtype, zone, resource_id, component_id, type, variable, year, segment, times[i], values[i])
                index += 1
            end
        end
        result = get_optimal_vars_timeseries(storage, storage_level, 1.0, Dict{Symbol, Base.RefValue{<: AbstractAsset}}(:storage1 => asset_ref2))
        @test size(result, 1) == 3
        for i = 1:3
            check_output_row(result[i, :], :Electricity, :storage_level, :storage1, :asset2, :storage1, :Battery, :storage_level, missing, 1, i, i)
        end
        result = get_optimal_vars_timeseries(storage, tuple(storage_level), 1.0, Dict{Symbol, Base.RefValue{<: AbstractAsset}}(:storage1 => asset_ref2))
        @test size(result, 1) == 3
        for i = 1:3
            check_output_row(result[i, :], :Electricity, :storage_level, :storage1, :asset2, :storage1, :Battery, :storage_level, missing, 1, i, i)
        end
        result = get_optimal_vars_timeseries([node1, node2], max_non_served_demand, 1.0)
        @test size(result, 1) == 6
        for i = 1:6
            check_output_row(result[i, :], :Electricity, :max_non_served_demand, i <= 3 ? :node1 : :node2, i <= 3 ? :node1 : :node2, i <= 3 ? :node1 : :node2, Symbol("Node{Electricity}"), :max_non_served_demand, missing, 1, (i-1) % 3 + 1, i-1)
        end
        result = get_optimal_vars_timeseries([node1, node2], tuple(max_non_served_demand), 1.0)
        @test size(result, 1) == 6
        for i = 1:6
            check_output_row(result[i, :], :Electricity, :max_non_served_demand, i <= 3 ? :node1 : :node2, i <= 3 ? :node1 : :node2, i <= 3 ? :node1 : :node2, Symbol("Node{Electricity}"), :max_non_served_demand, missing, 1, (i-1) % 3 + 1, i-1)
        end
    end

    @testset "DataFrame Output Functions Tests" begin
        # Test get_optimal_capacity_by_field
        result = get_optimal_capacity_by_field(mock_edges, (capacity,), 2.0, obj_asset_map)
        @test result isa DataFrame
        @test size(result, 1) == 6  # 6 edges × 1 field
        
        # Check first result structure
        @test result[1, :commodity] == :Electricity
        @test result[1, :commodity_subtype] == :capacity
        @test result[1, :zone] == :node1_node2
        @test result[1, :resource_id] == :asset1
        @test result[1, :component_id] == :edge1
        @test result[1, :type] == Symbol("ThermalPower{NaturalGas}")
        @test result[1, :variable] == :capacity
        @test result[1, :year] === missing
        @test result[1, :value] == 200.0
        
        # Test without asset map
        result_fast = get_optimal_capacity_by_field(mock_edges, (capacity,), 1.0)
        @test result_fast isa DataFrame
        @test size(result_fast, 1) == 6
        @test result_fast[1, :value] == 100.0  # No scaling applied
    end

    @testset "Flow Output Functions Tests" begin
        # Test get_optimal_flow
        result = get_optimal_flow(mock_edges, 1.0, obj_asset_map)
        @test result isa DataFrame
        @test size(result, 1) == 18
        
        # Check first result structure (node1 -> node2)
        @test result[1, :commodity] == :Electricity
        @test result[1, :commodity_subtype] == :flow
        @test result[1, :node_in] == :node1
        @test result[1, :node_out] == :node2
        @test result[1, :resource_id] == :asset1
        @test result[1, :component_id] == :edge1
        @test result[1, :type] == Symbol("ThermalPower{NaturalGas}")
        @test result[1, :variable] == :flow
        @test result[1, :year] === missing
        @test result[1, :time] === 1
        @test result[1, :value] == 1.0

        # Check second time step result structure (node1 -> node2)
        @test result[2, :node_in] == :node1
        @test result[2, :node_out] == :node2
        @test result[2, :value] == 2.0

        # Check third time step result structure (node1 -> node2)
        @test result[3, :node_in] == :node1
        @test result[3, :node_out] == :node2
        @test result[3, :value] == 3.0
        
        # Check storage flow (node1 -> storage1)
        @test result[4, :node_in] == :node1
        @test result[4, :node_out] == :storage1
        @test result[4, :value] == 4.0
        
        # Check transformation flow (node1 -> transformation1)
        @test result[7, :node_in] == :node1
        @test result[7, :node_out] == :transformation1
        @test result[7, :value] == 7.0
        
        # Check storage discharge (storage1 -> node2)
        @test result[10, :node_in] == :storage1
        @test result[10, :node_out] == :node2
        @test result[10, :value] == 10.0
        
        # Check transformation output (transformation1 -> node1)
        @test result[13, :node_in] == :transformation1
        @test result[13, :node_out] == :node2
        @test result[13, :value] == 13.0
        
        # Check internal flow (storage1 -> transformation1)
        @test result[16, :node_in] == :storage1
        @test result[16, :node_out] == :transformation1
        @test result[16, :value] == 16.0
        
        # Test without asset map
        result_fast = get_optimal_flow(mock_edges, 1.0)
        @test result_fast isa DataFrame
        @test size(result_fast, 1) == 18
        @test result_fast[1, :value] == 1.0  # No scaling applied
    end

    @testset "Timeseries Functions Tests" begin
        # Test get_optimal_vars_timeseries for flow data
        result = get_optimal_vars_timeseries(mock_edges, flow, 1.0, obj_asset_map)
        @test result isa DataFrame
        @test size(result, 1) == 18  # 6 edges × 3 time steps
        
        # Check first result structure
        @test result[1, :commodity] == :Electricity
        @test result[1, :commodity_subtype] == :flow
        @test result[1, :zone] == :node1_node2
        @test result[1, :resource_id] == :asset1
        @test result[1, :component_id] == :edge1
        @test result[1, :type] == Symbol("ThermalPower{NaturalGas}")
        @test result[1, :variable] == :flow
        @test result[1, :year] === missing
        @test result[1, :segment] == 1
        @test result[1, :time] == 1
        @test result[1, :value] == 1.0
        
        # Check time progression
        @test result[2, :time] == 2
        @test result[2, :value] == 2.0
        @test result[3, :time] == 3
        @test result[3, :value] == 3.0
        
        # Check next edge (edge2: node1 -> storage1)
        @test result[4, :zone] == :node1
        @test result[4, :time] == 1
        @test result[4, :value] == 4.0
    end

    # Test get_macro_objs functions
    @testset "get_macro_objs Tests" begin
        edges = get_edges([asset1, asset2])
        @test length(edges) == 5
        @test edges[1] == edge_to_transformation
        @test edges[2] == edge_from_transformation1
        @test edges[3] == edge_from_transformation2
        @test edges[4] == edge_to_storage
        @test edges[5] == edge_from_storage
        sys_edges = get_edges(system)
        @test length(sys_edges) == 5
        @test sys_edges == edges
        nodes = get_nodes(system)
        @test length(nodes) == 2
        @test nodes[1] == node1
        @test nodes[2] == node2
        transformations = get_transformations(system)
        @test length(transformations) == 1
        @test transformations[1] == transformation
    end

    # Test filtering of edges by commodity
    @testset "filter_edges_by_commodity Tests" begin
        filtered_edges = get_edges(system)
        filter_edges_by_commodity!(filtered_edges, :Electricity)

        @test length(filtered_edges) == 3
        @test filtered_edges[1] == edge_to_transformation
        @test filtered_edges[2] == edge_to_storage
        @test filtered_edges[3] == edge_from_storage

        filtered_edges, filtered_edge_asset_map = get_edges(system, return_ids_map=true)
        filter_edges_by_commodity!(filtered_edges, :Electricity, filtered_edge_asset_map)
        @test length(filtered_edges) == 3
        @test filtered_edges[1] == edge_to_transformation
        @test filtered_edges[2] == edge_to_storage
        @test filtered_edges[3] == edge_from_storage
        @test filtered_edge_asset_map[:edge3][] == asset1
        @test filtered_edge_asset_map[:edge2][] == asset2
        @test filtered_edge_asset_map[:edge4][] == asset2
    end

    # Test filtering of edges by asset type
    @testset "filter_edges_by_asset_type Tests" begin
        filtered_edges, filtered_edge_asset_map = get_edges(system, return_ids_map=true)
        filter_edges_by_asset_type!(filtered_edges, :Battery, filtered_edge_asset_map)
        @test length(filtered_edges) == 2
        @test filtered_edges[1] == edge_to_storage
        @test filtered_edges[2] == edge_from_storage
        @test filtered_edge_asset_map[:edge2][] == asset2
        @test filtered_edge_asset_map[:edge4][] == asset2
    end

    # Test filtering with wrong commodity or asset type
    @testset "filter_edges_by_commodity_and_asset_type Tests" begin
        filtered_edges, filtered_edge_asset_map = get_edges(system, return_ids_map=true)
        @test_throws ArgumentError filter_edges_by_commodity!(filtered_edges, :UnknownCommodity)
        @test_throws ArgumentError filter_edges_by_asset_type!(filtered_edges, :UnknownAssetType, filtered_edge_asset_map)
    end

    # Test edges_with_capacity_variables
    @testset "edges_with_capacity_variables Tests" begin
        edges_with_capacity = edges_with_capacity_variables([asset1, asset2])
        @test length(edges_with_capacity) == 1
        @test edges_with_capacity[1] == edge_to_transformation
        edges_with_capacity, edge_asset_map = edges_with_capacity_variables([asset1, asset2], return_ids_map=true)
        @test length(edges_with_capacity) == 1
        @test edges_with_capacity[1] == edge_to_transformation
        @test edge_asset_map[:edge3][] == asset1
        edges_with_capacity = edges_with_capacity_variables(asset1)
        @test length(edges_with_capacity) == 1
        @test edges_with_capacity[1] == edge_to_transformation
        edges_with_capacity = edges_with_capacity_variables(system)
        @test length(edges_with_capacity) == 1
        @test edges_with_capacity[1] == edge_to_transformation
    end

    @testset "get_output_dir Tests" begin
        # Create a temporary directory for testing
        test_dir = abspath(mktempdir("."))
        
        # Create a mock system with different settings
        system1 = empty_system(test_dir)
        system1.settings = (OutputDir = "results", OverwriteResults = true)
        
        # Test overwriting existing directory
        output_path1 = create_output_path(system1)
        @test isdir(output_path1)
        @test output_path1 == joinpath(test_dir, "results")
        
        # Create second path - should still use same directory
        output_path2 = create_output_path(system1)
        @test output_path2 == output_path1
        
        # Test with OverwriteResults = 0 (no overwrite)
        system2 = empty_system(test_dir)
        system2.settings = (OutputDir = "results", OverwriteResults = false)
        
        # This is the second call, so it should create "results_001"
        output_path3 = create_output_path(system2)
        @test isdir(output_path3)
        @test output_path3 == joinpath(test_dir, "results_001")
        
        # Third call should create "results_002"
        output_path4 = create_output_path(system2)
        @test isdir(output_path4)
        @test output_path4 == joinpath(test_dir, "results_002")

        # Test with path argument specified
        output_path6 = create_output_path(system2, joinpath(test_dir, "path", "to", "output"))
        @test isdir(output_path6)
        @test output_path6 == joinpath(test_dir, "path", "to", "output", "results_001")

        # Second call with path argument should create "path/to/output/results_002"
        output_path7 = create_output_path(system2, joinpath(test_dir, "path", "to", "output"))
        @test isdir(output_path7)
        @test output_path7 == joinpath(test_dir, "path", "to", "output", "results_002")
        
        # Cleanup
        rm(test_dir, recursive=true)

        @testset "choose_output_dir Tests" begin
            # Create a temporary directory for testing
            test_dir = abspath(mktempdir("."))
            
            # Test with non-existing directory
            result = find_available_path(test_dir)
            @test result == joinpath(test_dir, "results_001") # Should return original path if it doesn't exist
            
            
            # Create multiple directories and test incremental numbering
            mkpath(joinpath(test_dir, "newdir_002"))
            mkpath(joinpath(test_dir, "newdir_004"))
            result = find_available_path(test_dir, "newdir")
            @test result == joinpath(test_dir, "newdir_001")  # Should append _001

            mkpath(joinpath(test_dir, "newdir_001"))
            result = find_available_path(test_dir, "newdir")
            @test result == joinpath(test_dir, "newdir_003")

            # Test with path containing trailing slash
            path_with_slash = joinpath(test_dir, "dirwithslash/")
            mkpath(path_with_slash)
            result = find_available_path(path_with_slash)
            @test result == joinpath(test_dir, "dirwithslash", "results_001")
            
            # Test with path containing spaces
            path_with_spaces = joinpath(test_dir, "my dir")
            mkpath(path_with_spaces)
            result = find_available_path(path_with_spaces)
            @test result == joinpath(test_dir, "my dir", "results_001")
            
            # Cleanup
            rm(test_dir, recursive=true)
        end
    end

    @testset "get_output_layout" begin
        # Helper to create a minimal System struct with settings
        function make_test_system(layout)
            system = empty_system("random_path_$(randstring(8))")
            system.settings = (OutputLayout=layout,)
            return system
        end
    
        @testset "String layouts" begin
            # Test valid string inputs
            @test get_output_layout(make_test_system("wide")) == "wide"
            @test get_output_layout(make_test_system("long")) == "long"
        end
    
        @testset "NamedTuple layouts" begin
            ## Test NamedTuple
            layout_settings = (capacity="wide", storage="long")
            system = make_test_system(layout_settings)
            # no variable
            @test_logs (:warn, "OutputLayout in settings does not have a variable key. Using 'long' as default.") begin
                @test get_output_layout(system) == "long"
            end

            # with existing keys
            @test get_output_layout(system, :capacity) == "wide"
            @test get_output_layout(system, :storage) == "long"
    
            # Test missing key falls back to "long" with warning
            @test_logs (:warn, "OutputLayout in settings does not have a missing_var key. Using 'long' as default.") begin
                @test get_output_layout(system, :missing_var) == "long"
            end
        end
    
        @testset "Invalid layout types" begin
            # Test unexpected type with warning
            invalid_system = make_test_system(42)  # Integer is not a valid layout type
            @test_logs (:warn, "OutputLayout type Int64 not supported. Using 'long' as default.") begin
                @test get_output_layout(invalid_system, :any_variable) == "long"
            end
        end
    end
end

test_writing_output()

end # module TestOutput

