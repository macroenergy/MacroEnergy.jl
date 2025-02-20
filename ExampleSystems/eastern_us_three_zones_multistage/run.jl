using MacroEnergy
using Gurobi

(system, model) = run_multistage_case(@__DIR__; num_stages = 3, perfect_foresight = false, optimizer=Gurobi.Optimizer);
