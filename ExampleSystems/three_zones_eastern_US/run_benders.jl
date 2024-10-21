using Pkg
Pkg.activate(dirname(dirname(@__DIR__)))

using Macro
using MacroEnergySystemsDecomposition

case_path = @__DIR__
println("###### ###### ######")
println("Running case at $(case_path)")

setup = Dict(
    "MaxIter"=> 200,
    "MaxCpuTime" => 7200,
    "ConvTol" => 1e-3,
    "StabParam" => 0.5,
    "StabDynamic" => false,
    "IntegerInvestment" => false
)

results = solve_model_with_benders(case_path, setup, Macro);

benders_iter = Macro.DataFrame(:iter=>1:length(results.LB_hist),:LB=>results.LB_hist,:UB=>results.UB_hist,:runtime=>results.runtime)

# capacity_results = Macro.get_optimal_asset_capacity(system)

results_dir = joinpath(case_path, "results")
mkpath(results_dir)
Macro.write_csv(joinpath(case_path, "benders_iter.csv"), benders_iter)
#Macro.write_csv(joinpath(results_dir, "capacity.csv"), capacity_results)
println()

println("")