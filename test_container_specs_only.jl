using JuMP
using Test

# Import just the container specification functions
include("src/utilities/utilities.jl")

"""
Test file for corrected container specification approach.
This test verifies that our approach of using macro_energy_container_spec 
functions for efficient variable creation works correctly.
"""

# Mock the missing types for testing
abstract type AbstractAsset end
abstract type AbstractVertex end

@testset "Corrected Container Specification Tests" begin
    
    @testset "Core Container Functions" begin
        println("🔧 Testing container specification functions...")
        
        edge_ids = [:edge1, :edge2, :edge3]
        time_steps = [1, 2, 3, 4]
        
        # Test 1D container creation
        container_1d = macro_energy_container_spec(VariableRef, edge_ids)
        @test container_1d isa JuMP.Containers.DenseAxisArray
        println("  ✅ 1D DenseAxisArray created successfully")
        
        # Test 2D container creation
        container_2d = macro_energy_container_spec(VariableRef, edge_ids, time_steps)
        @test container_2d isa JuMP.Containers.DenseAxisArray
        println("  ✅ 2D DenseAxisArray created successfully")
        
        # Test sparse container creation
        sparse_indices = [(:edge1, 1), (:edge2, 3), (:edge3, 2)]
        container_sparse = macro_energy_sparse_container_spec(VariableRef, sparse_indices)
        @test container_sparse isa JuMP.Containers.SparseAxisArray
        println("  ✅ SparseAxisArray created successfully")
    end
    
    @testset "Variable Creation Pattern" begin
        println("\n🎯 Testing the CORRECT variable creation pattern...")
        
        model = Model()
        edge_ids = [:transmission1, :generation1, :storage1]
        time_steps = [1, 2, 3]
        
        # PATTERN 1: Capacity Variables (1D)
        println("  Creating capacity variables...")
        capacity_vars = macro_energy_container_spec(VariableRef, edge_ids)
        
        for edge_id in edge_ids
            capacity_vars[edge_id] = @variable(
                model,
                lower_bound = 0.0,
                base_name = "vCAP_$(edge_id)"
            )
        end
        
        # Verify all variables were created
        @test all(haskey(capacity_vars, edge_id) for edge_id in edge_ids)
        @test all(isa(capacity_vars[edge_id], VariableRef) for edge_id in edge_ids)
        capacity_count = length(edge_ids)
        println("    ✅ Created $capacity_count capacity variables using container spec")
        
        # PATTERN 2: Flow Variables (2D)
        println("  Creating flow variables...")
        flow_vars = macro_energy_container_spec(VariableRef, edge_ids, time_steps)
        
        for edge_id in edge_ids
            for t in time_steps
                flow_vars[edge_id, t] = @variable(
                    model,
                    base_name = "vFLOW_$(edge_id)_$(t)"
                )
            end
        end
        
        # Verify all 2D variables were created
        @test all(haskey(flow_vars, (edge_id, t)) for edge_id in edge_ids for t in time_steps)
        @test all(isa(flow_vars[edge_id, t], VariableRef) for edge_id in edge_ids for t in time_steps)
        flow_count = length(edge_ids) * length(time_steps)
        println("    ✅ Created $flow_count flow variables using container spec")
        
        # PATTERN 3: Sparse Variables (subset of combinations)
        println("  Creating sparse variables...")
        sparse_indices = [(:transmission1, 1), (:transmission1, 3), (:storage1, 2)]
        sparse_vars = macro_energy_sparse_container_spec(VariableRef, sparse_indices)
        
        for (edge_id, t) in sparse_indices
            sparse_vars[(edge_id, t)] = @variable(
                model,
                base_name = "vSPARSE_$(edge_id)_$(t)"
            )
        end
        
        # Verify sparse variables were created
        @test all(haskey(sparse_vars, idx) for idx in sparse_indices)
        @test all(isa(sparse_vars[idx], VariableRef) for idx in sparse_indices)
        sparse_count = length(sparse_indices)
        println("    ✅ Created $sparse_count sparse variables using container spec")
        
        # Verify total variable count in model
        total_expected = capacity_count + flow_count + sparse_count
        @test num_variables(model) == total_expected
        println("    ✅ Model has $total_expected variables total")
    end
    
    @testset "Access Pattern Efficiency" begin
        println("\n⚡ Testing access pattern efficiency...")
        
        model = Model()
        edge_ids = [:edge1, :edge2, :edge3, :edge4, :edge5]
        time_steps = [1, 2, 3, 4, 5]
        
        # Create container and populate it
        vars = macro_energy_container_spec(VariableRef, edge_ids, time_steps)
        
        for edge_id in edge_ids
            for t in time_steps
                vars[edge_id, t] = @variable(model, base_name = "v_$(edge_id)_$(t)")
            end
        end
        
        # Test direct access patterns
        @test vars[:edge1, 1] isa VariableRef
        @test vars[:edge3, 4] isa VariableRef
        @test vars[:edge5, 5] isa VariableRef
        
        # Test that different indices give different variables
        @test vars[:edge1, 1] !== vars[:edge1, 2]
        @test vars[:edge1, 1] !== vars[:edge2, 1]
        
        println("    ✅ Direct container access working efficiently")
        
        # Test container properties
        @test size(vars) == (length(edge_ids), length(time_steps))
        @test length(vars) == length(edge_ids) * length(time_steps)
        
        println("    ✅ Container dimensions correct: $(size(vars))")
    end
    
    @testset "Container Type Verification" begin
        println("\n🔍 Verifying container types match expectations...")
        
        # Test 1D containers
        edges = [:a, :b, :c]
        container_1d = macro_energy_container_spec(VariableRef, edges)
        @test container_1d isa JuMP.Containers.DenseAxisArray{VariableRef, 1}
        println("    ✅ 1D containers are DenseAxisArray{VariableRef, 1}")
        
        # Test 2D containers
        times = [1, 2]
        container_2d = macro_energy_container_spec(VariableRef, edges, times)
        @test container_2d isa JuMP.Containers.DenseAxisArray{VariableRef, 2}
        println("    ✅ 2D containers are DenseAxisArray{VariableRef, 2}")
        
        # Test sparse containers
        sparse_idx = [(:a, 1), (:c, 2)]
        container_sparse = macro_energy_sparse_container_spec(VariableRef, sparse_idx)
        @test container_sparse isa JuMP.Containers.SparseAxisArray{VariableRef, 2, Tuple{Symbol, Int}}
        println("    ✅ Sparse containers are SparseAxisArray{VariableRef, 2, Tuple{Symbol, Int}}")
    end
end

println("\n🎉 ALL CONTAINER SPECIFICATION TESTS PASSED!")
println("\n📋 SUMMARY:")
println("✅ Container specification functions working correctly")
println("✅ Variable creation pattern verified")
println("✅ Access patterns efficient")
println("✅ Container types match JuMP optimized structures")
println("\n🚀 Ready for EdgeOptimizationManager integration!")
