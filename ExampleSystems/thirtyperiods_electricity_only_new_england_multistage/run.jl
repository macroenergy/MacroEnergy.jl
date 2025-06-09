using MacroEnergy
using Gurobi

(system, model) = run_case(@__DIR__; 
                    optimizer=Gurobi.Optimizer,
                    optimizer_attributes=("Method" => 2, "Crossover" => 0, "BarConvTol" => 1e-3));
# (system, model) = run_case(@__DIR__; 
#                     optimizer=Gurobi.Optimizer,
#                     optimizer_attributes=("BarConvTol"=>1e-3, "Crossover" => 0, "Method" => 2, "PreSOS1BigM" => 0));