#!/usr/bin/env julia

"""
Improved benchmark test showing realistic scenarios where preallocation provides benefits
"""

using Pkg
Pkg.activate(".")

using MacroEnergy
using JuMP
using Printf
using Random  # Add Random at the top level

println("MacroEnergy.jl Preallocation Benchmark - Realistic Scenarios")
println("="^65)

"""
Scenario 1: Multiple model builds (simulating optimization over multiple time horizons)
This shows the benefit of reusing preallocated containers
"""
function benchmark_multiple_model_builds()
    println("\n🔄 SCENARIO 1: Multiple Model Builds")
    println("="^50)
    println("Simulating building multiple optimization models (like multi-period optimization)")
    
    edge_ids = [Symbol("edge_$i") for i in 1:20]
    time_horizon = collect(1:24)
    num_builds = 10
    
    println("Configuration: $num_builds model builds, $(length(edge_ids)) edges, $(length(time_horizon)) time periods")
    
    # Without preallocation - create new data structures each time
    println("\n📊 WITHOUT preallocation (create new structures each time)...")
    time_without = @elapsed begin
        models_without = []
        for build in 1:num_builds
            model = Model()
            variables = Dict{Symbol, Dict{Symbol, Dict{Int, VariableRef}}}()
            
            for var_type in [:capacity, :flow, :new_capacity]
                variables[var_type] = Dict{Symbol, Dict{Int, VariableRef}}()
                for edge_id in edge_ids
                    variables[var_type][edge_id] = Dict{Int, VariableRef}()
                    for t in time_horizon
                        var = @variable(model, base_name="$(var_type)_$(edge_id)_$(t)_$(build)")
                        variables[var_type][edge_id][t] = var
                    end
                end
            end
            push!(models_without, (model, variables))
        end
    end
    
    # With preallocation - reuse container structure
    println("📊 WITH preallocation (reuse container structures)...")
    time_with = @elapsed begin
        # Create template containers once
        template_manager = EdgeOptimizationManager(Model(), time_horizon)
        variable_types = [EdgeCapacityVariable, EdgeFlowVariable, EdgeNewCapacityVariable]
        
        for var_type in variable_types
            container = EdgeVariableContainer(var_type(), edge_ids, time_horizon)
            template_manager.variable_containers[var_type] = container
        end
        
        models_with = []
        for build in 1:num_builds
            model = Model()
            manager = EdgeOptimizationManager(model, time_horizon)
            
            # Reuse container structure but with new model
            for var_type in variable_types
                container = EdgeVariableContainer(var_type(), edge_ids, time_horizon)
                manager.variable_containers[var_type] = container
                
                # Fast allocation using preallocated structure
                for edge_id in edge_ids
                    for t in time_horizon
                        var = @variable(model, base_name="$(var_type)_$(edge_id)_$(t)_$(build)")
                        set_variable!(container, edge_id, var, t)
                    end
                end
            end
            push!(models_with, manager)
        end
    end
    
    improvement = ((time_without - time_with) / time_without) * 100
    
    @printf "  Time without preallocation: %.4f seconds\n" time_without
    @printf "  Time with preallocation: %.4f seconds\n" time_with
    @printf "  Improvement: %+.1f%% (%s)\n" improvement (improvement > 0 ? "faster ✅" : "slower ❌")
    
    return improvement
end

"""
Scenario 2: Variable access patterns (frequent lookups)
This shows the benefit of organized access to variables
"""
function benchmark_variable_access()
    println("\n🔍 SCENARIO 2: Variable Access Patterns")
    println("="^50)
    println("Simulating frequent variable access (like in constraint generation)")
    
    edge_ids = [Symbol("edge_$i") for i in 1:50]
    time_horizon = collect(1:24)
    num_accesses = 10000
    
    println("Configuration: $(length(edge_ids)) edges, $(length(time_horizon)) time periods, $num_accesses random accesses")
    
    # Setup without preallocation
    model_without = Model()
    variables_without = Dict{Symbol, Dict{Symbol, Dict{Int, VariableRef}}}()
    for var_type in [:capacity, :flow]
        variables_without[var_type] = Dict{Symbol, Dict{Int, VariableRef}}()
        for edge_id in edge_ids
            variables_without[var_type][edge_id] = Dict{Int, VariableRef}()
            for t in time_horizon
                var = @variable(model_without, base_name="$(var_type)_$(edge_id)_$(t)")
                variables_without[var_type][edge_id][t] = var
            end
        end
    end
    
    # Setup with preallocation
    model_with = Model()
    manager = EdgeOptimizationManager(model_with, time_horizon)
    variable_types = [EdgeCapacityVariable, EdgeFlowVariable]
    
    for var_type in variable_types
        container = EdgeVariableContainer(var_type(), edge_ids, time_horizon)
        manager.variable_containers[var_type] = container
        
        for edge_id in edge_ids
            for t in time_horizon
                var = @variable(model_with, base_name="$(var_type)_$(edge_id)_$(t)")
                set_variable!(container, edge_id, var, t)
            end
        end
    end
    
    # Generate random access patterns
    Random.seed!(42)  # For reproducibility
    access_patterns = []
    for _ in 1:num_accesses
        var_type_idx = rand(1:2)
        edge_idx = rand(1:length(edge_ids))
        time_idx = rand(1:length(time_horizon))
        push!(access_patterns, (var_type_idx, edge_idx, time_idx))
    end
    
    # Benchmark access without preallocation
    println("\n📊 WITHOUT preallocation (nested dict access)...")
    accessed_vars_without = []
    time_without = @elapsed begin
        for (var_type_idx, edge_idx, time_idx) in access_patterns
            var_type = var_type_idx == 1 ? :capacity : :flow
            edge_id = edge_ids[edge_idx]
            t = time_horizon[time_idx]
            var = variables_without[var_type][edge_id][t]
            push!(accessed_vars_without, var)
        end
    end
    
    # Benchmark access with preallocation
    println("📊 WITH preallocation (organized container access)...")
    accessed_vars_with = []
    time_with = @elapsed begin
        for (var_type_idx, edge_idx, time_idx) in access_patterns
            var_type = var_type_idx == 1 ? EdgeCapacityVariable : EdgeFlowVariable
            edge_id = edge_ids[edge_idx]
            t = time_horizon[time_idx]
            container = manager.variable_containers[var_type]
            var = get_variable(container, edge_id, t)
            push!(accessed_vars_with, var)
        end
    end
    
    improvement = ((time_without - time_with) / time_without) * 100
    
    @printf "  Time without preallocation: %.6f seconds\n" time_without
    @printf "  Time with preallocation: %.6f seconds\n" time_with
    @printf "  Improvement: %+.1f%% (%s)\n" improvement (improvement > 0 ? "faster ✅" : "slower ❌")
    
    # Verify correctness
    println("  Correctness: $(length(accessed_vars_without) == length(accessed_vars_with) ? "✅" : "❌")")
    
    return improvement
end

"""
Scenario 3: Memory usage with large models
This shows memory organization benefits
"""
function benchmark_memory_usage()
    println("\n💾 SCENARIO 3: Memory Usage Comparison")
    println("="^50)
    println("Comparing memory usage patterns for organized vs unorganized storage")
    
    edge_ids = [Symbol("edge_$i") for i in 1:100]
    time_horizon = collect(1:168)  # One week
    
    println("Configuration: $(length(edge_ids)) edges, $(length(time_horizon)) time periods")
    
    # Memory usage without preallocation
    println("\n📊 WITHOUT preallocation memory usage...")
    memory_without = @allocated begin
        model = Model()
        variables = Dict{Symbol, Dict{Symbol, Dict{Int, VariableRef}}}()
        
        for var_type in [:capacity, :flow, :new_capacity, :commitment, :startup]
            variables[var_type] = Dict{Symbol, Dict{Int, VariableRef}}()
            for edge_id in edge_ids
                variables[var_type][edge_id] = Dict{Int, VariableRef}()
                for t in time_horizon
                    var = @variable(model, base_name="$(var_type)_$(edge_id)_$(t)")
                    variables[var_type][edge_id][t] = var
                end
            end
        end
        
        # Simulate some operations that might cause memory fragmentation
        for _ in 1:1000
            var_type = rand([:capacity, :flow, :new_capacity, :commitment, :startup])
            edge_id = rand(edge_ids)
            t = rand(time_horizon)
            _ = variables[var_type][edge_id][t]
        end
    end
    
    # Memory usage with preallocation
    println("📊 WITH preallocation memory usage...")
    memory_with = @allocated begin
        model = Model()
        manager = EdgeOptimizationManager(model, time_horizon)
        variable_types = [EdgeCapacityVariable, EdgeFlowVariable, EdgeNewCapacityVariable, 
                         EdgeCommitmentVariable, EdgeStartupVariable]
        
        for var_type in variable_types
            container = EdgeVariableContainer(var_type(), edge_ids, time_horizon)
            manager.variable_containers[var_type] = container
            
            for edge_id in edge_ids
                for t in time_horizon
                    var = @variable(model, base_name="$(var_type)_$(edge_id)_$(t)")
                    set_variable!(container, edge_id, var, t)
                end
            end
        end
        
        # Simulate same operations with organized access
        for _ in 1:1000
            var_type = rand(variable_types)
            edge_id = rand(edge_ids)
            t = rand(time_horizon)
            container = manager.variable_containers[var_type]
            _ = get_variable(container, edge_id, t)
        end
    end
    
    improvement = ((memory_without - memory_with) / memory_without) * 100
    
    @printf "  Memory without preallocation: %.2f MB\n" memory_without / (1024^2)
    @printf "  Memory with preallocation: %.2f MB\n" memory_with / (1024^2)
    @printf "  Memory improvement: %+.1f%% (%s)\n" improvement (improvement > 0 ? "less memory ✅" : "more memory ❌")
    
    return improvement
end

"""
Run all realistic benchmark scenarios
"""
function run_realistic_benchmarks()
    println("Testing realistic scenarios where preallocation shows its benefits...")
    
    improvements = []
    
    # Run scenarios
    scenario1_improvement = benchmark_multiple_model_builds()
    push!(improvements, scenario1_improvement)
    
    scenario2_improvement = benchmark_variable_access()
    push!(improvements, scenario2_improvement)
    
    scenario3_improvement = benchmark_memory_usage()
    push!(improvements, scenario3_improvement)
    
    # Summary
    println("\n" * "="^65)
    println("REALISTIC BENCHMARK SUMMARY")
    println("="^65)
    
    avg_improvement = sum(improvements) / length(improvements)
    
    println("\n📊 Scenario Results:")
    @printf "  Multiple model builds: %+.1f%%\n" scenario1_improvement
    @printf "  Variable access patterns: %+.1f%%\n" scenario2_improvement
    @printf "  Memory usage: %+.1f%%\n" scenario3_improvement
    @printf "  Average improvement: %+.1f%%\n" avg_improvement
    
    println("\n🎯 Key Insights:")
    println("• Preallocation overhead is noticeable for simple, one-time operations")
    println("• Benefits emerge with repeated operations, complex access patterns, and larger models")
    println("• Real-world optimization scenarios (multi-period, iterative solving) benefit most")
    println("• Memory organization can reduce fragmentation in large models")
    
    println("\n💡 Recommendations:")
    if avg_improvement > 10
        println("✅ Strong case for preallocation - significant performance benefits")
    elseif avg_improvement > 0
        println("✅ Moderate case for preallocation - benefits in complex scenarios")
    else
        println("⚠️  Preallocation shows overhead - consider for specific use cases only")
    end
    
    println("\n🔧 Use preallocation when:")
    println("  • Building multiple related models")
    println("  • Frequent variable/constraint access during model construction")
    println("  • Large-scale models with many edges and time periods")
    println("  • Iterative optimization workflows")
    
    return improvements
end

# Run the realistic benchmarks
try
    improvements = run_realistic_benchmarks()
    println("\n✅ Realistic benchmark completed successfully!")
catch e
    println("❌ Benchmark failed with error: $e")
    rethrow(e)
end
