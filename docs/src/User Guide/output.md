# Macro Output

Macro provides functionality to access and export optimization results. Results can be accessed in memory as `DataFrames` or written directly to files for further analysis.

Currently, Macro supports the following types of outputs:

- [Capacity Results](@ref): final capacity, new capacity, retired capacity for each technology
- [Costs](@ref): total, fixed, variable and total costs for the system
- [Flow Results](@ref): flow for each commodity through each edge
- **`Combined Results`**: all results (capacity, costs, flows, non-served demand, storage level) in a single DataFrame

The default column names for the results in *long* format are:
- `commodity`: commodity type
- `commodity_subtype`: group identifier for the variables, i.e. `capacity`, `cost`, `flow`
- `zone`: zone id
- `resource_id`: resource id
- `component_id`: component id (e.g, edge id, storage id, etc.)
- `type`: type of the asset
- `variable`: unique identifier for the variable output (e.g, `capacity`, `new_capacity`, `retired_capacity`, `VariableCost`, `FixedCost`, `flow`)
- `value`: the value of the variable

!!! warning "Output Layout"
    When writing **capacity**, **costs**, and **flow** results, the user has the option to choose between two different layouts using the `OutputLayout` setting in the `macro_settings.json` file. The options are:
    - `"OutputLayout": "long"` (applies to all the three outputs)
    - `"OutputLayout": "wide"` (applies to all the three outputs)
    - `"OutputLayout": {"Capacity": "wide", "Costs": "long", "Flow": "long"}` (set the layout for each output individually)

    #### Capacity Results
    ##### Long Format
    ```julia
    commodity  commodity_subtype  zone    resource_id  component_id  type    variable  value
    Symbol     Symbol             Symbol  Symbol       Symbol        Symbol  Symbol    Float64
    ```
    Each **row** contains a single result specified by the `variable` column.

    ##### Wide Format
    ```julia
    commodity  commodity_subtype  zone    resource_id  component_id  type    variable  capacity  new_capacity  retired_capacity
    Symbol     Symbol             Symbol  Symbol       Symbol        Symbol  Symbol    Float64   Float64       Float64
    ```
    
    Each **row** contains a single `component_id`.

    #### Costs
    ##### Long Format
    ```julia
    commodity  commodity_subtype  zone    resource_id  component_id  type    variable  value
    Symbol     Symbol             Symbol  Symbol       Symbol        Symbol  Symbol    Float64
    ```

    Each **row** contains a single result specified by the `variable` column (e.g, `FixedCost`, `VariableCost`, `TotalCost`).
    
    ##### Wide Format
    ```julia
    FixedCost  VariableCost  TotalCost
    Float64    Float64       Float64
    ```
    Single row for each system.

    #### Flow Results
    ##### Long Format
    ```julia
    commodity  commodity_subtype  zone    resource_id  component_id  type    variable  value
    Symbol     Symbol             Symbol  Symbol       Symbol        Symbol  Symbol    Float64
    ```
    Each **row** contains a single result specified by the `variable` column (e.g, `flow`).

    ##### Wide Format
    ```julia
    time  component_id_1  component_id_2  ...
    Int64 Float64         Float64         ...
    1     100            200             ...
    2     101            201             ...
    ...
    ```
    Each **row** contains a single `time` step for each `component_id`.

## Quick Start

To collect and save all results at once, users can use the [`collect_results`](@ref) and [`write_results`](@ref) functions:

```julia
# Collect all results in memory and return a DataFrame
results = collect_results(system, model)

# Or collect and write directly to file
write_results("results.csv.gz", system, model)
```

!!! note "Output Format"
    Macro supports the following output formats:
    - **CSV**: comma-separated values
    - **CSV.GZ**: compressed CSV
    - **Parquet**: column-based data store

    The output format is determined by the file extension attached to the filename. For example, to write the results to a Parquet file instead of a CSV file, use the following line:

    ```julia
    write_results("results.parquet", system, model)
    ```


The function [`write_dataframe`](@ref) can be used to write a generic DataFrame to a file:

```julia
write_dataframe("results.csv", results) # Write the dataframe to a CSV file
write_dataframe("results.parquet", results) # Write the dataframe to a Parquet file
write_dataframe("results.csv", results, drop_cols=["commodity", "commodity_subtype"]) # Drop the commodity and commodity_subtype columns before writing to CSV
```

As can be seen in the example above, users have the option to drop columns from the DataFrame before writing the results to a file.

## Capacity Results

Results can be obtained either for the entire `system` or for specific `assets` using the [`get_optimal_capacity`](@ref), [`get_optimal_new_capacity`](@ref), and [`get_optimal_retired_capacity`](@ref) functions:

```julia
# System-level results
capacity_results = get_optimal_capacity(system)
new_capacity_results = get_optimal_new_capacity(system)
retired_capacity_results = get_optimal_retired_capacity(system)

# Asset-level results
capacity_results = get_optimal_capacity(asset)
new_capacity_results = get_optimal_new_capacity(asset)
retired_capacity_results = get_optimal_retired_capacity(asset)
```

To write system-level capacity results directly to a file, users can use the [`write_capacity`](@ref) function:

```julia
write_capacity("capacity.csv", system)
# Filter by commodity
write_capacity("capacity.csv", system, commodity="Electricity")
# Filter by asset type
write_capacity("capacity.csv", system, asset_type="ThermalPower")
# Filter by commodity and asset type
write_capacity("capacity.csv", system, commodity="Electricity", asset_type=["VRE", "Battery"])
# Filter by commodity and asset type using wildcard matching
write_capacity("capacity.csv", system, commodity="Electricity", asset_type="ThermalPower*")
# Drop columns
write_capacity("capacity.csv", system, drop_cols=["commodity", "commodity_subtype", "zone"])
```

By default, the results are written in *long* format. Users can also write the results in *wide* format by using the `OutputLayout` setting in the `macro_settings.json` file.
## Costs

System-wide cost results can be obtained as DataFrames using the [`get_optimal_costs`](@ref) function:

```julia
cost_results = get_optimal_costs(model)
write_dataframe("costs.csv", cost_results)
```

To write the costs results directly to a file, users can use the [`write_costs`](@ref) function:

```julia
write_costs("costs.csv", system, model)
write_costs("costs.csv", system, model, drop_cols=["commodity", "commodity_subtype", "zone"])
```

By default, the results are written in *long* format. Users can also write the results in *wide* format by using the `OutputLayout` setting in the `macro_settings.json` file.

## Flow Results

Flow results can be obtained either for the entire `system` or for specific `assets` using the [`get_optimal_flow`](@ref) function:

```julia
# System-level results
flow_results = get_optimal_flow(system)

# Asset-level results
flow_results = get_optimal_flow(asset)
```

To write system-level flow results directly to a file, users can use the [`write_flow`](@ref) function:

```julia
write_flow("flows.csv", system)
# Filter by commodity
write_flow("flows.csv", system, commodity="Electricity")
# Filter by asset type using parameter-free matching (ThermalPower{Fuel})
write_flow("flows.csv", system, asset_type="ThermalPower")
# Filter by asset type using wildcard matching (ThermalPower{Fuel} or ThermalPowerCCS{Fuel})
write_flow("flows.csv", system, asset_type="ThermalPower*")
# Drop columns
write_flow("flows.csv", system, drop_cols=["commodity", "commodity_subtype", "zone"])
```

By default, the results are written in *long* format. Users can also write the results in *wide* format by using the `OutputLayout` setting in the `macro_settings.json` file.
