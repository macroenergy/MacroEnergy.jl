using Pkg
Pkg.activate(dirname(dirname(@__DIR__)))
using Macro
using CPLEX

case_path = @__DIR__
println("###### ###### ######")
println("Running case at $(case_path)")

system = Macro.load_system(case_path)

model = Macro.generate_model(system)

Macro.set_optimizer(model, CPLEX.Optimizer);

Macro.set_optimizer_attributes(model, "CPX_PARAM_BAREPCOMP"=>1e-6, "CPX_PARAM_LPMETHOD" => 4)

Macro.optimize!(model)

macro_objval = Macro.objective_value(model)

println("The runtime for Macro was $(Macro.solve_time(model))")

capacity_results = Macro.get_optimal_asset_capacity(system)

results_dir = joinpath(case_path, "results")
mkpath(results_dir)
Macro.write_csv(joinpath(results_dir, "capacity.csv"), capacity_results)
println()
