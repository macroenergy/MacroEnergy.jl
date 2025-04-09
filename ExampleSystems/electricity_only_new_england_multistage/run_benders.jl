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

benders_optimizers = Dict(
    :planning => MacroEnergy.create_optimizer(Gurobi.Optimizer,GRB_ENV,("Method" => 2, "Crossover" => 0, "BarConvTol" => 1e-6)),
    :subproblems => MacroEnergy.create_optimizer(Gurobi.Optimizer, GRB_ENV, ("Method" => 2, "Crossover" => 1, "BarConvTol" => 1e-6)),
)
mono_optimizer = MacroEnergy.create_optimizer(Gurobi.Optimizer, GRB_ENV, ("Method" => 2, "Crossover" => 0, "BarConvTol" => 1e-6))

stages = MacroEnergy.load_stages(case_path; lazy_load=true);
stages,bd_results = MacroEnergy.solve_stages(stages, benders_optimizers,MacroEnergy.PerfectForesight(),MacroEnergy.Benders());

mono_stages = MacroEnergy.load_stages(case_path; lazy_load=true);
mono_stages,mono_model = MacroEnergy.solve_stages(mono_stages,mono_optimizer,MacroEnergy.PerfectForesight(),MacroEnergy.Monolithic());

_bd_capacity = MacroEnergy.get_available_capacity(stages.systems);
bd_capacity = Dict(y=>MacroEnergy.value(_bd_capacity[y]) for y in keys(_bd_capacity));
_mono_capacity = MacroEnergy.get_available_capacity(mono_stages.systems);
mono_capacity = Dict(y=>MacroEnergy.value(_mono_capacity[y]) for y in keys(_mono_capacity));

println("Done!")