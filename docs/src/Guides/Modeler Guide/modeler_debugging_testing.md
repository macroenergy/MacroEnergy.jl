# Debugging and Testing a Macro Model

```@meta
DocTestSetup = quote
    using MacroEnergy
end
```

Macro offers a range of utility functions designed to make debugging and testing new models and sectors more efficient and straightforward.

The following functions are organized with the following sections:
- [Working with a System](@ref "Working with a System")
- [Generating a Model](@ref "Model Generation and Running")
- [Working with Nodes](@ref "Working with Nodes in a System")
- [Working with Assets](@ref "Working with Assets")
- [Working with Edges](@ref "Working with Edges")
- [Working with Transformations](@ref "Working with Transformations")
- [Working with Storages](@ref "Working with Storages")
- [Time Management](@ref "Time Management")
- [Results Collection and Writing](@ref "Results Collection and Writing")

## Working with a System
Let's start by loading a system from a case folder (you can find more information about the structure of this folder in the [Running Macro](@ref) section).

### `load_case`
```@repl utils
using MacroEnergy
using HiGHS # hide
using DataFrames # hide
case = MacroEnergy.load_case("doctest");
system = case.systems[1];
```

### `propertynames`
The `propertynames` function in Julia can be used to retrieve the names of the fields of a `System` object, such as the data directory path, settings, and locations.

```@repl utils
propertynames(system)
```

- `data_dirpath`: Path to the data directory.
- `settings`: Settings of the system.
- `commodities`: Sectors modeled in the system.
- `timedata`: Time resolution for each sector.
- `locations`: Vector of all `Location`s and `Node`s.
- `assets`: Vector of all `Asset`s.

A `System` consists of six primary fields, each of which can be accessed using dot notation:
```@repl utils
system.data_dirpath
system.settings
```

When interacting with a `System`, users might need to **retrieve information** about specific nodes, locations, or assets. The functions listed below are helpful for these tasks:

### [`find_node`](@ref)
Finds a node by its ID.
```@repl utils
co2_node = MacroEnergy.find_node(system.locations, :co2_sink)
```

### [`get_asset_types`](@ref)
Retrieves all the types of assets in the system.
```@repl utils
asset_types = MacroEnergy.get_asset_types(system);
unique(asset_types)
```

### [`asset_ids`](@ref)
Retrieves the IDs of all the assets in the system.
```@repl utils
ids = MacroEnergy.asset_ids(system)
```
Once you have the IDs, you can retrieve an asset by its ID using the following function:
### [`get_asset_by_id`](@ref)
Retrieves an asset by its ID.
```@repl utils
battery_SE = MacroEnergy.get_asset_by_id(system, :battery_SE);
thermal_plant_SE = MacroEnergy.get_asset_by_id(system, :SE_natural_gas_fired_combined_cycle_1);
```

The following function can be useful to retrieve a vector of all the assets of a given type.
### [`get_assets_sametype`](@ref)
Returns a vector of assets of a given type.
```@repl utils
batteries = MacroEnergy.get_assets_sametype(system, Battery);
battery = batteries[1]; # first battery in the list
thermal_plants = MacroEnergy.get_assets_sametype(system, ThermalPower{NaturalGas});
thermal_plant = thermal_plants[1]; # first thermal power plant in the list
```

## Model Generation and Running

### `generate_model`
Uses JuMP to generate the optimization model for the system data. 
```@repl utils
model = MacroEnergy.generate_model(case);
MacroEnergy.set_silent(model) # hide
```

### `set_optimizer`
Sets the optimizer for the JuMP model.
```@repl utils
MacroEnergy.set_optimizer(model, HiGHS.Optimizer);
```

### `optimize!`
Solves the optimization model.
```@repl utils
MacroEnergy.optimize!(model)
```

The following set of functions can be used to retrieve the optimal values of some variables in the model.
### [`get_optimal_capacity`](@ref)
Fetches the final capacities for all assets.
```@repl utils
capacity = MacroEnergy.get_optimal_capacity(system);
capacity[!, [:commodity, :resource_id, :value]]
```

### [`get_optimal_new_capacity`](@ref)
Fetches the new capacities for all assets.
```@repl utils
new_capacity = MacroEnergy.get_optimal_new_capacity(system);
new_capacity[!, [:commodity, :resource_id, :value]]
```

### [`get_optimal_retired_capacity`](@ref)
Fetches the retired capacities for all assets.
```@repl utils
retired_capacity = MacroEnergy.get_optimal_retired_capacity(system);
retired_capacity[!, [:commodity, :resource_id, :value]]
```

See the [Results Collection and Writing](@ref "Results Collection and Writing") section for more information on how to write the results to a file.

## Working with Nodes in a System
Once a `System` object is loaded, and the model is generated, users can use the following functions to inspect the nodes in the system.

!!! tip "Node Interface"
    For a comprehensive list of function interfaces available for node besides `id`, `commodity_type` and the ones listed below, users can refer to the `node.jl` and the `vertex.jl` source code.

### [`find_node`](@ref)
Finds a node in the `System` by its ID.

```@repl utils
elec_node = MacroEnergy.find_node(system.locations, :elec_SE);
```

!!! note "Understanding Balance Equations"
    Nodes, as explained in the [Macro Internal Components](@ref) section, are a unique type of *vertex* that represent the demand or supply of a commodity, where each vertex in Macro is associated with a **balance equation**.
    To programmatically access all balance equations within the system, the following functions are available:
    - [`balance_ids`](@ref): Retrieve the **IDs** of all balance equations associated with a vertex.
    - [`get_balance`](@ref): Obtain the **mathematical expression** of a specific balance equation.
    - [`balance_data`](@ref): Access the **input balance data**, which typically includes the stoichiometric coefficients of a specific balance equation, if applicable.

Here is an example of how to use these functions to access the balance equations for the electricity node in the system:

### [`balance_ids`](@ref)
Retrieves the IDs of all balance equations in a node.
```@repl utils
MacroEnergy.balance_ids(elec_node)
```

!!! note "Demand Balance Equation"
    Macro automatically creates a `:demand` balance equation for each node that has a `BalanceConstraint`. 

### [`get_balance`](@ref)
Retrieves the mathematical expression of the demand balance equation for the node.
```@repl utils
demand_expression = MacroEnergy.get_balance(elec_node, :demand);
demand_expression[1] # first time step
```

### [`balance_ids`](@ref)
```@repl utils
co2_node = MacroEnergy.find_node(system.locations, :co2_sink);
MacroEnergy.balance_ids(co2_node)
```

!!! note "CO₂ Balance Equation"
    Macro automatically creates an `:emissions` balance equation for each CO₂ node that has a `CO2CapConstraint`.

### [`get_balance`](@ref)
```@repl utils
emissions_expression = MacroEnergy.get_balance(co2_node, :emissions);
emissions_expression[1] # first time step
```

!!! tip "Total Emissions"
    To calculate the total emissions at a node, users should perform the following steps:
    ```@repl utils
    emissions_expression = MacroEnergy.get_balance(co2_node, :emissions);
    MacroEnergy.value(sum(emissions_expression))
    ```

To check and visualize the mathematical expressions of the **constraints** applied to a node, the following functions are available:
- [`all_constraints`](@ref): Retrieve all constraints associated with a node.
- [`all_constraints_types`](@ref): Retrieve all types of constraints associated with a node.
- [`get_constraint_by_type`](@ref): Retrieve a specific constraint on a node by its type.

### [`all_constraints`](@ref)
Retrieves all the constraints attached to a node.
```@repl utils
all_constraints = MacroEnergy.all_constraints(elec_node);
```

### [`all_constraints_types`](@ref)
Retrieves all the types of constraints attached to a node.
```@repl utils
all_constraints_types = MacroEnergy.all_constraints_types(elec_node)
```

### [`get_constraint_by_type`](@ref), `constraint_ref`
Retrieves a constraint on a node by its type.
```@repl utils
balance_constraint = MacroEnergy.get_constraint_by_type(elec_node, BalanceConstraint);
MacroEnergy.constraint_ref(balance_constraint);

max_non_served_demand_constraint = MacroEnergy.get_constraint_by_type(elec_node, MaxNonServedDemandConstraint);
MacroEnergy.constraint_ref(max_non_served_demand_constraint)[1:5]
```

## Working with Assets
Together with Locations, assets form the core components of an energy system in Macro. The functions below are essential for managing and interacting with assets.

### `id`
Retrieves the ID of an asset.
```@repl utils
thermal_plant = MacroEnergy.get_asset_by_id(system, :SE_natural_gas_fired_combined_cycle_1);
MacroEnergy.id(thermal_plant)
```

### [`print_struct_info`](@ref)
Prints the structure of an asset in terms of its components (edges, transformations, storages, etc.)
```@repl utils
MacroEnergy.print_struct_info(thermal_plant)
```

Once you have collected the **names** of the components of an asset, you can use the following function to get a specific component by its name.

### [`get_component_by_fieldname`](@ref)
Retrieves a component of an asset by its field name.
```@repl utils
elec_edge = MacroEnergy.get_component_by_fieldname(thermal_plant, :elec_edge);
MacroEnergy.id(elec_edge)
MacroEnergy.typeof(elec_edge)
MacroEnergy.commodity_type(elec_edge)
```

Alternatively, users can retrieve a specific component using its ID.
### [`get_component_ids`](@ref)
Retrieves the IDs of all the components of an asset.
```@repl utils
MacroEnergy.get_component_ids(thermal_plant)
```

### [`get_component_by_id`](@ref)
Retrieves a component of an asset by its ID.
```@repl utils
elec_edge = MacroEnergy.get_component_by_id(thermal_plant, :SE_natural_gas_fired_combined_cycle_1_elec_edge);
MacroEnergy.id(elec_edge)
MacroEnergy.typeof(elec_edge)
```

## Working with Edges

### `id`
Retrieves the ID of an edge.
```@repl utils
MacroEnergy.id(elec_edge)
```

### `commodity_type`
Retrieves the commodity type of an edge.
```@repl utils
MacroEnergy.commodity_type(elec_edge)
```

!!! tip "Edge Interface"
    For a comprehensive list of function interfaces available for edge besides `id`, `commodity_type` and the ones listed below, users can refer to the `edge.jl` source code.

### [`get_edges`](@ref)
Retrieves all the edges in the system.
```@repl utils
edges = MacroEnergy.get_edges(system);
```

### `capacity`
Retrieves the capacity expression of an edge.
```@repl utils
capacity_expression = MacroEnergy.capacity(elec_edge)
```

### `final_capacity`
Retrieves the final capacity of an edge (i.e. the optimal value of the capacity expression).
```@repl utils
capacity_expression = MacroEnergy.capacity(elec_edge)
MacroEnergy.value(capacity_expression)
```

### `flow`
Retrieves the flow variables of an edge.
```@repl utils
flow_variables = MacroEnergy.flow(elec_edge);
flow_variables[1:5]
```

### `value`
Retrieves the values of the flow variables of an edge.
```@repl utils
flow_values = MacroEnergy.value.(flow_variables);
flow_values[1:5]
```

!!! note "Broadcasted `value`"
    Note that the `value` function is called with the dot notation to apply it to each element of the `flow_variables` array (see [Julia's documentation](https://docs.julialang.org/en/v1/manual/functions/#man-vectorized) for more information).

In this example, we first get the flow of the CO₂ edge and then we call the `value` function to get the values of these variables.
```@repl utils
co2_edge = MacroEnergy.get_component_by_fieldname(thermal_plant, :co2_edge);
emission = MacroEnergy.flow(co2_edge)[1:5]
emission_values = MacroEnergy.value.(emission);
emission_values[1:5]
```

The functions available for nodes when dealing with constraints can also be used for edges.

### [`all_constraints_types`](@ref)
```@repl utils
MacroEnergy.all_constraints_types(elec_edge)
```

### [`get_constraint_by_type`](@ref)
```@repl utils
constraint = MacroEnergy.get_constraint_by_type(elec_edge, CapacityConstraint);
MacroEnergy.constraint_ref(constraint)[1:5]
```

### `start_vertex`
Retrieves the starting node of an edge.
```@repl utils
start_node = MacroEnergy.start_vertex(elec_edge);
MacroEnergy.id(start_node)
MacroEnergy.typeof(start_node)
```

### `end_vertex`
Retrieves the ending node of an edge.
```@repl utils
end_node = MacroEnergy.end_vertex(elec_edge);
MacroEnergy.id(end_node)
MacroEnergy.typeof(end_node)
```

## Working with Transformations

!!! tip "Transformation Interface"
    For a comprehensive list of function interfaces available for transformation besides `id`, `commodity_type` and the ones listed below, users can refer to the `transformation.jl` and the `vertex.jl` source code.

To access the transformation component of an asset, utilize the following functions:
```@repl utils
MacroEnergy.print_struct_info(thermal_plant)
thermal_transform = MacroEnergy.get_component_by_fieldname(thermal_plant, :thermal_transform);
MacroEnergy.id(thermal_transform)
MacroEnergy.typeof(thermal_transform)
```

### [`balance_ids`](@ref)
Retrieves the IDs of all the balance equations in a transformation.
```@repl utils
MacroEnergy.balance_ids(thermal_transform)
```

### [`balance_data`](@ref)
Retrieves the balance data of a transformation. This is very useful to check the **stoichiometric coefficients** of a transformation.
```@repl utils
MacroEnergy.balance_data(thermal_transform, :energy)
```

### [`get_balance`](@ref)
Retrieves the mathematical expression of the balance of a transformation.
```@repl utils
MacroEnergy.get_balance(thermal_transform, :energy)[1:5]
```

We can do the same for the emissions balance equation.
### [`balance_data`](@ref)
```@repl utils
MacroEnergy.balance_data(thermal_transform, :emissions)
```

### [`get_balance`](@ref)
```@repl utils
MacroEnergy.get_balance(thermal_transform, :emissions)[1:5]
```

The functions available for nodes and edges can also be applied to transformations.
### [`all_constraints`](@ref)
```@repl utils
MacroEnergy.all_constraints(thermal_transform)
```

### [`all_constraints_types`](@ref)
```@repl utils
MacroEnergy.all_constraints_types(thermal_transform)
```

### [`get_constraint_by_type`](@ref)
```@repl utils
MacroEnergy.get_constraint_by_type(thermal_transform, BalanceConstraint)
```

## Working with Storages

!!! tip "Storage Interface"
    For a comprehensive list of function interfaces available for storage besides `id`, `commodity_type` and the ones listed below, users can refer to the `storage.jl` and the `vertex.jl` source code.

To access the storage component of an asset, utilize the following functions:
```@repl utils
battery = MacroEnergy.get_asset_by_id(system, :battery_SE);
MacroEnergy.print_struct_info(battery)
storage = MacroEnergy.get_component_by_fieldname(battery, :battery_storage);
MacroEnergy.id(storage)
MacroEnergy.typeof(storage)
```

### [`balance_ids`](@ref)
Retrieves the IDs of all the balance equations in a storage.
```@repl utils
MacroEnergy.balance_ids(storage)
```

### [`balance_data`](@ref)
Retrieves the balance data of a storage. This is very useful to check the **stoichiometric coefficients** of a storage.
```@repl utils
MacroEnergy.balance_data(storage, :storage)
```

### [`get_balance`](@ref)
Retrieves the mathematical expression of the balance of a storage.
```@repl utils
MacroEnergy.get_balance(storage, :storage)[1:5]
```

The same set of functions that we have seen for nodes, edges, and transformations are also available for storages.
### [`all_constraints_types`](@ref)
```@repl utils
MacroEnergy.all_constraints_types(storage)
```

### [`get_constraint_by_type`](@ref)
```@repl utils
MacroEnergy.get_constraint_by_type(storage, BalanceConstraint)
constraint = MacroEnergy.get_constraint_by_type(storage, StorageCapacityConstraint);
MacroEnergy.constraint_ref(constraint)[1:5]
```

### `storage_level`
Retrieves the storage level variables of a storage component.
```@repl utils
storage_level = MacroEnergy.storage_level(storage);
MacroEnergy.value.(storage_level)[1:5]
```

### `charge_edge`
Retrieves the charge edge connected to a storage component.
```@repl utils
charge_edge = MacroEnergy.charge_edge(storage);
MacroEnergy.id(charge_edge)
MacroEnergy.typeof(charge_edge)
```

### `discharge_edge`
Retrieves the discharge edge connected to a storage component.
```@repl utils
discharge_edge = MacroEnergy.discharge_edge(storage);
MacroEnergy.id(discharge_edge)
MacroEnergy.typeof(discharge_edge)
```

### `spillage_edge`
Retrieves the spillage edge connected to a storage component (applicable to hydro reservoirs).
```julia
julia> MacroEnergy.spillage_edge(storage)
```

## Time Management
```@repl utils
vertex = MacroEnergy.find_node(system.locations, :elec_SE);
edge = MacroEnergy.get_component_by_fieldname(thermal_plant, :elec_edge);
```

### `time_interval`
Retrieves the time interval of a vertex/edge.
```@repl utils
MacroEnergy.time_interval(vertex)
MacroEnergy.time_interval(edge)
```

### `period_map`
Retrieves the period map of a vertex/edge.
```@repl utils
MacroEnergy.subperiod_map(vertex)
```

### `modeled_subperiods`
Retrieves the modeled subperiods of a vertex/edge.
```@repl utils
MacroEnergy.modeled_subperiods(vertex)
```

### `current_subperiod`
Retrieves the subperiod a given time step belongs to for the time series attached to a given vertex/edge.

```@repl utils
MacroEnergy.current_subperiod(vertex, 7)
```

### `subperiods`
Retrieves the subperiods of the time series attached to a vertex/edge.
```@repl utils
MacroEnergy.subperiods(vertex)
```

### `subperiod_indices`
Retrieves the indices of the subperiods of the time series attached to a vertex/edge.
```@repl utils
MacroEnergy.subperiod_indices(vertex)
```

### `get_subperiod`
Retrieves the subperiod of a vertex/edge for a given index.
```@repl utils
MacroEnergy.get_subperiod(vertex, 2)
```

### `subperiod_weight`
Retrieves the weight of a subperiod of a vertex/edge for a given index.
```@repl utils
MacroEnergy.subperiod_weight(vertex, 2)
```

## Results Collection and Writing

### [`reshape_wide`](@ref)
Reshapes the results to wide format.
```@repl utils
capacity_results = MacroEnergy.get_optimal_capacity(system; scaling=1e3);
new_capacity_results = MacroEnergy.get_optimal_new_capacity(system; scaling=1e3);
retired_capacity_results = MacroEnergy.get_optimal_retired_capacity(system; scaling=1e3);
all_capacity_results = vcat(capacity_results, new_capacity_results, retired_capacity_results);
df_wide = MacroEnergy.reshape_wide(all_capacity_results);
df_wide[1:5, [:commodity, :resource_id, :capacity, :new_capacity, :retired_capacity]]
```

### [`write_flow`](@ref)
Writes the flow results to a (CSV, CSV.GZ, or Parquet) file. An optional `commodity` and `asset` type filter can be applied.
```julia
julia> write_flow("flow.csv", system)
# Filter by commodity: write only the flow of edges of commodity "Electricity"
julia> write_flow("flow.csv", system, commodity="Electricity")
# Filter by commodity and asset type using parameter-free matching
julia> write_flow("flow.csv", system, commodity="Electricity", asset_type="ThermalPower")
# Filter by commodity and asset type using wildcard matching
julia> write_flow("flow.csv", system, commodity="Electricity", asset_type="ThermalPower*")
```

### [`write_capacity`](@ref)
Writes the capacity results to a (CSV, CSV.GZ, or Parquet) file. An optional `commodity` and `asset` type filter can be applied.
```julia
julia> write_capacity("capacity.csv", system)
# Filter by commodity: write only the capacity of edges of commodity "Electricity"
julia> write_capacity("capacity.csv", system, commodity="Electricity")
# Filter by commodity and asset type using parameter-free matching
julia> write_capacity("capacity.csv", system, asset_type="ThermalPower")
# Filter by asset type using wildcard matching
julia> write_capacity("capacity.csv", system, asset_type="ThermalPower*")
# Filter by commodity and asset type
julia> write_capacity("capacity.csv", system, commodity="Electricity", asset_type=["ThermalPower", "Battery"])
```

### [`write_costs`](@ref)

Writes the costs results to a (CSV, CSV.GZ, or Parquet) file. An optional `type` filter can be applied.

```julia
julia> write_costs("costs.csv", system, model)
```

### [`write_settings`](@ref)

```julia
julia> write_settings(case, "settings.json")
```
This function exports case and system settings to a JSON file, useful for debugging and documentation.

### [`write_results`](@ref)

!!! warning "write_results is a legacy function"
    The `write_results` function is part of the legacy unified output system. For new code, consider using the specialized output functions instead.

```julia
julia> write_results(file_path, system, model, settings, ext=".csv.gz")
julia> write_results(file_path, system, model, settings, ext=".parquet")
```

This function creates multiple output files, one for each result type:
- `file_path_capacity.ext` - Capacity results
- `file_path_flow.ext` - Flow results
- `file_path_non_served_demand.ext` - Non-served demand
- `file_path_storage_level.ext` - Storage levels
- `file_path_discounted_costs.ext` - Discounted costs
- `file_path_undiscounted_costs.ext` - Undiscounted costs

```@meta
DocTestSetup = nothing
```