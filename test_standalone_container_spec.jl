# Standalone test of container specification functions
using JuMP
import JuMP.Containers: DenseAxisArray, SparseAxisArray

"""
Returns the correct container specification for MacroEnergy JuMP Models
"""
function macro_energy_container_spec(::Type{T}, kwarg...) where {T <: Any}
    return DenseAxisArray{T}(undef, kwarg...)
end

"""
Returns the correct container specification for MacroEnergy JuMP Models (Float64 specialization)
"""
function macro_energy_container_spec(::Type{Float64}, kwarg...)
    cont = DenseAxisArray{Float64}(undef, kwarg...)
    cont.data .= fill(NaN, size(cont.data))
    return cont
end

"""
Returns the correct sparse container specification for MacroEnergy JuMP Models
"""
function macro_energy_sparse_container_spec(::Type{T}, kwarg...) where {T <: JuMP.AbstractJuMPScalar}
    indexes = Base.Iterators.product(kwarg...)
    contents = Dict{eltype(indexes), T}(i => zero(T) for i in indexes)
    return JuMP.Containers.SparseAxisArray(contents)
end

function macro_energy_sparse_container_spec(::Type{T}, kwarg...) where {T <: JuMP.VariableRef}
    indexes = Base.Iterators.product(kwarg...)
    contents = Dict{eltype(indexes), Union{Nothing, T}}(indexes .=> nothing)
    return JuMP.Containers.SparseAxisArray(contents)
end

function macro_energy_sparse_container_spec(::Type{T}, sparse_indices::Set) where {T <: JuMP.VariableRef}
    contents = Dict{eltype(sparse_indices), Union{Nothing, T}}(idx => nothing for idx in sparse_indices)
    return JuMP.Containers.SparseAxisArray(contents)
end

# Test the corrected approach
function test_corrected_usage()
    println("="^60)
    println("CORRECTED CONTAINER SPECIFICATION USAGE TEST")
    println("="^60)
    
    model = Model()
    edges = [:edge1, :edge2, :edge3, :edge4, :edge5]
    time_steps = [1, 2, 3, 4]
    
    # Test 1: The CORRECT way - Use container spec, then populate
    println("\\n1. Testing CORRECTED capacity variables approach...")
    cap_vars = macro_energy_container_spec(VariableRef, edges)
    println("   Container created: $(typeof(cap_vars))")
    
    # Populate the container
    for edge_id in edges
        cap_vars[edge_id] = @variable(model, lower_bound = 0.0, base_name = "vCAP_$(edge_id)")
    end
    println("   ✅ Variables stored in container successfully")
    
    # Test 2: The CORRECT way for 2D variables
    println("\\n2. Testing CORRECTED flow variables (2D) approach...")
    flow_vars = macro_energy_container_spec(VariableRef, edges, time_steps)
    println("   2D Container created: $(typeof(flow_vars))")
    
    # Populate the 2D container
    for edge_id in edges
        for t in time_steps
            flow_vars[edge_id, t] = @variable(model, base_name = "vFLOW_$(edge_id)_$(t)")
        end
    end
    println("   ✅ 2D Variables stored in container successfully")
    
    # Test 3: Sparse container
    println("\\n3. Testing CORRECTED sparse variables approach...")
    sparse_indices = Set([(edges[1], 1), (edges[1], 3), (edges[3], 2), (edges[5], 4)])
    sparse_vars = macro_energy_sparse_container_spec(VariableRef, sparse_indices)
    println("   Sparse container created: $(typeof(sparse_vars))")
    
    # Populate sparse container
    for (edge_id, t) in sparse_indices
        sparse_vars[(edge_id, t)] = @variable(model, base_name = "vSPARSE_$(edge_id)_$(t)")
    end
    println("   ✅ Sparse variables stored in container successfully")
    
    # Verification
    println("\\n" * "="^60)
    println("VERIFICATION:")
    println("="^60)
    println("Total variables in model: $(num_variables(model))")
    println("Dense container variables: $(length(edges))")
    println("2D container variables: $(length(edges) * length(time_steps))")
    println("Sparse container variables: $(length(sparse_indices))")
    
    expected_total = length(edges) + (length(edges) * length(time_steps)) + length(sparse_indices)
    println("Expected total: $(expected_total)")
    
    if num_variables(model) == expected_total
        println("✅ ALL TESTS PASSED - Container specifications working correctly!")
    else
        println("❌ Mismatch in variable count")
    end
    
    # Show access examples
    println("\\nAccess examples:")
    println("  cap_vars[:edge1] = $(cap_vars[:edge1])")
    println("  flow_vars[:edge2, 3] = $(flow_vars[:edge2, 3])")
    println("  sparse_vars[(:edge1, 1)] = $(sparse_vars[(:edge1, 1)])")
    
    return (cap_vars, flow_vars, sparse_vars)
end

# Run the test
test_corrected_usage()
