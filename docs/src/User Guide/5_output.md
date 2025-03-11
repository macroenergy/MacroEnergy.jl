# Macro Output

Macro provides functionality to access and export optimization results. Results can be accessed in memory as `DataFrames` or written directly to files for further analysis.

Currently, Macro supports the following types of outputs:

- [Capacity Results](@ref): final capacity, new capacity, retired capacity for each technology
- [Costs](@ref): total, fixed, variable and total costs for the system
- [Flow Results](@ref): flow for each commodity through each edge
- **`Combined Results`**: all results (capacity, costs, flows, non-served demand, storage level) in a single DataFrame

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
results = collect_results(system, model)
write_dataframe("results.csv", results) # Write the dataframe to a CSV file
write_dataframe("results.parquet", results) # Write the dataframe to a Parquet file
```

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

As for the previous example, to write the results to a file, users can use the [`write_dataframe`](@ref) function:

```julia
write_dataframe("capacity.csv", capacity_results)
write_dataframe("new_capacity.csv", new_capacity_results)
write_dataframe("retired_capacity.csv", retired_capacity_results)
```

To facilitate this process, Macro provides the [`write_capacity_results`](@ref) function that writes **all** system-level capacity results directly to a file:

```julia
write_capacity_results("capacity.csv", system)
```

## Costs

System-wide cost results can be obtained as DataFrames using the [`get_optimal_costs`](@ref) function:

```julia
cost_results = get_optimal_costs(model)
write_dataframe("costs.csv", cost_results)
```

To write the costs results directly to a file, users can use the [`write_costs`](@ref) function:

```julia
write_costs("costs.csv", model)
```

## Flow Results

Flow results can be obtained either for the entire `system` or for specific `assets` using the [`get_optimal_flow`](@ref) function:

```julia
# System-level results
flow_results = get_optimal_flow(system)

# Asset-level results
flow_results = get_optimal_flow(asset)
```

To write system-level flow results directly to a file, users can use the [`write_flow_results`](@ref) function:

```julia
write_flow_results("flows.csv", system)
```