using Pkg
Pkg.activate(dirname(dirname(@__DIR__)))
using MacroEnergy
using Gurobi
using DataFrames

system = MacroEnergy.load_system(@__DIR__)
model = MacroEnergy.generate_model(system)

MacroEnergy.set_optimizer(model, Gurobi.Optimizer)
MacroEnergy.set_optimizer_attributes(model, "BarConvTol"=>1e-3,"Crossover" => 0, "Method" => 2)
MacroEnergy.optimize!(model)

MacroEnergy.compute_conflict!(model)
list_of_conflicting_constraints = MacroEnergy.ConstraintRef[];
for (F, S) in MacroEnergy.list_of_constraint_types(model)
    for con in MacroEnergy.JuMP.all_constraints(model, F, S)
        if MacroEnergy.JuMP.get_attribute(con, MacroEnergy.MOI.ConstraintConflictStatus()) == MacroEnergy.MOI.IN_CONFLICT
            push!(list_of_conflicting_constraints, con)
        end
    end
end
display(list_of_conflicting_constraints)

###
# Function to replace timestep indices with [t]
function extract_pattern(constraint)
    # Replace timestep indices with a placeholder
    return replace(constraint, r"\[\d+\]" => "[t]")
end

# Get the unique constraints
constraint_dict = Dict()
for constraint in list_of_conflicting_constraints
    pattern = extract_pattern(string(constraint))  # Extract pattern
    constraint_dict[pattern] = constraint  # Store the original constraint
end

for (key, value) in constraint_dict
    println(value)
end

function generalize_constraints(constraint_vector)
    # Create a container for the generalized constraints
    generalized_constraints = [] 
    for c in constraint_vector
        # Replace numeric indices with symbolic 't' in each constraint
        generalized_constraint = replace(string(c), r"\[\d+\]" => "[t]")
        push!(generalized_constraints, generalized_constraint)
    end
    return unique(generalized_constraints)
end

constraints = generalize_constraints(list_of_conflicting_constraints)
for constraint in constraints
    println(constraint)
end

# Write the unique constraints to a file
open("conflicting_constraints.txt", "w") do file
    write(file, constraints)
end