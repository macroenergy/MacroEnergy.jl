using MacroEnergy
using HiGHS
using Pkg
try Pkg.add("Gurobi"); using Gurobi; catch e end
optim = is_gurobi_available() ? Gurobi.Optimizer : HiGHS.Optimizer
println()

system = MacroEnergy.load_system(@__DIR__)
optimizer = MacroEnergy.create_optimizer(optim)
model = MacroEnergy.generate_model(system, optimizer)
MacroEnergy.optimize!(model)
macro_objval = MacroEnergy.objective_value(model)