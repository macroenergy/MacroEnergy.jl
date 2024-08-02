using Pkg
Pkg.activate(dirname(dirname(@__DIR__)))
using Macro
using Gurobi

test_case_path = joinpath(dirname(dirname(@__DIR__)), "ExampleSystems", "three_zones_macro_biomass")

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

# # Read in demand data
Macro.load_demand_data!(nodes, system_path)

# # Create the network (aka Edges) between Nodes
edges = Macro.load_edges_json(network_dir, time_data, nodes)

# # Load all the asset data
asset_dir = joinpath(test_case_path, "assets")
assets = Macro.load_assets_json(asset_dir, time_data, nodes)

# # Load the capacity factor data for the assets
Macro.load_capacity_factor!(assets, asset_dir)

# # Read in fuel data and CO2 emissions
Macro.load_fuel_data!(system_path, assets)

system = Macro.create_system(nodes, edges, assets)

model = Macro.generate_model(system);

Macro.set_optimizer(model,Gurobi.Optimizer);
Macro.optimize!(model)
macro_objval = Macro.objective_value(model)

println("The runtime for Macro was $(Macro.solve_time(model))")

capacity_results = Macro.get_optimal_asset_capacity(assets);

println()