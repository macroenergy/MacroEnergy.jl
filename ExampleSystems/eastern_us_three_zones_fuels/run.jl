using MacroEnergy
using Gurobi

(system, model) = run_case(@__DIR__; optimizer=Gurobi.Optimizer);
