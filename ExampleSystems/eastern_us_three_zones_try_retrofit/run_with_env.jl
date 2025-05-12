using MacroEnergy
using Gurobi

if !(@isdefined GRB_ENV)
    const GRB_ENV = Gurobi.Env()
end

(system, model) = run_case(@__DIR__; optimizer=Gurobi.Optimizer, optimizer_env=GRB_ENV);