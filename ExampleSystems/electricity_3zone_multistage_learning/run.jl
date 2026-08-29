using MacroEnergy
using Gurobi

(system, model) = run_case(@__DIR__; optimizer=Gurobi.Optimizer, optimizer_attributes=("Method" => 2, "Crossover" => 0, "BarConvTol" => 1e-3));

# (system, model) = run_case(@__DIR__; optimizer=Gurobi.Optimizer);

# using MacroEnergy
# using HiGHS

# (case, solution) = run_case(@__DIR__; 
#     optimizer=HiGHS.Optimizer,
#     optimizer_attributes=("solver" => "ipm", "run_crossover" => "off", "ipm_optimality_tolerance" => 1e-3)
# );