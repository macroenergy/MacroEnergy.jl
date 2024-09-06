using Pkg
Pkg.activate(dirname(dirname(@__DIR__)))
using Macro
using Gurobi

(@isdefined GRB_ENV) || (const GRB_ENV = Gurobi.Env())

case_path = @__DIR__
# println("###### ###### ######")
# println("Running monolithic case at $(case_path)")

# system = Macro.load_system(case_path)

# model = Macro.generate_model(system)

# Macro.set_optimizer(model,Gurobi.Optimizer);
# Macro.optimize!(model)
# monolithic_objval = Macro.objective_value(model)

# using Distributed

# addprocs(5)

# @everywhere begin
#     import Pkg
#     Pkg.activate(dirname(dirname(dirname(@__FILE__))))
#     using Macro
# end

bd_system = Macro.load_system(case_path)

benders_models = Macro.generate_benders_models(bd_system);

# _,planning_sol,LB_hist,UB_hist,cpu_time  = Macro.benders(benders_models);


println()