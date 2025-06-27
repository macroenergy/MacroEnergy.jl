using MacroEnergy
using Gurobi

(system, model) = run_case(@__DIR__; 
                    optimizer=Gurobi.Optimizer,
                    optimizer_attributes=("Method" => 2, "Crossover" => 0, "BarConvTol" => 1e-3));