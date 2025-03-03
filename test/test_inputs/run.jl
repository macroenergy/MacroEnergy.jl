using MacroEnergy
using Gurobi

#(system, model) = run_case(@__DIR__; optimizer=Gurobi.Optimizer);

println()

system = MacroEnergy.load_system(@__DIR__)
model = MacroEnergy.generate_model(system)
MacroEnergy.set_optimizer(model, Gurobi.Optimizer)
MacroEnergy.optimize!(model)
macro_objval = MacroEnergy.objective_value(model)