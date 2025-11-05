module TestBendersOutputUtilities

using Test
using JuMP
using HiGHS
using MacroEnergy

import MacroEnergy: densearray_to_dict, dict_to_densearray
import MacroEnergy: collect_local_slack_vars, collect_local_constraint_duals
import MacroEnergy: populate_slack_vars_from_subproblems!, populate_constraint_duals_from_subproblems!
import MacroEnergy: merge_distributed_slack_vars_dicts, merge_distributed_balance_duals
import MacroEnergy: BalanceConstraint
import MacroEnergy: empty_system
import MacroEnergy: Node, Electricity, TimeData, System

function test_benders_output_utilities()

    @testset "DenseAxisArray Conversion Functions" begin
        
        @testset "1D Array Conversion" begin
            model = Model(HiGHS.Optimizer)
            set_silent(model)
            
            time_periods = [2, 5, 25, 100]
            @variable(model, x[t in time_periods] >= 0)
            @constraint(model, x .== 1)
            @objective(model, Min, sum(x[t] for t in time_periods))
            optimize!(model)
            
            # Convert to dict
            x_dict = densearray_to_dict(x)
            
            @test isa(x_dict, Dict)
            @test length(x_dict) == 4
            @test haskey(x_dict, 2)
            @test haskey(x_dict, 5)
            @test haskey(x_dict, 25)
            @test haskey(x_dict, 100)
            @test all(v == 1 for v in values(x_dict))
            
            # Convert back to DenseAxisArray
            x_reconstructed = dict_to_densearray(x_dict)
            
            @test isa(x_reconstructed, JuMP.Containers.DenseAxisArray)
            @test length(x_reconstructed.axes) == 1
            @test x_reconstructed.axes[1] == [2, 5, 25, 100]
            @test x_reconstructed[2] == x_dict[2]
            @test x_reconstructed[5] == x_dict[5]
            @test x_reconstructed[25] == x_dict[25]
            @test x_reconstructed[100] == x_dict[100]
        end
        
        @testset "2D Array Conversion" begin
            model = Model(HiGHS.Optimizer)
            set_silent(model)
            
            locations = [:boston, :princeton]
            times = [2, 5, 25, 100]
            @variable(model, z[loc in locations, t in times] >= 0)
            @objective(model, Min, sum(z[loc, t] for loc in locations, t in times))
            optimize!(model)
            
            # Convert to dict with tuple keys
            z_dict = densearray_to_dict(z)
            
            @test z_dict isa Dict
            @test length(z_dict) == 8  # 2 locations × 4 times
            @test haskey(z_dict, (:boston, 2))
            @test haskey(z_dict, (:boston, 5))
            @test haskey(z_dict, (:boston, 25))
            @test haskey(z_dict, (:boston, 100))
            @test haskey(z_dict, (:princeton, 2))
            @test haskey(z_dict, (:princeton, 5))
            @test haskey(z_dict, (:princeton, 25))
            @test haskey(z_dict, (:princeton, 100))
            
            # Convert back
            z_reconstructed = dict_to_densearray(z_dict)
            
            @test isa(z_reconstructed, JuMP.Containers.DenseAxisArray)
            @test length(z_reconstructed.axes) == 2
            @test z_reconstructed[:boston, 2] == z_dict[(:boston, 2)]
            @test z_reconstructed[:boston, 5] == z_dict[(:boston, 5)]
            @test z_reconstructed[:boston, 25] == z_dict[(:boston, 25)]
            @test z_reconstructed[:boston, 100] == z_dict[(:boston, 100)]
            @test z_reconstructed[:princeton, 2] == z_dict[(:princeton, 2)]
            @test z_reconstructed[:princeton, 5] == z_dict[(:princeton, 5)]
            @test z_reconstructed[:princeton, 25] == z_dict[(:princeton, 25)]
            @test z_reconstructed[:princeton, 100] == z_dict[(:princeton, 100)]
        end
        
        @testset "Dict Merging" begin
            dict1 = Dict(2 => 1.0, 5 => 2.0)
            dict2 = Dict(25 => 3.0, 100 => 4.0)
            
            merged = merge(dict1, dict2)
            
            @test length(merged) == 4
            @test merged[2] == 1.0
            @test merged[5] == 2.0
            @test merged[25] == 3.0
            @test merged[100] == 4.0
            
            # Convert to DenseAxisArray
            arr = dict_to_densearray(merged)
            
            @test arr[2] == 1.0
            @test arr[5] == 2.0
            @test arr[25] == 3.0
            @test arr[100] == 4.0
        end
    end
    
    @testset "Merge Helper Functions" begin
        
        @testset "merge_distributed_slack_vars_dicts - Two Workers" begin
            # Mock two workers with different data
            worker1 = Dict(
                1 => Dict(
                    (:node1, :slack1) => Dict(1 => 1.0, 2 => 2.0),
                    (:node2, :slack2) => Dict(1 => 3.0)
                )
            )
            
            worker2 = Dict(
                1 => Dict(
                    (:node1, :slack1) => Dict(3 => 3.0, 4 => 4.0),
                    (:node3, :slack3) => Dict(1 => 5.0)
                )
            )
            
            worker_results = [worker1, worker2]
            merged = merge_distributed_slack_vars_dicts(worker_results)
            
            # Check structure
            @test haskey(merged, 1) # period_idx = 1
            @test haskey(merged[1], (:node1, :slack1))
            @test haskey(merged[1], (:node2, :slack2))
            @test haskey(merged[1], (:node3, :slack3))
            
            # Check merged data for node1
            @test length(merged[1][(:node1, :slack1)]) == 4
            @test merged[1][(:node1, :slack1)][1] == 1.0
            @test merged[1][(:node1, :slack1)][2] == 2.0
            @test merged[1][(:node1, :slack1)][3] == 3.0
            @test merged[1][(:node1, :slack1)][4] == 4.0
            
            # Check other nodes
            @test merged[1][(:node2, :slack2)][1] == 3.0
            @test merged[1][(:node3, :slack3)][1] == 5.0
        end
        
        @testset "merge_distributed_slack_vars_dicts - Multiple Periods" begin
            worker1 = Dict(
                1 => Dict((:nodeA, :slackA) => Dict(1 => 1.0)),
                2 => Dict((:nodeB, :slackB) => Dict(2 => 2.0))
            )
            
            worker2 = Dict(
                1 => Dict((:nodeA, :slackA) => Dict(2 => 1.5)),
                3 => Dict((:nodeC, :slackC) => Dict(3 => 3.0))
            )
            
            merged = merge_distributed_slack_vars_dicts([worker1, worker2])
            
            @test haskey(merged, 1)
            @test haskey(merged, 2)
            @test haskey(merged, 3)
            @test length(merged[1][(:nodeA, :slackA)]) == 2
            @test merged[1][(:nodeA, :slackA)][1] == 1.0
            @test merged[1][(:nodeA, :slackA)][2] == 1.5
            @test length(merged[2][(:nodeB, :slackB)]) == 1
            @test merged[2][(:nodeB, :slackB)][2] == 2.0
            @test length(merged[3][(:nodeC, :slackC)]) == 1
            @test merged[3][(:nodeC, :slackC)][3] == 3.0
        end
        
        @testset "merge_distributed_balance_duals - Three Levels" begin
            # Test the specialized merge for balance constraints
            worker1 = Dict(
                1 => Dict(
                    :node1 => Dict(
                        :demand => Dict(1 => -10.0, 2 => -20.0),
                        :emissions => Dict(1 => -5.0)
                    ),
                    :node2 => Dict(
                        :demand => Dict(1 => -15.0)
                    )
                )
            )
            
            worker2 = Dict(
                1 => Dict(
                    :node1 => Dict(
                        :demand => Dict(3 => -30.0),  # Same node, same balance_id, different time
                        :co2_storage => Dict(1 => -7.0)  # Same node, new balance_id
                    ),
                    :node3 => Dict(
                        :demand => Dict(1 => -25.0)  # New node
                    )
                )
            )
            
            merged = merge_distributed_balance_duals([worker1, worker2])
            
            # Check structure
            @test haskey(merged, 1)
            @test haskey(merged[1], :node1)
            @test haskey(merged[1], :node2)
            @test haskey(merged[1], :node3)
            
            # Check node1 merged duals
            @test haskey(merged[1][:node1], :demand)
            @test haskey(merged[1][:node1], :emissions)
            @test haskey(merged[1][:node1], :co2_storage)

            # Check node2 merged duals
            @test haskey(merged[1][:node2], :demand)
            @test length(merged[1][:node2][:demand]) == 1

            # Check node3 merged duals
            @test haskey(merged[1][:node3], :demand)
            @test length(merged[1][:node3][:demand]) == 1
            
            # Check demand duals merged from both workers
            @test length(merged[1][:node1][:demand]) == 3
            @test merged[1][:node1][:demand][1] == -10.0
            @test merged[1][:node1][:demand][2] == -20.0
            @test merged[1][:node1][:demand][3] == -30.0
            
            # Check other balance equations
            @test merged[1][:node1][:emissions][1] == -5.0
            @test merged[1][:node1][:co2_storage][1] == -7.0
            @test merged[1][:node2][:demand][1] == -15.0
            @test merged[1][:node3][:demand][1] == -25.0
        end
        
        @testset "merge_distributed_balance_duals - Empty Workers" begin
            # Test with some workers returning empty dicts
            worker1 = Dict{Int64, Dict{Symbol, Dict{Symbol, Dict{Int,Float64}}}}()
            worker2 = Dict(
                1 => Dict(
                    :node1 => Dict(:demand => Dict(1 => -10.0))
                )
            )
            
            merged = merge_distributed_balance_duals([worker1, worker2])
            
            @test haskey(merged, 1)
            @test merged[1][:node1][:demand][1] == -10.0
        end
    end
    
    @testset "Local Slack Variables Collection" begin
        
        @testset "Multiple Nodes with Slack Variables" begin
            # Create mock subproblem data
            model_1 = Model(HiGHS.Optimizer)
            set_silent(model_1)
            
            time_indices_1 = 1:1:5
            slack_1_model_1 = @variable(model_1, slack_1[t in time_indices_1] >= 0)
            slack_2_model_1 = @variable(model_1, slack_2[t in time_indices_1] >= 0)
            @constraint(model_1, [t in time_indices_1], slack_1[t] .== 10)
            @constraint(model_1, [t in time_indices_1], slack_2[t] .== 20)
            @objective(model_1, Min, sum(slack_1[t] for t in time_indices_1) + 
                sum(slack_2[t] for t in time_indices_1))
            optimize!(model_1)
            
            model_2 = Model(HiGHS.Optimizer)
            set_silent(model_2)

            time_indices_2 = 6:1:10
            slack_1_model_2 = @variable(model_2, slack_1[t in time_indices_2] >= 0)
            slack_2_model_2 = @variable(model_2, slack_2[t in time_indices_2] >= 0)
            @constraint(model_2, [t in time_indices_2], slack_1[t] .== 10)
            @constraint(model_2, [t in time_indices_2], slack_2[t] .== 20)
            @objective(model_2, Min, sum(slack_1[t] for t in time_indices_2) + 
                sum(slack_2[t] for t in time_indices_2))
            optimize!(model_2)
            
            # Create mock timedata
            timedata_1 = TimeData{Electricity}(;
                time_interval = time_indices_1,
                hours_per_timestep = 1,
                period_index = 1,
                subperiods = [1:5],
                subperiod_indices = [1],
                subperiod_weights = Dict(1 => 2.0),
                subperiod_map = Dict(1 => 1)
            )

            timedata_2 = TimeData{Electricity}(;
                time_interval = time_indices_2,
                hours_per_timestep = 1,
                period_index = 1,
                subperiods = [6:10],
                subperiod_indices = [2],
                subperiod_weights = Dict(2 => 2.0),
                subperiod_map = Dict(2 => 2)
            )

            # Create mock node with slack variables
            mock_node_1 = Node{Electricity}(
                id = :test_node_1,
                policy_slack_vars = Dict{Symbol, Any}(
                    :test_slack_1 => slack_1_model_1
                ),
                timedata = timedata_1
            )
            
            mock_node_2 = Node{Electricity}(
                id = :test_node_2,
                policy_slack_vars = Dict{Symbol, Any}(
                    :test_slack_2 => slack_2_model_1
                ),
                timedata = timedata_1
            )

            mock_node_3 = Node{Electricity}(
                id = :test_node_3,
                policy_slack_vars = Dict{Symbol, Any}(
                    :test_slack_1 => slack_1_model_2
                ),
                timedata = timedata_2
            )

            mock_node_4 = Node{Electricity}(
                id = :test_node_4,
                policy_slack_vars = Dict{Symbol, Any}(
                    :test_slack_2 => slack_2_model_2
                ),
                timedata = timedata_2
            )

            # Create mock system
            mock_system_1 = empty_system("mock_system_1")
            mock_system_1.time_data = Dict(:Electricity => timedata_1)
            mock_system_1.locations = [mock_node_1, mock_node_2]
            mock_system_2 = empty_system("mock_system_2")
            mock_system_2.time_data = Dict(:Electricity => timedata_2)
            mock_system_2.locations = [mock_node_3, mock_node_4]

            # Create subproblems_local
            subproblems_local_1 = [Dict{Any, Any}(:system_local => mock_system_1)]
            subproblems_local_2 = [Dict{Any, Any}(:system_local => mock_system_2)]
            
            # Test collection
            result_1 = collect_local_slack_vars(subproblems_local_1)
            result_2 = collect_local_slack_vars(subproblems_local_2)
            
            @test isa(result_1, Dict)
            @test haskey(result_1, 1)  # period_index = 1
            # keys are (node_id, slack_vars_key)
            @test haskey(result_1[1], (:test_node_1, :test_slack_1))
            @test haskey(result_1[1], (:test_node_2, :test_slack_2))

            @test haskey(result_2, 1)  # period_index = 1
            @test haskey(result_2[1], (:test_node_3, :test_slack_1))
            @test haskey(result_2[1], (:test_node_4, :test_slack_2))
            
            slack_dict_1 = result_1[1][(:test_node_1, :test_slack_1)]
            @test isa(slack_dict_1, Dict)
            @test length(slack_dict_1) == 5

            slack_dict_2 = result_2[1][(:test_node_3, :test_slack_1)]
            @test isa(slack_dict_2, Dict)
            @test length(slack_dict_2) == 5

            merged = merge_distributed_slack_vars_dicts([result_1, result_2])

            @test haskey(merged, 1)
            @test haskey(merged[1], (:test_node_1, :test_slack_1))
            @test haskey(merged[1], (:test_node_2, :test_slack_2))
            @test haskey(merged[1], (:test_node_3, :test_slack_1))
            @test haskey(merged[1], (:test_node_4, :test_slack_2))
            @test length(merged[1][(:test_node_1, :test_slack_1)]) == 5
            @test length(merged[1][(:test_node_2, :test_slack_2)]) == 5
            @test length(merged[1][(:test_node_3, :test_slack_1)]) == 5
            @test length(merged[1][(:test_node_4, :test_slack_2)]) == 5
            @test merged[1][(:test_node_1, :test_slack_1)][1] .== 10.0
            @test merged[1][(:test_node_1, :test_slack_1)][2] .== 10.0
            @test merged[1][(:test_node_1, :test_slack_1)][3] .== 10.0
            @test merged[1][(:test_node_1, :test_slack_1)][4] .== 10.0
            @test merged[1][(:test_node_1, :test_slack_1)][5] .== 10.0
            @test merged[1][(:test_node_2, :test_slack_2)][1] == 20.0
            @test merged[1][(:test_node_2, :test_slack_2)][2] == 20.0
            @test merged[1][(:test_node_2, :test_slack_2)][3] == 20.0
            @test merged[1][(:test_node_2, :test_slack_2)][4] == 20.0
            @test merged[1][(:test_node_2, :test_slack_2)][5] == 20.0
            @test merged[1][(:test_node_3, :test_slack_1)][6] == 10.0
            @test merged[1][(:test_node_3, :test_slack_1)][7] == 10.0
            @test merged[1][(:test_node_3, :test_slack_1)][8] == 10.0
            @test merged[1][(:test_node_3, :test_slack_1)][9] == 10.0
            @test merged[1][(:test_node_3, :test_slack_1)][10] == 10.0
            @test merged[1][(:test_node_4, :test_slack_2)][6] == 20.0
            @test merged[1][(:test_node_4, :test_slack_2)][7] == 20.0
            @test merged[1][(:test_node_4, :test_slack_2)][8] == 20.0
            @test merged[1][(:test_node_4, :test_slack_2)][9] == 20.0
            @test merged[1][(:test_node_4, :test_slack_2)][10] == 20.0

            # Another test with different nodes and slack variables
            model = Model(HiGHS.Optimizer)
            set_silent(model)
            
            @variable(model, slack1[t in [1, 2]] >= 0)
            @variable(model, slack2[t in [3, 4]] >= 0)
            @constraint(model, [t in [1, 2]], slack1[t] .== 10)
            @constraint(model, [t in [3, 4]], slack2[t] .== 20)
            @objective(model, Min, sum(slack1) + sum(slack2))
            optimize!(model)
            
            # Create mock timedata
            timedata_1 = TimeData{Electricity}(;
                time_interval = 1:2,
                hours_per_timestep = 1,
                period_index = 1,
                subperiods = [1:2],
                subperiod_indices = [1],
                subperiod_weights = Dict(1 => 2.0),
                subperiod_map = Dict(1 => 1)
            )
            timedata_2 = TimeData{NaturalGas}(;
                time_interval = 3:4,
                hours_per_timestep = 1,
                period_index = 1,
                subperiods = [3:4],
                subperiod_indices = [2],
                subperiod_weights = Dict(2 => 2.0),
                subperiod_map = Dict(2 => 2)
            )
            # Create two nodes
            node1 = Node{Electricity}(
                id = :node1,
                policy_slack_vars = Dict(:co2_slack => slack1),
                timedata = timedata_1
            )
            
            node2 = Node{NaturalGas}(
                id = :node2,
                policy_slack_vars = Dict(:co2_slack => slack2),
                timedata = timedata_2
            )

            mock_system = empty_system("mock_system")
            mock_system.time_data = Dict(:Electricity => timedata_1, :NaturalGas => timedata_2)
            mock_system.locations = [node1, node2]
            
            subproblems_local = [Dict{Any,Any}(:system_local => mock_system)]
            
            result = collect_local_slack_vars(subproblems_local)
            
            @test haskey(result[1], (:node1, :co2_slack))
            @test haskey(result[1], (:node2, :co2_slack))
            @test length(result[1][(:node1, :co2_slack)]) == 2
            @test length(result[1][(:node2, :co2_slack)]) == 2
            @test result[1][(:node1, :co2_slack)][1] == 10.0
            @test result[1][(:node1, :co2_slack)][2] == 10.0
            @test result[1][(:node2, :co2_slack)][3] == 20.0
            @test result[1][(:node2, :co2_slack)][4] == 20.0
        end
        
        @testset "Empty Slack Variables" begin
            timedata = TimeData{Electricity}(;
                time_interval = 1:2,
                hours_per_timestep = 1,
                period_index = 1,
                subperiods = [1:2],
                subperiod_indices = [1],
                subperiod_weights = Dict(1 => 2.0),
                subperiod_map = Dict(1 => 1)
            )

            # Node with no slack variables
            mock_node = Node{Electricity}(
                id = :empty_node,
                policy_slack_vars = Dict{Symbol, Any}(), 
                timedata = timedata
            )
            
            mock_system = empty_system("mock_system")
            mock_system.time_data = Dict(:Electricity => timedata)
            mock_system.locations = [mock_node]
            
            subproblems_local = [Dict{Any,Any}(:system_local => mock_system)]
            
            result = collect_local_slack_vars(subproblems_local)
            
            # Should return empty dict for this period
            @test isa(result, Dict)
            @test !haskey(result, 1) || isempty(result[1])
        end
    end
    
    @testset "Local Constraint Duals Collection" begin
        
        @testset "BalanceConstraint Duals" begin
            model = Model(HiGHS.Optimizer)
            set_silent(model)
            
            time_indices = 1:3
            @variable(model, x[t in time_indices] >= 0)
            balance_constraint = @constraint(model, 
                balance[t in time_indices], 
                x[t] == 1.0
            )
            @objective(model, Min, sum(x))
            optimize!(model)
            
            timedata = TimeData{Electricity}(;
                time_interval = time_indices,
                hours_per_timestep = 1,
                period_index = 1,
                subperiods = [1:length(time_indices)],
                subperiod_indices = [1],
                subperiod_weights = Dict(1 => 2.0),
                subperiod_map = Dict(1 => 1)
            )
            # Create mock node with balance constraint
            mock_node = Node{Electricity}(
                id = :test_node,
                timedata = timedata
            )
            
            # Create BalanceConstraint with duals already extracted
            balance_ct = BalanceConstraint(
                constraint_ref = balance_constraint,
                constraint_dual = Dict(
                    :demand => [dual(balance_constraint[t]) for t in time_indices]
                )
            )
            mock_node.constraints = [balance_ct]
            
            mock_system = empty_system("mock_system")
            mock_system.time_data = Dict(:Electricity => timedata)
            mock_system.locations = [mock_node]
            
            subproblems_local = [Dict(:system_local => mock_system)]
            
            # Test collection
            result = collect_local_constraint_duals(subproblems_local, BalanceConstraint)
            
            @test isa(result, Dict)
            @test haskey(result, 1)  # period_index
            @test haskey(result[1], :test_node)
            @test haskey(result[1][:test_node], :demand)
            
            demand_duals = result[1][:test_node][:demand]
            @test isa(demand_duals, Dict)
            @test length(demand_duals) == 3
            @test all(haskey(demand_duals, t) for t in time_indices)
            @test all(demand_duals[t] == 1.0 for t in time_indices)
        end
        
        @testset "Multiple Balance Equations" begin
            model = Model(HiGHS.Optimizer)
            set_silent(model)
            
            @variable(model, x >= 0)
            @constraint(model, c1, x == 1.0)
            @objective(model, Min, x)
            optimize!(model)
            
            timedata = TimeData{Electricity}(;
                time_interval = 1:1,
                hours_per_timestep = 1,
                period_index = 1,
                subperiods = [1:1],
                subperiod_indices = [1],
                subperiod_weights = Dict(1 => 2.0),
                subperiod_map = Dict(1 => 1)
            )
            mock_node = Node{Electricity}(
                id = :multi_node,
                timedata = timedata
            )
            
            # Balance constraint with multiple balance equations
            balance_ct = BalanceConstraint(
                constraint_ref = c1,
                constraint_dual = Dict(
                    :demand => [dual(c1)],
                    :emissions => [dual(c1) * 2.0]
                )
            )
            mock_node.constraints = [balance_ct]
                
            mock_system = empty_system("mock_system")
            mock_system.time_data = Dict(:Electricity => timedata)
            mock_system.locations = [mock_node]
            
            subproblems_local = [Dict(:system_local => mock_system)]
            
            result = collect_local_constraint_duals(subproblems_local, BalanceConstraint)
            
            @test haskey(result[1][:multi_node], :demand)
            @test haskey(result[1][:multi_node], :emissions)
            @test result[1][:multi_node][:emissions][1] == result[1][:multi_node][:demand][1] * 2.0
        end
        
        @testset "Node Without BalanceConstraint" begin
            timedata = TimeData{Electricity}(;
                time_interval = 1:1,
                hours_per_timestep = 1,
                period_index = 1,
                subperiods = [1:1],
                subperiod_indices = [1],
                subperiod_weights = Dict(1 => 2.0),
                subperiod_map = Dict(1 => 1)
            )
            mock_node = Node{Electricity}(
                id = :no_constraint_node,
                timedata = timedata
            )

            mock_node.constraints = []  # No constraints

            mock_system = empty_system("mock_system")
            mock_system.time_data = Dict(:Electricity => timedata)
            mock_system.locations = [mock_node]
            
            subproblems_local = [Dict(:system_local => mock_system)]
            
            result = collect_local_constraint_duals(subproblems_local, BalanceConstraint)
            
            # Should return empty or not include this node
            @test isa(result, Dict) && isempty(result)
        end
    end
    
    @testset "Prepare Duals Benders" begin
        
        @testset "Move Slack Variables to Planning Problem" begin
            timedata = TimeData{Electricity}(;
                time_interval = 1:3,
                hours_per_timestep = 1,
                period_index = 1,
                subperiods = [1:3],
                subperiod_indices = [1],
                subperiod_weights = Dict(1 => 2.0),
                subperiod_map = Dict(1 => 1)
            )
            planning_node = Node{Electricity}(
                id = :plan_node,
                policy_slack_vars = Dict{Symbol, Any}(), # empty dict to start with
                timedata = timedata
            )
            
            planning_system = empty_system("planning_system")
            planning_system.locations = [planning_node]
            planning_system.time_data = Dict(:Electricity => timedata)
            
            # Create slack vars dict to move
            slack_vars_dict = Dict(
                (:plan_node, :co2_slack) => Dict(1 => 0.5, 2 => 1.0, 3 => 0.0)
            )
            
            # Move
            populate_slack_vars_from_subproblems!(planning_system, slack_vars_dict)
            
            # Check move
            @test haskey(planning_node.policy_slack_vars, :co2_slack)
            moved = planning_node.policy_slack_vars[:co2_slack]
            @test isa(moved, JuMP.Containers.DenseAxisArray)
            @test moved[1] == 0.5
            @test moved[2] == 1.0
            @test moved[3] == 0.0
        end
        
        @testset "Move Constraint Duals to Planning Problem" begin
            # Create planning problem node with BalanceConstraint
            timedata = TimeData{Electricity}(;
                time_interval = 1:3,
                hours_per_timestep = 1,
                period_index = 1,
                subperiods = [1:3],
                subperiod_indices = [1],
                subperiod_weights = Dict(1 => 2.0),
                subperiod_map = Dict(1 => 1)
            )
            planning_node = Node{Electricity}(
                id = :plan_node,
                timedata = timedata,
                constraints = [BalanceConstraint(constraint_dual = missing)]
            )
            
            planning_system = empty_system("planning_system")
            planning_system.time_data = Dict(:Electricity => timedata)
            planning_system.locations = [planning_node]
            
            # Create constraint duals dict to move to planning problem
            constraint_duals_dict = Dict(
                :plan_node => Dict(
                    :demand => Dict(1 => -10.5, 2 => -20.3, 3 => -15.7)
                )
            )
            
            # Restore
            populate_constraint_duals_from_subproblems!(
                planning_system, 
                constraint_duals_dict, 
                BalanceConstraint
            )

            balance_ct = planning_system.locations[1].constraints[1]
            
            # Check restoration
            @test isa(balance_ct, BalanceConstraint)
            @test !ismissing(balance_ct.constraint_dual)
            @test haskey(balance_ct.constraint_dual, :demand)
            @test balance_ct.constraint_dual[:demand] == [-10.5, -20.3, -15.7]
        end
        
        @testset "Check Error for Missing Nodes" begin
            planning_system = empty_system("planning_system")
            planning_system.locations = []  # Empty system
            
            planning_system.settings = (;AutoCreateNodes = false)

            slack_vars_dict = Dict(
                (:nonexistent_node, :slack) => Dict(1 => 1.0)
            )
            
            # Should throw error because node does not exist in the system
            @test_throws ErrorException populate_slack_vars_from_subproblems!(planning_system, slack_vars_dict)
        end
    end
    
    @testset "Integration: Full Workflow" begin
        
        @testset "Collect and Move Slack Variables" begin
            model_1 = Model(HiGHS.Optimizer)
            set_silent(model_1)
            
            @variable(model_1, slack[t in [1, 2, 3]] >= 0)
            @constraint(model_1, [t in [1, 2, 3]], slack[t] .== 10)
            @objective(model_1, Min, sum(slack))
            optimize!(model_1)
            
            # Subproblem node
            timedata_1 = TimeData{Electricity}(;
                time_interval = 1:3,
                hours_per_timestep = 1,
                period_index = 1,
                subperiods = [1:3],
                subperiod_indices = [1],
                subperiod_weights = Dict(1 => 2.0),
                subperiod_map = Dict(1 => 1)
            )
            sub_node_1 = Node{Electricity}(
                id = :integration_node,
                policy_slack_vars = Dict(:test_slack => slack),
                timedata = timedata_1
            )
            
            sub_system_1 = empty_system("sub_system")
            sub_system_1.locations = [sub_node_1]
            sub_system_1.time_data = Dict(:Electricity => timedata_1)

            model_2 = Model(HiGHS.Optimizer)
            set_silent(model_2)
            
            @variable(model_2, slack[t in [4, 5, 6]] >= 0)
            @constraint(model_2, [t in [4, 5, 6]], slack[t] .== 20)
            @objective(model_2, Min, sum(slack))
            optimize!(model_2)
            
            # Subproblem node
            timedata_2 = TimeData{Electricity}(;
                time_interval = 4:6,
                hours_per_timestep = 1,
                period_index = 1,
                subperiods = [4:6],
                subperiod_indices = [2],
                subperiod_weights = Dict(2 => 5.0),
                subperiod_map = Dict(2 => 2)
            )
            sub_node_2 = Node{Electricity}(
                id = :integration_node,
                policy_slack_vars = Dict(:test_slack => slack),
                timedata = timedata_2
            )
            
            sub_system_2 = empty_system("sub_system")
            sub_system_2.locations = [sub_node_2]
            sub_system_2.time_data = Dict(:Electricity => timedata_2)
            
            # Collect
            subproblems_local = [
                Dict{Any, Any}(:system_local => sub_system_1),
                Dict{Any, Any}(:system_local => sub_system_2)
            ]
            collected = collect_local_slack_vars(subproblems_local)
            
            # Planning node
            timedata_planning = TimeData{Electricity}(;
                time_interval = 1:6,
                hours_per_timestep = 1,
                period_index = 1,
                subperiods = [1:3,4:6],
                subperiod_indices = [1,2],
                subperiod_weights = Dict(1 => 2, 2 => 5.0),
                subperiod_map = Dict(1 => 1, 2 => 2)
            )
            plan_node = Node{Electricity}(
                id = :integration_node,
                policy_slack_vars = Dict{Symbol, Any}(), 
                timedata = timedata_planning
            )
            
            plan_system = empty_system("plan_system")
            plan_system.time_data = Dict(:Electricity => timedata_planning)
            plan_system.locations = [plan_node]
            
            # Move
            populate_slack_vars_from_subproblems!(plan_system, collected[1])
            
            # Verify
            @test haskey(plan_node.policy_slack_vars, :test_slack)
            moved_slack = plan_node.policy_slack_vars[:test_slack]
            @test isa(moved_slack, JuMP.Containers.DenseAxisArray)
            @test length(moved_slack.axes[1]) == 6
            @test moved_slack[1] == 10.0
            @test moved_slack[2] == 10.0
            @test moved_slack[3] == 10.0
            @test moved_slack[4] == 20.0
            @test moved_slack[5] == 20.0
            @test moved_slack[6] == 20.0
        end
    end
end

test_benders_output_utilities()
end # module TestBendersOutputUtilities

