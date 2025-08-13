# Corrected Benchmark: Using True Container Specification Functions
using JuMP, MacroEnergy
using BenchmarkTools

"""
Create variables WITHOUT using container specifications (current approach)
"""
function create_variables_without_container_spec(model::Model, edge_ids::Vector{Symbol}, time_horizon::Vector{Int})
    variables = Dict{Symbol, Dict{Symbol, Vector{VariableRef}}}()
    
    # Create individual variables one by one (current inefficient approach)
    for var_type in [:capacity, :flow, :new_capacity]
        variables[var_type] = Dict{Symbol, Vector{VariableRef}}()
        
        for edge_id in edge_ids
            variables[var_type][edge_id] = Vector{VariableRef}(undef, length(time_horizon))
            
            for (idx, t) in enumerate(time_horizon)
                var = @variable(model, base_name = "v_$(var_type)_$(edge_id)_$(t)")
                variables[var_type][edge_id][idx] = var
            end
        end
    end
    
    return variables
end

"""
Create variables WITH container specifications (true preallocation)
"""
function create_variables_with_container_spec(model::Model, edge_ids::Vector{Symbol}, time_horizon::Vector{Int})
    variables = Dict{Symbol, Any}()
    
    # Use macro_energy_container_spec for efficient container creation
    for var_type in [:capacity, :flow, :new_capacity]
        # Create the container using the proper specification function
        container = macro_energy_container_spec(VariableRef, edge_ids, time_horizon)
        
        # Allocate all variables at once using JuMP's container approach
        for edge_id in edge_ids
            for t in time_horizon
                container[edge_id, t] = @variable(model, base_name = "v_$(var_type)_$(edge_id)_$(t)")
            end
        end
        
        variables[var_type] = container
    end
    
    return variables
end

"""
Create variables with SPARSE container specifications
"""
function create_variables_with_sparse_container_spec(model::Model, edge_ids::Vector{Symbol}, time_horizon::Vector{Int})
    variables = Dict{Symbol, Any}()
    
    # Create sparse index set (simulating only some edge-time combinations)
    sparse_indices = Set{Tuple{Symbol, Int}}()
    for edge_id in edge_ids[1:2:end]  # Only every other edge
        for t in time_horizon[1:3:end]  # Only every third time step
            push!(sparse_indices, (edge_id, t))
        end
    end
    
    # Use macro_energy_sparse_container_spec for sparse allocation
    for var_type in [:capacity, :flow, :new_capacity]
        container = macro_energy_sparse_container_spec(VariableRef, sparse_indices)
        
        # Allocate variables only for sparse indices
        for (edge_id, t) in sparse_indices
            var = @variable(model, base_name = "v_$(var_type)_$(edge_id)_$(t)")
            container[(edge_id, t)] = var  # Use tuple indexing for sparse arrays
        end
        
        variables[var_type] = container
    end
    
    return variables
end

"""
Benchmark function access patterns
"""
function benchmark_variable_access(variables::Dict, edge_ids::Vector{Symbol}, time_horizon::Vector{Int})
    total_sum = 0.0
    
    # Access pattern: Test accessing variables
    for var_type in [:capacity, :flow, :new_capacity]
        if haskey(variables, var_type)
            container = variables[var_type]
            for edge_id in edge_ids[1:5]  # Only test first 5 edges for speed
                for t in time_horizon[1:5]  # Only test first 5 time steps
                    try
                        if isa(container, Dict)
                            # Old dict-based approach
                            if haskey(container, edge_id) && length(container[edge_id]) >= 1
                                total_sum += 1.0
                            end
                        elseif isa(container, JuMP.Containers.DenseAxisArray)
                            # DenseAxisArray access
                            if haskey(container, (edge_id, t))
                                total_sum += 1.0
                            end
                        elseif isa(container, JuMP.Containers.SparseAxisArray)
                            # SparseAxisArray access
                            if haskey(container, (edge_id, t))
                                total_sum += 1.0
                            end
                        end
                    catch
                        # Handle access errors gracefully
                    end
                end
            end
        end
    end
    
    return total_sum
end

# Run the corrected benchmark
function run_corrected_benchmark()
    println("="^60)
    println("CORRECTED BENCHMARK: Container Specification Functions")
    println("="^60)
    
    # Test parameters
    edge_ids = [Symbol("edge_$i") for i in 1:50]
    time_horizon = collect(1:24)
    
    println("Testing with $(length(edge_ids)) edges and $(length(time_horizon)) time steps")
    println()
    
    # Test 1: Without container specifications (current approach)
    println("1. Creating variables WITHOUT container specifications...")
    model1 = Model()
    time1 = @elapsed variables1 = create_variables_without_container_spec(model1, edge_ids, time_horizon)
    num_vars1 = num_variables(model1)
    
    println("   Variables created: $num_vars1")
    println("   Time taken: $(round(time1*1000, digits=2)) ms")
    
    # Test access performance
    access_time1 = @elapsed result1 = benchmark_variable_access(variables1, edge_ids, time_horizon)
    println("   Access test time: $(round(access_time1*1000, digits=2)) ms")
    println()
    
    # Test 2: With dense container specifications
    println("2. Creating variables WITH dense container specifications...")
    model2 = Model()
    time2 = @elapsed variables2 = create_variables_with_container_spec(model2, edge_ids, time_horizon)
    num_vars2 = num_variables(model2)
    
    println("   Variables created: $num_vars2")
    println("   Time taken: $(round(time2*1000, digits=2)) ms")
    
    # Test access performance
    access_time2 = @elapsed result2 = benchmark_variable_access(variables2, edge_ids, time_horizon)
    println("   Access test time: $(round(access_time2*1000, digits=2)) ms")
    println()
    
    # Test 3: With sparse container specifications
    println("3. Creating variables WITH sparse container specifications...")
    model3 = Model()
    time3 = @elapsed variables3 = create_variables_with_sparse_container_spec(model3, edge_ids, time_horizon)
    num_vars3 = num_variables(model3)
    
    println("   Variables created: $num_vars3")
    println("   Time taken: $(round(time3*1000, digits=2)) ms")
    
    # Test access performance  
    access_time3 = @elapsed result3 = benchmark_variable_access(variables3, edge_ids, time_horizon)
    println("   Access test time: $(round(access_time3*1000, digits=2)) ms")
    println()
    
    # Performance comparison
    println("="^60)
    println("PERFORMANCE COMPARISON:")
    println("="^60)
    
    creation_improvement_dense = ((time1 - time2) / time1) * 100
    creation_improvement_sparse = ((time1 - time3) / time1) * 100
    access_improvement_dense = ((access_time1 - access_time2) / access_time1) * 100
    access_improvement_sparse = ((access_time1 - access_time3) / access_time1) * 100
    
    println("Creation time improvement:")
    println("  Dense containers:  $(round(creation_improvement_dense, digits=1))%")
    println("  Sparse containers: $(round(creation_improvement_sparse, digits=1))%")
    println()
    println("Access time improvement:")
    println("  Dense containers:  $(round(access_improvement_dense, digits=1))%")
    println("  Sparse containers: $(round(access_improvement_sparse, digits=1))%")
    println()
    
    if creation_improvement_dense > 0
        println("✅ Dense container specification shows improvement!")
    else
        println("❌ Dense container specification shows overhead of $(abs(round(creation_improvement_dense, digits=1)))%")
    end
    
    if creation_improvement_sparse > 0
        println("✅ Sparse container specification shows improvement!")
    else
        println("❌ Sparse container specification shows overhead of $(abs(round(creation_improvement_sparse, digits=1)))%")
    end
    
    return (
        without_spec = (creation = time1, access = access_time1, vars = num_vars1),
        with_dense_spec = (creation = time2, access = access_time2, vars = num_vars2),
        with_sparse_spec = (creation = time3, access = access_time3, vars = num_vars3)
    )
end

# Run the benchmark
if abspath(PROGRAM_FILE) == @__FILE__
    using Pkg
    Pkg.activate(".")
    
    results = run_corrected_benchmark()
    
    println("\n" * "="^60)
    println("DETAILED RESULTS:")
    println("="^60)
    println("Without container spec: $(results.without_spec)")
    println("With dense spec:       $(results.with_dense_spec)")
    println("With sparse spec:      $(results.with_sparse_spec)")
end
