using Macro
using Gurobi

test_case_path = joinpath(dirname(dirname(@__DIR__)), "ExampleSystems", "three_zones_macro")

macro_settings = Macro.configure_settings(joinpath(test_case_path, "settings", "macro_settings.yml"))

# Load and create all the Nodes
system_path = joinpath(test_case_path, "system")

# Read in all the commodities
commodities = Macro.load_commodities_json(system_path)

# Read in time data
time_data = Macro.load_time_json(system_path, commodities)

# Read in all the nodes
network_dir = joinpath(system_path, "network")
nodes = Macro.load_nodes_json(network_dir, time_data)

# Read in demand data
Macro.load_demand_data!(nodes, system_path)

# Create the network (aka Edges) between Nodes
edges = Macro.load_edges_json(network_dir, time_data, nodes)

# Load all the asset data
asset_dir = joinpath(test_case_path, "assets")
assets = Macro.load_assets_json(asset_dir, time_data, nodes)

# Load the capacity factor data for the assets
Macro.load_capacity_factor!(assets, asset_dir)

# Read in fuel data and CO2 emissions
Macro.load_fuel_data!(system_path, assets)

system = Macro.create_system(nodes, edges, assets)

model = Macro.generate_model(system)

Macro.set_optimizer(model,Gurobi.Optimizer);
Macro.optimize!(model)
macro_objval = Macro.objective_value(model)

println("The runtime for Macro was $(Macro.solve_time(model))")

using CSV, DataFrames
df_genx_status = CSV.read("/Users/lb9239/Documents/ZERO_lab/Macro/Macro/ExampleSystems/three_zones_genx/results_fulltimeseries/Status.csv",DataFrame)
println("The objective value for GenX was $(df_genx_status.Objval[1])")
println("The relative error between Macro and GenX is $(abs(df_genx_status.Objval[1]-macro_objval)/df_genx_status.Objval[1])")
println("The runtime for Macro was $(Macro.solve_time(model))")
println("The runtime for GenX was $(df_genx_status.Solve[1])")

println()