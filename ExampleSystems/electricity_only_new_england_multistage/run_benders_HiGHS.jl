using MacroEnergy
using HiGHS

(system, model) = run_case(@__DIR__;
    planning_optimizer=HiGHS.Optimizer,
    subproblem_optimizer=HiGHS.Optimizer,
    planning_optimizer_attributes=("solver" => "ipm", "run_crossover" => "off", "ipm_optimality_tolerance" => 1e-3),
    subproblem_optimizer_attributes=("solver" => "ipm", "run_crossover" => "on", "ipm_optimality_tolerance" => 1e-3));