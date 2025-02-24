### Before running this script, you have to install the MacroEnergySolvers package.
### To use your local copy, type in the REPL: 
### using Pkg; Pkg.develop(path="path-to-MacroEnergySolvers.jl")

using MacroEnergy
using MacroEnergySolvers
using Gurobi

mono_system = MacroEnergy.load_system(@__DIR__);

MacroEnergy.scaling!(mono_system);

mono_model = MacroEnergy.generate_model(mono_system)

MacroEnergy.set_optimizer(mono_model, Gurobi.Optimizer);

MacroEnergy.set_optimizer_attributes(mono_model, "BarConvTol"=>1e-8,"Crossover" => 0, "Method" => 2)

MacroEnergy.optimize!(mono_model)

system = MacroEnergy.load_system(@__DIR__);

MacroEnergy.scaling!(system)

system_decomp = MacroEnergy.generate_decomposed_system(system);

planning_problem,linking_variables = initialize_planning_problem!(system,MacroEnergy);

number_of_subperiods = length(system_decomp);

subproblems = [Dict() for i in 1:number_of_subperiods];

MacroEnergySolvers.initialize_local_subproblems(system_decomp,subproblems,MacroEnergy);

linking_variables_sub = MacroEnergySolvers.get_local_linking_variables(subproblems);

# start_distributed_processes!(number_of_subperiods,MacroEnergy)

# subproblems_dict,linking_variables_sub = initialize_dist_subproblems!(system_decomp,MacroEnergy)


benders_setup = Dict(
    :solver=>:benders,
    :MaxIter=> 50,
    :MaxCpuTime => 7200,
    :ConvTol => 1e-3,
    :StabParam => 0.5,
    :StabDynamic => false,
    :IntegerInvestment => false
)

results = benders(planning_problem,linking_variables,subproblems,linking_variables_sub,benders_setup)

println("LB                     UB                      MonoOptVal")
println([results.LB_hist[end],results.UB_hist[end],MacroEnergy.objective_value(mono_model)])

println("")