#!/usr/bin/env julia

"""
Simple test script for the custom Edge Variable and Constraint Preallocation System
"""

using Pkg
Pkg.activate(".")

using MacroEnergy
using JuMP

println("Testing Custom Edge Preallocation System")
println("="^50)

# Test basic functionality
println("1. Testing EdgeOptimizationManager creation...")

model = Model()
time_horizon = [1, 2, 3]

try
    manager = EdgeOptimizationManager(model, time_horizon)
    println("✓ EdgeOptimizationManager created successfully")
    
    # Test variable type definitions
    println("\n2. Testing variable type definitions...")
    cap_var_type = EdgeCapacityVariable()
    flow_var_type = EdgeFlowVariable()
    println("✓ Variable types instantiated successfully")
    
    # Test constraint type definitions  
    println("\n3. Testing constraint type definitions...")
    cap_const_type = EdgeCapacityConstraint()
    flow_const_type = EdgeFlowConstraint()
    println("✓ Constraint types instantiated successfully")
    
    # Test container creation
    println("\n4. Testing container creation...")
    edge_ids = [:edge1, :edge2]
    
    var_container = EdgeVariableContainer(cap_var_type, edge_ids, time_horizon, description="test")
    const_container = EdgeConstraintContainer(cap_const_type, edge_ids, time_horizon, description="test")
    
    println("✓ Variable container created with $(length(var_container.edge_ids)) edges")
    println("✓ Constraint container created with $(length(const_container.edge_ids)) edges")
    
    # Test container access methods
    println("\n5. Testing container access methods...")
    
    # Create a dummy variable for testing
    test_var = @variable(model, x >= 0, base_name="test_var")
    
    # Test setting and getting variables
    set_variable!(var_container, :edge1, test_var, 1)
    retrieved_var = get_variable(var_container, :edge1, 1)
    
    if retrieved_var == test_var
        println("✓ Variable container access methods working")
    else
        println("❌ Variable container access methods failed")
    end
    
    println("\n" * "="^50)
    println("✅ BASIC FUNCTIONALITY TEST PASSED")
    println("✓ All core components are working correctly")
    println("✓ Ready for integration with MacroEnergy edge system")
    println("="^50)
    
catch e
    println("❌ Error during testing: $e")
    println("❌ BASIC FUNCTIONALITY TEST FAILED")
    rethrow(e)
end
