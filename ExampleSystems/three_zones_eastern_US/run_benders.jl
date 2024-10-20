using Pkg
Pkg.activate(dirname(dirname(@__DIR__)))

using Macro
using MacroEnergySystemsDecomposition

case_path = @__DIR__
println("###### ###### ######")
println("Running case at $(case_path)")

setup = Dict(
    "MaxIter"=> 20,
    "MaxCpuTime" => 3600,
    "ConvTol" => 1e-3,
    "StabParam" => 0.0,
    "IntegerInvestment" => false
)

results = solve_model_with_benders(case_path, setup, Macro);

# capacity_results = Macro.get_optimal_asset_capacity(system)

# results_dir = joinpath(case_path, "results")
# mkpath(results_dir)
# Macro.write_csv(joinpath(results_dir, "capacity.csv"), capacity_results)
# println()

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