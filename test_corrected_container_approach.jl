# Corrected Edge Variable Allocation Functions
# These functions properly use the macro_energy_container_spec functions

using JuMP

# Import only the utilities functions we need
include("src/utilities/utilities.jl")

"""
Corrected allocation function that properly uses container specifications
"""
function allocate_capacity_variables_corrected!(model::JuMP.Model, edges::Vector{Symbol})
    println("Testing corrected allocation approach...")
    
    # Step 1: Use macro_energy_container_spec to create the container
    vars = macro_energy_container_spec(VariableRef, edges)
    println("Created container: $(typeof(vars))")
    
    # Step 2: Populate the container with JuMP variables
    for edge_id in edges
        vars[edge_id] = @variable(model, lower_bound = 0.0, base_name = "vCAP_$(edge_id)")
    end
    
    println("Variables created in container:")
    for edge_id in edges
        println("  $(edge_id): $(vars[edge_id])")
    end
    
    return vars
end

"""
Corrected 2D allocation function for flow variables
"""
function allocate_flow_variables_corrected!(model::JuMP.Model, edges::Vector{Symbol}, time_steps::Vector{Int})
    println("Testing corrected 2D allocation approach...")
    
    # Step 1: Use macro_energy_container_spec to create the 2D container
    vars = macro_energy_container_spec(VariableRef, edges, time_steps)
    println("Created 2D container: $(typeof(vars))")
    
    # Step 2: Populate the container with JuMP variables
    for edge_id in edges
        for t in time_steps
            vars[edge_id, t] = @variable(model, base_name = "vFLOW_$(edge_id)_$(t)")
        end
    end
    
    println("2D Variables created in container:")
    for edge_id in edges[1:2]  # Show just first 2 for brevity
        for t in time_steps[1:3]  # Show just first 3 time steps
            println("  $(edge_id), $(t): $(vars[edge_id, t])")
        end
    end
    
    return vars
end

"""
Test sparse container allocation
"""
function allocate_sparse_variables_corrected!(model::JuMP.Model, sparse_indices::Set{Tuple{Symbol, Int}})
    println("Testing corrected sparse allocation approach...")
    
    # Step 1: Use macro_energy_sparse_container_spec to create the sparse container
    vars = macro_energy_sparse_container_spec(VariableRef, sparse_indices)
    println("Created sparse container: $(typeof(vars))")
    
    # Step 2: Populate the container with JuMP variables for sparse indices only
    for (edge_id, t) in sparse_indices
        vars[(edge_id, t)] = @variable(model, base_name = "vSPARSE_$(edge_id)_$(t)")
    end
    
    println("Sparse variables created:")
    for (edge_id, t) in collect(sparse_indices)[1:min(5, length(sparse_indices))]
        println("  $(edge_id), $(t): $(vars[(edge_id, t)])")
    end
    
    return vars
end

# Test the corrected approach
function test_corrected_container_usage()
    println("="^60)
    println("TESTING CORRECTED CONTAINER SPECIFICATION USAGE")
    println("="^60)
    
    model = Model()
    edges = [:edge1, :edge2, :edge3, :edge4, :edge5]
    time_steps = [1, 2, 3, 4]
    
    # Test 1: Capacity variables
    println("\n1. Testing capacity variables...")
    cap_vars = allocate_capacity_variables_corrected!(model, edges)
    
    # Test 2: Flow variables (2D)
    println("\n2. Testing flow variables (2D)...")
    flow_vars = allocate_flow_variables_corrected!(model, edges, time_steps)
    
    # Test 3: Sparse variables
    println("\n3. Testing sparse variables...")
    sparse_indices = Set([(edges[1], 1), (edges[1], 3), (edges[3], 2), (edges[5], 4)])
    sparse_vars = allocate_sparse_variables_corrected!(model, sparse_indices)
    
    println("\n" * "="^60)
    println("SUMMARY:")
    println("="^60)
    println("Total variables in model: $(num_variables(model))")
    println("✅ All container specifications working correctly!")
    
    return (cap_vars, flow_vars, sparse_vars)
end

# Run the test (this will work even if edge.jl has syntax errors)
println("Testing container specification usage independently...")

test_corrected_container_usage()
