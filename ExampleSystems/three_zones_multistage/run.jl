using MacroEnergy
using Gurobi

gurobi_attributes = (
    "FeasibilityTol" => 1.0e-05,
    "TimeLimit" => 110000,
    "Method" => 4,
    "Crossover" => -1,
    "PreDual" => 0
)

(system, model) = run_case(@__DIR__; optimizer=Gurobi.Optimizer, optimizer_attributes=gurobi_attributes);