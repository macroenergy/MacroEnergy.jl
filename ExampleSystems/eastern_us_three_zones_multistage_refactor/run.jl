using MacroEnergy
using Gurobi

(stages, models) = run_case(@__DIR__; optimizer=Gurobi.Optimizer);
