### Before running this script, you have to install the MacroEnergySolvers package.
### To use your local copy, type in the REPL: 
### using Pkg; Pkg.develop(path="path-to-MacroEnergySolvers.jl")

using MacroEnergy
using Gurobi
using MacroEnergySolvers

case_path = @__DIR__;

if !(@isdefined GRB_ENV)
    const GRB_ENV = Gurobi.Env()
end 

stages = MacroEnergy.load_stages(case_path; lazy_load=true);

benders_optimizers = Dict(
    :planning => MacroEnergy.create_optimizer(Gurobi.Optimizer,GRB_ENV,("Method" => 2, "Crossover" => 0, "BarConvTol" => 1e-3)),
    :subproblems => MacroEnergy.create_optimizer(Gurobi.Optimizer, GRB_ENV, ("Method" => 2, "Crossover" => 1, "BarConvTol" => 1e-3)),
)

stages, results = MacroEnergy.solve_stages(stages, benders_optimizers);

println("Done!")