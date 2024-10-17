using Pkg
Pkg.activate(dirname(dirname(@__DIR__)))
using Macro
using Gurobi

case_path = @__DIR__
println("###### ###### ######")
println("Running case at $(case_path)")

system = Macro.load_system(case_path)

Macro.scaling!(system)

model = Macro.generate_model(system)

Macro.set_optimizer(model, Gurobi.Optimizer);

Macro.set_optimizer_attributes(model, "BarConvTol"=>1e-3,"Crossover" => 0, "Method" => 2)

Macro.optimize!(model)

# Macro.compute_conflict!(model)
# list_of_conflicting_constraints = Macro.ConstraintRef[];
# for (F, S) in Macro.list_of_constraint_types(model)
#     for con in Macro.all_constraints(model, F, S)
#         if get_attribute(con, Macro.MOI.ConstraintConflictStatus()) == Macro.MOI.IN_CONFLICT
#             push!(list_of_conflicting_constraints, con)
#         end
#     end
# end
# display(list_of_conflicting_constraints)

println("")