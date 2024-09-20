using Pkg
Pkg.activate(dirname(dirname(@__DIR__)))
using Macro
using Gurobi

case_path = @__DIR__
println("###### ###### ######")
println("Running case at $(case_path)")

system = Macro.load_system(case_path)

model = Macro.generate_model(system)

Macro.set_optimizer(model, Gurobi.Optimizer);
Macro.optimize!(model)
macro_objval = Macro.objective_value(model)

println("The runtime for Macro was $(Macro.solve_time(model))")
println("The objective value for Macro was $(macro_objval)")

using CSV, DataFrames
genx_results = joinpath(dirname(@__DIR__), "three_zones_genx", "results")
if isdir(genx_results)
    df_genx_status = CSV.read(joinpath(genx_results, "Status.csv"), DataFrame)
    println("The objective value for GenX was $(df_genx_status.Objval[1])")
    println(
        "The relative error between Macro and GenX is $(abs(df_genx_status.Objval[1]-macro_objval)/df_genx_status.Objval[1])",
    )
    println("The runtime for GenX was $(df_genx_status.Solve[1])")
end

println()
