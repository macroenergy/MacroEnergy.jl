using MacroEnergy
using Gurobi

(stages, models) = run_case(case; optimizer=Gurobi.Optimizer);
