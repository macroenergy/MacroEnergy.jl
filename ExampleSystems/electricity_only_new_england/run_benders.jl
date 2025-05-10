using MacroEnergy
using Gurobi

(system, results) = run_case(@__DIR__;
    planning_optimizer=Gurobi.Optimizer,
    subproblem_optimizer=Gurobi.Optimizer,
    planning_optimizer_attributes=("Method" => 2, "Crossover" => 0, "BarConvTol" => 1e-4),
    subproblem_optimizer_attributes=("Method" => 2, "Crossover" => 1, "BarConvTol" => 1e-4));