module TestOutput

using Test
using Random
using MacroEnergy
using CSV
using DataFrames
import MacroEnergy:
    TimeData,
    compute_annualized_costs!,
    discount_fixed_costs!,
    get_detailed_costs,
    get_optimal_curtailment,
    capacity,
    variable_om_cost,
    fixed_om_cost,
    annualized_investment_cost,
    capital_recovery_period,
    current_subperiod,
    subperiod_weight,
    time_interval,
    start_vertex,
    price,
    total_years,
    present_value_factor,
    present_value_annuity_factor,
    capital_recovery_factor,
    new_capacity,
    retired_capacity,
    flow,
    new_capacity,
    storage_level,
    non_served_demand,
    segments_non_served_demand,
    price_non_served_demand,
    max_non_served_demand,
    edges_with_capacity_variables,
    get_commodity_name,
    get_edges,
    get_nodes,
    get_storages,
    get_transformations,
    get_resource_id,
    get_component_id,
    get_zone_name,
    get_node_in,
    get_node_out,
    get_type,
    get_unit,
    get_optimal_capacity_by_field,
    get_optimal_flow,
    get_optimal_non_served_demand,
    get_optimal_storage_level,
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
    filter_edges_by_commodity!,
    write_curtailment,
    VRE


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
        price = [10.0, 11.0, 12.0],
        price_supply = [100.0, 110.0, 120.0],
        max_supply = [100.0, 110.0, 120.0],
        supply_flow = zeros(3, 3),  # 3 segments × 3 time steps
        non_served_demand = [1.0 2.0 3.0; 4.0 5.0 6.0; 7.0 8.0 9.0],
        max_nsd=[10.0, 11.0, 12.0],
        price_nsd = [100.0, 110.0, 120.0],
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
        @test get_zone_name(node1) == "node1"
        @test get_zone_name(node2) == "node2"
        @test get_zone_name(storage) == "storage1"
        @test get_zone_name(transformation) == "transformation1"

        # Test get_zone_name for an edge
        @test get_zone_name(edge_between_nodes) == "node1_node2"
        @test get_zone_name(edge_to_storage) == "node1_storage1"
        @test get_zone_name(edge_to_transformation) == "node1_transformation1"
        @test get_zone_name(edge_from_storage) == "storage1_node2"
        @test get_zone_name(edge_from_transformation) == "transformation1_node2"
        @test get_zone_name(edge_storage_transformation) == "storage1_transformation1"

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
        @test get_type(asset_ref) == "ThermalPower{NaturalGas}"
        @test get_type(asset_ref2) == "Battery"
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

    @testset "DataFrame Output Functions Tests" begin
        # Test get_optimal_capacity_by_field
        result = get_optimal_capacity_by_field(mock_edges, (capacity,), 2.0, obj_asset_map)
        @test result isa DataFrame
        @test size(result, 1) == 6  # 6 edges × 1 field
        
        # Check first result structure
        @test result[1, :commodity] == :Electricity
        @test result[1, :zone] == "node1_node2"
        @test result[1, :resource_id] == :asset1
        @test result[1, :component_id] == :edge1
        @test result[1, :resource_type] == "ThermalPower{NaturalGas}"
        @test result[1, :component_type] == "Edge{Electricity}"
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
        @test result[1, :node_in] == :node1
        @test result[1, :node_out] == :node2
        @test result[1, :resource_id] == :asset1
        @test result[1, :component_id] == :edge1
        @test result[1, :resource_type] == "ThermalPower{NaturalGas}"
        @test result[1, :component_type] == "Edge{Electricity}"
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
        @test result[4, :value] == -4.0
        
        # Check transformation flow (node1 -> transformation1)
        @test result[7, :node_in] == :node1
        @test result[7, :node_out] == :transformation1
        @test result[7, :value] == -7.0
        
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

    @testset "Non-Served Demand Output Functions Tests" begin
        # Create nodes with non-served demand variables
        node_with_nsd = Node{Electricity}(;
            id=:node_nsd,
            timedata=TimeData{Electricity}(;
                time_interval=1:3,
                hours_per_timestep=10,
                subperiods=[1:10, 11:20, 21:30],
                subperiod_indices=[1, 2, 3],
                subperiod_weights=Dict(1 => 0.3, 2 => 0.5, 3 => 0.2)
            ),
            max_nsd=[0.1, 0.2],  # 2 segments
            non_served_demand=[1.0 2.0 3.0; 4.0 5.0 6.0]  # 2 segments × 3 time steps
        )
        
        # Test get_optimal_non_served_demand for single node
        result = get_optimal_non_served_demand(node_with_nsd, 1.0)
        @test result isa DataFrame
        @test size(result, 1) == 6  # 2 segments × 3 time steps
        
        # Check structure
        @test result[1, :commodity] == :Electricity
        @test result[1, :zone] == "node_nsd"
        @test result[1, :component_id] == :node_nsd
        @test result[1, :component_type] == "Node{Electricity}"
        @test result[1, :variable] == :non_served_demand
        @test result[1, :segment] == 1
        @test result[1, :time] == 1
        @test result[1, :value] == 1.0
        
        # Check segment 1 values
        @test result[1, :value] == 1.0  # seg 1, time 1
        @test result[2, :value] == 2.0  # seg 1, time 2
        @test result[3, :value] == 3.0  # seg 1, time 3
        
        # Check segment 2 values
        @test result[4, :segment] == 2
        @test result[4, :value] == 4.0  # seg 2, time 1
        @test result[5, :value] == 5.0  # seg 2, time 2
        @test result[6, :value] == 6.0  # seg 2, time 3
        
        # Test scaling
        result_scaled = get_optimal_non_served_demand(node_with_nsd, 2.0)
        @test result_scaled[1, :value] == 2.0
        @test result_scaled[4, :value] == 8.0
        
        # Test with list of nodes
        node_with_nsd2 = Node{Electricity}(;
            id=:node_nsd2,
            timedata=TimeData{Electricity}(;
                time_interval=1:3,
                hours_per_timestep=10,
                subperiods=[1:10, 11:20, 21:30],
                subperiod_indices=[1, 2, 3],
                subperiod_weights=Dict(1 => 0.3, 2 => 0.5, 3 => 0.2)
            ),
            max_nsd=[0.1],  # 1 segment
            non_served_demand=reshape([7.0, 8.0, 9.0], 1, 3)  # 1 segment × 3 time steps
        )
        
        result_multi = get_optimal_non_served_demand([node_with_nsd, node_with_nsd2], 1.0)
        @test size(result_multi, 1) == 9  # 6 from node1 + 3 from node2
        
        # Test empty result for node without NSD
        node_without_nsd = Node{Electricity}(;
            id=:node_no_nsd,
            timedata=TimeData{Electricity}(;
                time_interval=1:3,
                hours_per_timestep=10,
                subperiods=[1:10, 11:20, 21:30],
                subperiod_indices=[1, 2, 3],
                subperiod_weights=Dict(1 => 0.3, 2 => 0.5, 3 => 0.2)
            )
        )
        result_empty = get_optimal_non_served_demand(node_without_nsd, 1.0)
        @test isempty(result_empty)
    end

    @testset "Storage Level Output Functions Tests" begin
        # Create storage with storage_level values
        storage_for_test = Storage{Electricity}(;
            id=:storage_test,
            timedata=TimeData{Electricity}(;
                time_interval=1:3,
                hours_per_timestep=10,
                subperiods=[1:10, 11:20, 21:30],
                subperiod_indices=[1, 2, 3],
                subperiod_weights=Dict(1 => 0.3, 2 => 0.5, 3 => 0.2)
            ),
            storage_level=[10.0, 20.0, 30.0]
        )
        
        # Test get_optimal_storage_level for single storage (without asset map)
        result = get_optimal_storage_level(storage_for_test, 1.0)
        @test result isa DataFrame
        @test size(result, 1) == 3  # 3 time steps
        
        # Check structure
        @test result[1, :commodity] == :Electricity
        @test result[1, :zone] == "storage_test"
        @test result[1, :resource_id] == :storage_test
        @test result[1, :component_id] == :storage_test
        @test result[1, :component_type] == "Storage{Electricity}"
        @test result[1, :variable] == :storage_level
        @test result[1, :time] == 1
        @test result[1, :value] == 10.0
        
        # Check time progression
        @test result[2, :time] == 2
        @test result[2, :value] == 20.0
        @test result[3, :time] == 3
        @test result[3, :value] == 30.0
        
        # Test scaling
        result_scaled = get_optimal_storage_level(storage_for_test, 2.0)
        @test result_scaled[1, :value] == 20.0
        @test result_scaled[2, :value] == 40.0
        @test result_scaled[3, :value] == 60.0
        
        # Test with list of storages
        storage_for_test2 = Storage{Electricity}(;
            id=:storage_test2,
            timedata=TimeData{Electricity}(;
                time_interval=1:3,
                hours_per_timestep=10,
                subperiods=[1:10, 11:20, 21:30],
                subperiod_indices=[1, 2, 3],
                subperiod_weights=Dict(1 => 0.3, 2 => 0.5, 3 => 0.2)
            ),
            storage_level=[40.0, 50.0, 60.0]
        )
        
        result_multi = get_optimal_storage_level([storage_for_test, storage_for_test2], 1.0)
        @test size(result_multi, 1) == 6  # 3 from storage1 + 3 from storage2
        @test result_multi[4, :component_id] == :storage_test2
        @test result_multi[4, :value] == 40.0
        
        # Test with asset map (using existing storage and asset_ref2 from test setup)
        storage_asset_map = Dict{Symbol, Base.RefValue{<:MacroEnergy.AbstractAsset}}(:storage1 => asset_ref2)
        
        result_with_map = get_optimal_storage_level(storage, 1.0, storage_asset_map)
        @test result_with_map[1, :resource_id] == :asset2
        @test result_with_map[1, :resource_type] == "Battery"
        @test result_with_map[1, :component_id] == :storage1
        
        # Test system-level function with filtering (using existing system)
        result_system = get_optimal_storage_level(system)
        @test result_system isa DataFrame
        @test size(result_system, 1) == 3  # storage1 has 3 time steps
        
        # Test filtering by commodity - should return results (storage is Electricity)
        result_filtered_commodity = get_optimal_storage_level(system, commodity="Electricity")
        @test size(result_filtered_commodity, 1) == 3
        
        # Test filtering by asset type - should return results (asset is Battery)
        result_filtered_asset = get_optimal_storage_level(system, asset_type="Battery")
        @test size(result_filtered_asset, 1) == 3
        
        # Test filtering with non-existent commodity - should warn and return empty
        @test_logs (:warn, "Commodities not found: [:NaturalGas] when printing storage level results") (:warn, "No storages found after filtering") begin
            result_no_match = get_optimal_storage_level(system, commodity="NaturalGas")
            @test isempty(result_no_match)
        end
        
        # Test filtering with non-existent asset type - should warn and return empty
        @test_logs (:warn, "Asset type(s) not found: [\"VRE\"] when printing storage level results") (:warn, "No storages found after filtering") begin
            result_no_match_asset = get_optimal_storage_level(system, asset_type="VRE")
            @test isempty(result_no_match_asset)
        end
    end

    @testset "Curtailment Output Functions Tests" begin
        # Create VRE asset with edge that has capacity, flow, and availability
        vre_timedata = TimeData{Electricity}(;
            time_interval=1:3,
            hours_per_timestep=1,
            subperiods=[1:1, 2:2, 3:3],
            subperiod_indices=[1, 2, 3],
            subperiod_weights=Dict(1 => 0.3, 2 => 0.5, 3 => 0.2)
        )
        vre_transform = Transformation(;
            id=:vre_transform,
            timedata=vre_timedata
        )
        vre_edge = Edge{Electricity}(;
            id=:vre_edge,
            start_vertex=vre_transform,
            end_vertex=node1,
            timedata=vre_timedata,
            has_capacity=true,
            capacity=100.0,
            flow=[1.0, 2.0, 3.0],
            availability=[0.5, 0.6, 0.7]
        )
        vre_asset = VRE(:vre_asset, vre_transform, vre_edge)

        # System with VRE for curtailment tests
        system_with_vre = empty_system("test_system_with_vre")
        system_with_vre.settings = (OutputLayout="long",)  # Required for write_curtailment
        add!(system_with_vre, node1)
        add!(system_with_vre, vre_asset)

        # Test get_optimal_curtailment for single edge
        vre_asset_ref = Ref(vre_asset)
        vre_edge_map = Dict{Symbol,Base.RefValue{<:AbstractAsset}}(:vre_edge => vre_asset_ref)
        result = get_optimal_curtailment(vre_edge, 1.0, vre_edge_map)
        @test result isa DataFrame
        @test size(result, 1) == 3  # 3 time steps
        # Curtailment = max(0, capacity * availability(t) - flow(t))
        # t=1: 100*0.5 - 1 = 49, t=2: 100*0.6 - 2 = 58, t=3: 100*0.7 - 3 = 67
        @test result[1, :commodity] == :Electricity
        @test result[1, :variable] == :curtailment
        @test result[1, :time] == 1
        @test result[1, :value] ≈ 49.0 # first time step value
        @test result[2, :value] ≈ 58.0 # second time step value
        @test result[3, :value] ≈ 67.0 # third time step value
        @test result[1, :resource_id] == :vre_asset
        @test result[1, :resource_type] == "VRE"

        # Test get_optimal_curtailment at system level (with VRE)
        result_system = get_optimal_curtailment(system_with_vre)
        @test result_system isa DataFrame
        @test size(result_system, 1) == 3
        @test result_system[1, :value] ≈ 49.0
        @test result_system[2, :value] ≈ 58.0
        @test result_system[3, :value] ≈ 67.0

        # Test scaling
        result_scaled = get_optimal_curtailment(system_with_vre; scaling=2.0)
        @test result_scaled[1, :value] ≈ 98.0  # 49 * 2
        @test result_scaled[2, :value] ≈ 116.0 # 58 * 2
        @test result_scaled[3, :value] ≈ 134.0 # 67 * 2

        # Test get_optimal_curtailment for system without VRE (returns empty)
        result_empty = get_optimal_curtailment(system)  # system has ThermalPower and Battery, no VRE
        @test result_empty isa DataFrame
        @test isempty(result_empty)

        # Test write_curtailment
        test_curtailment_path = joinpath(abspath(mktempdir(".")), "curtailment.csv")
        @test_nowarn write_curtailment(test_curtailment_path, system_with_vre)
        @test isfile(test_curtailment_path)
        written = CSV.read(test_curtailment_path, DataFrame)
        @test size(written, 1) == 3
        @test written[1, :value] ≈ 49.0
        @test written[2, :value] ≈ 58.0
        @test written[3, :value] ≈ 67.0
        @test "value" in names(written)
        rm(test_curtailment_path) # clean up

        # Test write_curtailment with wide layout
        system_with_vre.settings = (OutputLayout="wide",)
        test_curtailment_path = joinpath(abspath(mktempdir(".")), "curtailment_wide.csv")
        @test_nowarn write_curtailment(test_curtailment_path, system_with_vre)
        @test isfile(test_curtailment_path)
        written = CSV.read(test_curtailment_path, DataFrame)
        @test size(written, 1) == 3
        @test written[1, :vre_asset] ≈ 49.0
        @test written[2, :vre_asset] ≈ 58.0
        @test written[3, :vre_asset] ≈ 67.0

        # Test write_curtailment with system without VRE (no file written, no error)
        test_empty_path = joinpath(abspath(mktempdir(".")), "curtailment_empty.csv")
        @test_nowarn write_curtailment(test_empty_path, system)
        # When empty, write_curtailment returns early and may not create file
        # (get_optimal_curtailment returns empty, so no write occurs)
        @test !isfile(test_empty_path)
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
            sys = empty_system("random_path_$(randstring(8))")
            sys.settings = (OutputLayout=layout,)
            return sys
        end
    
        @testset "String layouts" begin
            # Test valid string inputs
            @test get_output_layout(make_test_system("wide")) == "wide"
            @test get_output_layout(make_test_system("long")) == "long"
        end
    
        @testset "NamedTuple layouts" begin
            ## Test NamedTuple
            layout_settings = (Capacity="wide", Curtailment="wide", StorageLevel="long")
            system3 = make_test_system(layout_settings)
            # no variable
            @test_logs (:warn, "OutputLayout in settings does not have a variable key. Using 'long' as default.") begin
                @test get_output_layout(system3) == "long"
            end

            # with existing keys
            @test get_output_layout(system3, :Capacity) == "wide"
            @test get_output_layout(system3, :Curtailment) == "wide"
            @test get_output_layout(system3, :StorageLevel) == "long"
    
            # Test missing key falls back to "long" with warning
            @test_logs (:warn, "OutputLayout in settings does not have a missing_var key. Using 'long' as default.") begin
                @test get_output_layout(system3, :missing_var) == "long"
            end
        end
    
        @testset "Invalid layout types" begin
            # Test unexpected type with warning
            invalid_system = make_test_system(42)  # Integer is not a valid layout type
            @test_logs (:warn, "OutputLayout type Int64 not supported. Using 'long' as default.") begin
                @test get_output_layout(invalid_system, :any_variable) == "long"
            end
        end

        @testset "OutputLayout validation accepts Curtailment" begin
            # Verify configure_settings accepts :Curtailment in OutputLayout
            settings = MacroEnergy.configure_settings((
                OutputLayout=(Capacity="long", Costs="long", Curtailment="wide", Flow="long",
                             NonServedDemand="long", StorageLevel="long"),
            ))
            @test settings.OutputLayout isa NamedTuple
            @test settings.OutputLayout.Curtailment == "wide"
        end
    end

    @testset "get_detailed_costs" begin
        # Add time_data to system (required by get_detailed_costs)
        electricity_timedata = TimeData{Electricity}(;
            time_interval=1:3,
            hours_per_timestep=1,
            subperiods=[1:1, 2:2, 3:3],
            subperiod_indices=[1, 2, 3],
            subperiod_weights=Dict(1 => 0.3, 2 => 0.5, 3 => 0.2),
            period_index=1
        )
        node1.timedata = electricity_timedata
        edge_to_transformation.timedata = electricity_timedata
        system.time_data[:Electricity] = electricity_timedata
        settings = (PeriodLengths=[10], DiscountRate=0.5, SolutionAlgorithm=MacroEnergy.Monolithic())

        # Add costs to edge_to_transformation
        edge_to_transformation.variable_om_cost = 1.0
        edge_to_transformation.fixed_om_cost = 2.0
        edge_to_transformation.can_expand = true
        edge_to_transformation.annualized_investment_cost = 3.0
        edge_to_transformation.capital_recovery_period = 4
        edge_to_transformation.new_capacity = 5.0

        # Compute annualized costs and discount fixed costs
        compute_annualized_costs!(system, settings)
        discount_fixed_costs!(system, settings)

        # Compute multipliers using economics functions (period_length=10, period_index=1)
        period_length = 10
        period_index = 1
        discount_rate = 0.5
        period_start_year = total_years(settings.PeriodLengths[1:period_index-1])
        discount_factor = present_value_factor(discount_rate, period_start_year)
        opexmult = present_value_annuity_factor(discount_rate, period_length)
        payment_years = min(capital_recovery_period(edge_to_transformation), period_length)
        pvaf_inv = present_value_annuity_factor(discount_rate, payment_years)
        crf_inv = capital_recovery_factor(discount_rate, payment_years)

        # Pre-computed values to test against
        variable_om_raw = sum(
            subperiod_weight(edge_to_transformation, current_subperiod(edge_to_transformation, t)) *
            variable_om_cost(edge_to_transformation) * value(flow(edge_to_transformation, t))
            for t in time_interval(edge_to_transformation)
        )
        fuel_raw_transformation = sum(
            subperiod_weight(edge_to_transformation, current_subperiod(edge_to_transformation, t)) * price(start_vertex(edge_to_transformation), t) * value(flow(edge_to_transformation, t))
            for t in time_interval(edge_to_transformation)
        )
        fuel_raw_storage = sum(
            subperiod_weight(edge_to_storage, current_subperiod(edge_to_storage, t)) * price(start_vertex(edge_to_storage), t) * value(flow(edge_to_storage, t))
            for t in time_interval(edge_to_storage)
        )
        fuel_raw_total = fuel_raw_transformation + fuel_raw_storage
        # NonServedDemand from node1: sum over segment and time of (weight * price_nsd * nsd)
        nsd_raw_total = sum(
            subperiod_weight(node1, current_subperiod(node1, t)) * price_non_served_demand(node1, s) * value(non_served_demand(node1, s, t))
            for s in segments_non_served_demand(node1), t in time_interval(node1)
        )
        capacity_val = value(capacity(edge_to_transformation))
        new_cap_val = value(new_capacity(edge_to_transformation))
        fixed_om_cost_val = fixed_om_cost(edge_to_transformation)
        annualized_inv_cost = annualized_investment_cost(edge_to_transformation)

        # Undiscounted costs
        costs_result = get_detailed_costs(system, settings)
        detailed_undisc = costs_result.undiscounted
        @test detailed_undisc isa DataFrame
        @test all(c in names(detailed_undisc) for c in ["zone", "type", "category", "value"])
        @test !isempty(detailed_undisc)

        # Return structure: both discounted and undiscounted have same columns and row count
        @test names(costs_result.discounted) == ["zone", "type", "category", "value"]
        @test names(costs_result.undiscounted) == ["zone", "type", "category", "value"]
        @test size(costs_result.discounted, 1) == size(costs_result.undiscounted, 1)
        # FixedOM: cf_period_fixed_om_cost * capacity = (period_length * fixed_om_cost) * capacity
        @test detailed_undisc.value[detailed_undisc.category .== :FixedOM] ≈ [period_length * fixed_om_cost_val * capacity_val]
        # Investment: payment_years * pv_period_inv * crf * new_capacity
        inv_cf = payment_years * annualized_inv_cost * pvaf_inv * crf_inv
        @test detailed_undisc.value[detailed_undisc.category .== :Investment] ≈ [inv_cf * new_cap_val]
        # VariableOM: raw * period_length
        @test detailed_undisc.value[detailed_undisc.category .== :VariableOM] ≈ [variable_om_raw * period_length]
        # Fuel: raw * period_length (sum of all edges with fuel cost)
        @test sum(detailed_undisc.value[detailed_undisc.category .== :Fuel]) ≈ fuel_raw_total * period_length
        # NonServedDemand: raw * period_length (from nodes with non_served_demand)
        @test sum(detailed_undisc.value[detailed_undisc.category .== :NonServedDemand]) ≈ nsd_raw_total * period_length

        # Discounted costs (use economics multipliers)
        detailed_disc = costs_result.discounted
        @test detailed_disc isa DataFrame
        @test size(detailed_disc, 2) == 4
        @test size(detailed_disc, 1) == size(detailed_undisc, 1)
        # FixedOM: (fixed_om_cost * opexmult) * capacity * discount_factor
        @test detailed_disc.value[detailed_disc.category .== :FixedOM] ≈ [fixed_om_cost_val * opexmult * capacity_val * discount_factor]
        # Investment: (annualized_inv * pvaf_inv) * new_cap * discount_factor
        inv_pv = annualized_inv_cost * pvaf_inv * new_cap_val * discount_factor
        @test detailed_disc.value[detailed_disc.category .== :Investment] ≈ [inv_pv]
        # VariableOM: raw * discount_factor * opexmult
        @test detailed_disc.value[detailed_disc.category .== :VariableOM] ≈ [variable_om_raw * discount_factor * opexmult]
        # Fuel: raw * discount_factor * opexmult (sum of all edges with fuel cost)
        @test sum(detailed_disc.value[detailed_disc.category .== :Fuel]) ≈ fuel_raw_total * discount_factor * opexmult
        # NonServedDemand: raw * discount_factor * opexmult
        @test sum(detailed_disc.value[detailed_disc.category .== :NonServedDemand]) ≈ nsd_raw_total * discount_factor * opexmult

        # Scaling
        detailed_scaled = get_detailed_costs(system, settings; scaling=2.0).undiscounted
        @test detailed_scaled.value ≈ detailed_undisc.value .* 4  # scaling^2

        # Restore edge for other tests
        edge_to_transformation.variable_om_cost = 0.0
        edge_to_transformation.fixed_om_cost = 0.0
        edge_to_transformation.can_expand = false
        edge_to_transformation.annualized_investment_cost = 0.0
        edge_to_transformation.capital_recovery_period = 1  # default
        edge_to_transformation.new_capacity = 0.0
        delete!(system.time_data, :Electricity)
    end

    @testset "get_detailed_costs - empty system and return structure" begin
        # Empty / zero-cost system
        empty_dir = abspath(mktempdir("."))
        empty_sys = empty_system(empty_dir)
        empty_timedata = TimeData{Electricity}(;
            time_interval=1:1,
            hours_per_timestep=1,
            subperiods=[1:1],
            subperiod_indices=[1],
            subperiod_weights=Dict(1 => 1.0),
            period_index=1
        )
        empty_sys.time_data = Dict(:Electricity => empty_timedata)
        empty_settings = (PeriodLengths=[1], DiscountRate=0.0, SolutionAlgorithm=MacroEnergy.Monolithic())

        costs_empty = get_detailed_costs(empty_sys, empty_settings)
        @test costs_empty.discounted isa DataFrame
        @test costs_empty.undiscounted isa DataFrame
        @test names(costs_empty.discounted) == ["zone", "type", "category", "value"]
        @test names(costs_empty.undiscounted) == ["zone", "type", "category", "value"]
        @test isempty(costs_empty.discounted)
        @test isempty(costs_empty.undiscounted)
        rm(empty_dir, recursive = true)
    end

    @testset "Detailed cost helper functions" begin
        # Test aggregate_costs_by_type
        costs_df = DataFrame(
            zone = ["z1", "z1", "z2", "z2"],
            type = ["A", "A", "B", "B"],
            category = [:Investment, :VariableOM, :Investment, :VariableOM],
            value = [10.0, 5.0, 20.0, 8.0]
        )
        by_type = MacroEnergy.aggregate_costs_by_type(costs_df)
        @test by_type isa DataFrame
        @test size(by_type, 1) == 4  # 2 types × 2 categories
        @test sum(by_type[by_type.type .== "A", :].value) ≈ 15.0
        @test sum(by_type[by_type.type .== "B", :].value) ≈ 28.0

        # Test aggregate_costs_by_zone
        by_zone = MacroEnergy.aggregate_costs_by_zone(costs_df)
        @test by_zone isa DataFrame
        @test size(by_zone, 1) == 4  # 2 zones × 2 categories
        @test sum(by_zone[by_zone.zone .== "z1", :].value) ≈ 15.0
        @test sum(by_zone[by_zone.zone .== "z2", :].value) ≈ 28.0

        # Test add_total_row!
        df_with_total = MacroEnergy.add_total_row!(copy(by_type), :type)
        @test "Total" in df_with_total.type
        @test :Total in df_with_total.category
        grand_total = only(df_with_total[(df_with_total.type .== "Total") .& (df_with_total.category .== :Total), :value])
        @test grand_total ≈ 43.0

        # Test reshape_costs_wide
        wide_df = MacroEnergy.reshape_costs_wide(df_with_total, :type)
        @test "Total" in names(wide_df)
        @test "Investment" in names(wide_df)
        @test "VariableOM" in names(wide_df)

        # Test write_cost_breakdown_files!
        test_dir = abspath(mktempdir("."))
        detailed_costs = DataFrame(
            zone = ["z1", "z2"],
            type = ["A", "B"],
            category = [:Investment, :VariableOM],
            value = [100.0, 50.0]
        )
        @test_nowarn MacroEnergy.write_cost_breakdown_files!(
            test_dir, detailed_costs, "long";
            prefix = "test_costs",
            validate_model = nothing
        )
        @test isfile(joinpath(test_dir, "test_costs_by_type.csv"))
        @test isfile(joinpath(test_dir, "test_costs_by_zone.csv"))
        rm(test_dir, recursive = true)

        # Test aggregate_operational_costs (for Benders)
        op_costs = [
            DataFrame(zone=["z1"], type=["A"], category=[:VariableOM], value=[1.0]),
            DataFrame(zone=["z1"], type=["A"], category=[:VariableOM], value=[2.0])
        ]
        merged = MacroEnergy.aggregate_operational_costs(op_costs)
        @test size(merged, 1) == 1
        @test only(merged.value) ≈ 3.0

        # Test empty inputs
        @test isempty(MacroEnergy.aggregate_costs_by_type(DataFrame(zone=[], type=[], category=[], value=[])))
        @test isempty(MacroEnergy.aggregate_costs_by_zone(DataFrame(zone=[], type=[], category=[], value=[])))
    end
end

test_writing_output()

end # module TestOutput

