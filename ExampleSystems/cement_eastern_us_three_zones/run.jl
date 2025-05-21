using Pkg
Pkg.activate(dirname(dirname(@__DIR__)))
using MacroEnergy
using Gurobi
using DataFrames

case_path = @__DIR__
println("###### ###### ######")
println("Running case at $(case_path)")

## Run model

system = MacroEnergy.load_system(case_path)

model = MacroEnergy.generate_model(system)

MacroEnergy.set_optimizer(model, Gurobi.Optimizer);

MacroEnergy.set_optimizer_attributes(model, "BarConvTol"=>1e-3,"Crossover" => 0, "Method" => 2)

MacroEnergy.optimize!(model)

## Output results
# Create results directory
results_dir = MacroEnergy.create_output_path(system)

# Capacity results
write_capacity(joinpath(results_dir, "capacity.csv"), system)

# Cost results
write_costs(joinpath(results_dir, "costs.csv"), system, model)

# Flow results
write_flow(joinpath(results_dir, "flow.csv"), system)

# Macro.compute_conflict!(model)
# list_of_conflicting_constraints = Macro.ConstraintRef[];
# for (F, S) in Macro.list_of_constraint_types(model)
#     for con in Macro.JuMP.all_constraints(model, F, S)
#         if Macro.JuMP.get_attribute(con, Macro.MOI.ConstraintConflictStatus()) == Macro.MOI.IN_CONFLICT
#             push!(list_of_conflicting_constraints, con)
#         end
#     end
# end
# display(list_of_conflicting_constraints)