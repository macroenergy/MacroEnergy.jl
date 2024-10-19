using Pkg
Pkg.activate(dirname(dirname(@__DIR__)))
using Macro
using Gurobi

case_path = @__DIR__
println("###### ###### ######")
println("Running case at $(case_path)")

system = Macro.load_system(case_path)

start_time = time();
model = Macro.generate_model(system)
println("The model generation required $(time() - start_time)")

Macro.set_optimizer(model, Gurobi.Optimizer);

Macro.set_optimizer_attributes(model, "BarConvTol"=>1e-3,"Crossover" => 0, "Method" => 2)

Macro.optimize!(model)

capacity_results = Macro.get_optimal_asset_capacity(system)

results_dir = joinpath(case_path, "results")
mkpath(results_dir)
Macro.write_csv(joinpath(results_dir, "capacity.csv"), capacity_results)
println()

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

println("")