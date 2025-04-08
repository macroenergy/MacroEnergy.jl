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
    :planning => MacroEnergy.create_optimizer(Gurobi.Optimizer,GRB_ENV,("Method" => 2, "Crossover" => 0, "BarConvTol" => 1e-3)),
    :subproblems => MacroEnergy.create_optimizer(Gurobi.Optimizer, GRB_ENV, ("Method" => 2, "Crossover" => 1, "BarConvTol" => 1e-3)),
)

# MacroEnergy.start_distributed_processes!(2, Gurobi, case_path)

stages = MacroEnergy.load_stages(case_path; lazy_load=true);

system = stages.systems[1];

system_decomp = MacroEnergy.generate_decomposed_system(system);

subproblems_dict, linking_variables_sub =  MacroEnergy.initialize_dist_subproblems!(system_decomp,benders_optimizers[:subproblems]);

# MacroEnergy.solve_stages(stages, benders_optimizers);

println("Done!")