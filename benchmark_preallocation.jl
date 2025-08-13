#!/usr/bin/env julia

"""
Benchmark test comparing preallocated vs non-preallocated edge variable/constraint creation in MacroEnergy.jl
"""

using Pkg
Pkg.activate(".")

using MacroEnergy
using JuMP
using BenchmarkTools
using Printf

println("MacroEnergy.jl Preallocation Benchmark")
println("="^50)

# Test parameters
const BENCHMARK_EDGE_COUNTS = [10, 50, 100, 500]
const BENCHMARK_TIME_PERIODS = [24, 168, 8760]  # 1 day, 1 week, 1 year
const BENCHMARK_VARIABLE_TYPES = 5  # Test subset of variable types for speed

"""
Create variables without preallocation (baseline approach)
"""
function create_variables_without_preallocation(model::Model, edge_ids::Vector{Symbol}, time_horizon::Vector{Int})
    variables = Dict{Symbol, Dict{Symbol, Dict{Int, VariableRef}}}()
    
    # Simulate creating different types of variables
    variable_types = [:capacity, :flow, :new_capacity, :commitment, :startup]
    
    for var_type in variable_types
        variables[var_type] = Dict{Symbol, Dict{Int, VariableRef}}()
        for edge_id in edge_ids
            variables[var_type][edge_id] = Dict{Int, VariableRef}()
            for t in time_horizon
                var = @variable(model, base_name="$(var_type)_$(edge_id)_$(t)")
                variables[var_type][edge_id][t] = var
            end
        end
    end
    
    return variables
end

"""
Create constraints without preallocation (baseline approach)
"""
function create_constraints_without_preallocation(model::Model, edge_ids::Vector{Symbol}, time_horizon::Vector{Int}, variables)
    constraints = Dict{Symbol, Dict{Symbol, Dict{Int, ConstraintRef}}}()
    
    # Simulate creating different types of constraints
    constraint_types = [:capacity_limit, :flow_limit]
    
    for const_type in constraint_types
        constraints[const_type] = Dict{Symbol, Dict{Int, ConstraintRef}}()
        for edge_id in edge_ids
            constraints[const_type][edge_id] = Dict{Int, ConstraintRef}()
            for t in time_horizon
                # Create a dummy constraint using the variables
                if const_type == :capacity_limit
                    var = variables[:capacity][edge_id][t]
                    cons = @constraint(model, var <= 1000)
                else  # flow_limit
                    var = variables[:flow][edge_id][t]
                    cons = @constraint(model, var <= 500)
                end
                constraints[const_type][edge_id][t] = cons
            end
        end
    end
    
    return constraints
end

"""
Create variables with MacroEnergy preallocation system
"""
function create_variables_with_preallocation(model::Model, edge_ids::Vector{Symbol}, time_horizon::Vector{Int})
    manager = EdgeOptimizationManager(model, time_horizon)
    
    # Create containers for different variable types
    variable_types = [
        EdgeCapacityVariable,
        EdgeFlowVariable,
        EdgeNewCapacityVariable,
        EdgeCommitmentVariable,
        EdgeStartupVariable
    ]
    
    for var_type in variable_types
        container = EdgeVariableContainer(
            var_type(),
            edge_ids,
            time_horizon
        )
        manager.variable_containers[var_type] = container
        
        # Create variables and store them
        for edge_id in edge_ids
            for t in time_horizon
                var = @variable(model, base_name="$(var_type)_$(edge_id)_$(t)")
                set_variable!(container, edge_id, var, t)
            end
        end
    end
    
    return manager
end

"""
Create constraints with MacroEnergy preallocation system
"""
function create_constraints_with_preallocation(manager::EdgeOptimizationManager, edge_ids::Vector{Symbol}, time_horizon::Vector{Int})
    model = manager.model
    
    # Create constraint containers
    constraint_types = [EdgeCapacityConstraint, EdgeFlowConstraint]
    
    for const_type in constraint_types
        container = EdgeConstraintContainer(
            const_type(),
            edge_ids,
            time_horizon
        )
        manager.constraint_containers[const_type] = container
        
        # Create constraints and store them
        for edge_id in edge_ids
            for t in time_horizon
                # Get corresponding variable from variable containers
                if const_type == EdgeCapacityConstraint
                    var_container = manager.variable_containers[EdgeCapacityVariable]
                    var = get_variable(var_container, edge_id, t)
                    cons = @constraint(model, var <= 1000)
                else  # EdgeFlowConstraint
                    var_container = manager.variable_containers[EdgeFlowVariable]
                    var = get_variable(var_container, edge_id, t)
                    cons = @constraint(model, var <= 500)
                end
                set_constraint!(container, edge_id, cons, t)
            end
        end
    end
    
    return manager
end

"""
Run benchmark for a specific configuration
"""
function run_benchmark(num_edges::Int, num_time_periods::Int)
    println("\n" * "-"^40)
    println("Benchmarking: $num_edges edges, $num_time_periods time periods")
    println("Total variables: $(num_edges * num_time_periods * BENCHMARK_VARIABLE_TYPES)")
    println("Total constraints: $(num_edges * num_time_periods * 2)")
    
    # Generate test data
    edge_ids = [Symbol("edge_$i") for i in 1:num_edges]
    time_horizon = collect(1:num_time_periods)
    
    # Benchmark without preallocation
    println("\n📊 Benchmarking WITHOUT preallocation...")
    model_baseline = Model()
    
    time_baseline = @elapsed begin
        vars_baseline = create_variables_without_preallocation(model_baseline, edge_ids, time_horizon)
        cons_baseline = create_constraints_without_preallocation(model_baseline, edge_ids, time_horizon, vars_baseline)
    end
    
    baseline_memory = @allocated begin
        model_temp = Model()
        vars_temp = create_variables_without_preallocation(model_temp, edge_ids, time_horizon)
        cons_temp = create_constraints_without_preallocation(model_temp, edge_ids, time_horizon, vars_temp)
    end
    
    # Benchmark with preallocation
    println("📊 Benchmarking WITH preallocation...")
    model_prealloc = Model()
    
    time_prealloc = @elapsed begin
        manager = create_variables_with_preallocation(model_prealloc, edge_ids, time_horizon)
        create_constraints_with_preallocation(manager, edge_ids, time_horizon)
    end
    
    prealloc_memory = @allocated begin
        model_temp = Model()
        manager_temp = create_variables_with_preallocation(model_temp, edge_ids, time_horizon)
        create_constraints_with_preallocation(manager_temp, edge_ids, time_horizon)
    end
    
    # Calculate improvements
    time_improvement = ((time_baseline - time_prealloc) / time_baseline) * 100
    memory_improvement = ((baseline_memory - prealloc_memory) / baseline_memory) * 100
    
    # Verify correctness
    baseline_var_count = JuMP.num_variables(model_baseline)
    prealloc_var_count = JuMP.num_variables(model_prealloc)
    baseline_cons_count = JuMP.num_constraints(model_baseline, count_variable_in_set_constraints=false)
    prealloc_cons_count = JuMP.num_constraints(model_prealloc, count_variable_in_set_constraints=false)
    
    println("\n📈 Results:")
    println("  Without preallocation:")
    @printf "    Time: %.4f seconds\n" time_baseline
    @printf "    Memory: %.2f MB\n" baseline_memory / (1024^2)
    @printf "    Variables: %d, Constraints: %d\n" baseline_var_count baseline_cons_count
    
    println("  With preallocation:")
    @printf "    Time: %.4f seconds\n" time_prealloc
    @printf "    Memory: %.2f MB\n" prealloc_memory / (1024^2)
    @printf "    Variables: %d, Constraints: %d\n" prealloc_var_count prealloc_cons_count
    
    println("  Improvements:")
    @printf "    Time: %+.1f%% (%s)\n" time_improvement (time_improvement > 0 ? "faster ✅" : "slower ❌")
    @printf "    Memory: %+.1f%% (%s)\n" memory_improvement (memory_improvement > 0 ? "less memory ✅" : "more memory ❌")
    
    # Verify correctness
    if baseline_var_count == prealloc_var_count && baseline_cons_count == prealloc_cons_count
        println("  Correctness: ✅ Both methods produce identical results")
    else
        println("  Correctness: ❌ Results differ!")
    end
    
    return (
        time_baseline=time_baseline,
        time_prealloc=time_prealloc,
        memory_baseline=baseline_memory,
        memory_prealloc=prealloc_memory,
        time_improvement=time_improvement,
        memory_improvement=memory_improvement
    )
end

"""
Run comprehensive benchmark suite
"""
function run_comprehensive_benchmark()
    println("Starting comprehensive benchmark...")
    results = []
    
    for num_edges in BENCHMARK_EDGE_COUNTS
        for num_time_periods in BENCHMARK_TIME_PERIODS
            # Skip very large test cases for initial benchmark
            if num_edges * num_time_periods * BENCHMARK_VARIABLE_TYPES > 50000
                println("\nSkipping large test case: $num_edges edges × $num_time_periods time periods (would create $(num_edges * num_time_periods * BENCHMARK_VARIABLE_TYPES) variables)")
                continue
            end
            
            result = run_benchmark(num_edges, num_time_periods)
            push!(results, (
                edges=num_edges,
                periods=num_time_periods,
                result...
            ))
        end
    end
    
    # Summary
    println("\n" * "="^50)
    println("BENCHMARK SUMMARY")
    println("="^50)
    
    avg_time_improvement = mean([r.time_improvement for r in results])
    avg_memory_improvement = mean([r.memory_improvement for r in results])
    
    @printf "Average time improvement: %+.1f%%\n" avg_time_improvement
    @printf "Average memory improvement: %+.1f%%\n" avg_memory_improvement
    
    best_time = maximum([r.time_improvement for r in results])
    best_memory = maximum([r.memory_improvement for r in results])
    
    @printf "Best time improvement: %+.1f%%\n" best_time
    @printf "Best memory improvement: %+.1f%%\n" best_memory
    
    println("\n📊 Detailed Results Table:")
    println("Edges | Periods | Time Impr. | Memory Impr. | Variables")
    println("-"^55)
    for r in results
        total_vars = r.edges * r.periods * BENCHMARK_VARIABLE_TYPES
        @printf "%5d | %7d | %+9.1f%% | %+11.1f%% | %9d\n" r.edges r.periods r.time_improvement r.memory_improvement total_vars
    end
    
    println("\n🎯 Conclusion:")
    if avg_time_improvement > 0 && avg_memory_improvement > 0
        println("✅ Preallocation provides consistent performance improvements!")
    elseif avg_time_improvement > 0
        println("✅ Preallocation provides time improvements but uses more memory")
    elseif avg_memory_improvement > 0
        println("✅ Preallocation saves memory but is slower")
    else
        println("❌ Preallocation shows no clear benefit in this benchmark")
    end
    
    return results
end

# Add statistics function
function mean(arr)
    return sum(arr) / length(arr)
end

# Run the benchmark
try
    results = run_comprehensive_benchmark()
    println("\n✅ Benchmark completed successfully!")
catch e
    println("❌ Benchmark failed with error: $e")
    rethrow(e)
end
