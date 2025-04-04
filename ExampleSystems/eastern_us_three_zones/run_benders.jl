### Before running this script, you have to install the MacroEnergySolvers package.
### To use your local copy, type in the REPL: 
### using Pkg; Pkg.develop(path="path-to-MacroEnergySolvers.jl")

using MacroEnergy
using Gurobi


case_path = @__DIR__;

mono_stages = MacroEnergy.load_stages(case_path; lazy_load=true);

if !(@isdefined GRB_ENV)
    const GRB_ENV = Gurobi.Env()
end

benders_optimizer = Dict(
    :planning => MacroEnergy.create_optimizer(Gurobi.Optimizer, GRB_ENV, ("Method" => 2, "Crossover" => 0, "BarConvTol" => 1e-6)),
    :subproblems => MacroEnergy.create_optimizer(Gurobi.Optimizer, GRB_ENV, ("Method" => 2, "BarConvTol" => 1e-3, "Crossover" => 1))
)

(mono_stages, mono_model) = MacroEnergy.solve_stages(mono_stages, benders_optimizer);

println("Done!")