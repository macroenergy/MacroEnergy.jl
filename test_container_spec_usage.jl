# Test: Proper Container Specification Usage
using Pkg
Pkg.activate(".")
using MacroEnergy, JuMP

println("Testing proper container specification usage...")

# Test 1: Simple capacity variables using container spec
model = Model()
edge_ids = [:edge1, :edge2, :edge3]

# The CORRECT way: Use container spec to create the container, then populate it
println("Creating container using macro_energy_container_spec...")
vars = macro_energy_container_spec(VariableRef, edge_ids)
println("Container created: $(typeof(vars))")

# Now create variables and store them IN the container
println("Creating variables and storing in container...")
for edge_id in edge_ids
    vars[edge_id] = @variable(model, lower_bound = 0.0, base_name = "vCAP_$(edge_id)")
end

println("Variables created and stored:")
for edge_id in edge_ids
    println("  $(edge_id): $(vars[edge_id])")
end

# Test 2: Flow variables (2D) using container spec
println("\nTesting 2D container for flow variables...")
time_steps = [1, 2, 3]
flow_vars = macro_energy_container_spec(VariableRef, edge_ids, time_steps)
println("2D Container created: $(typeof(flow_vars))")

# Create 2D variables
for edge_id in edge_ids
    for t in time_steps
        flow_vars[edge_id, t] = @variable(model, base_name = "vFLOW_$(edge_id)_$(t)")
    end
end

println("2D Variables created:")
for edge_id in edge_ids
    for t in time_steps
        println("  $(edge_id), $(t): $(flow_vars[edge_id, t])")
    end
end

println("\n✅ Container specification test completed successfully!")
println("Total variables in model: $(num_variables(model))")
