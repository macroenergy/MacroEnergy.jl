# [Writing Results to Files](@id user-write-results)

Currently, Macro supports the following types of outputs:

- [Capacity Results](@ref): final capacity, new capacity and retired capacity for each technology.
- [Costs](@ref): fixed, variable and total system costs.
- [Curtailment Results](@ref): curtailment of variable renewable energy (VRE) assets over time.
- [Flow Results](@ref): flow for each commodity through each edge in the system.
- [Non-Served Demand Results](@ref): non-served demand for each node with demand.
- [Storage Level Results](@ref): storage level for each storage unit over time.
- [Time Weights](@ref time_weights_results): timestep-to-weight mapping for annualization when using time-domain reduction (TDR).
- [Full Time Series Reconstruction](@ref full_time_series_reconstruction): expand representative-period results back to the full modeled year when using TDR.

For detailed information about output formats and layouts, please refer to the [Output Format](@ref) and [Output Files Layout](@ref) sections below.

!!! note "Output Files Location"
    By default, output files are written to a `results` directory created in the same location as your input data. For more details about output file locations, see the [Output Files Location](@ref) section below.

## Capacity Results
To export system-level capacity results to a file, users can use the [`write_capacity`](@ref) function:

```julia
write_capacity("capacity.csv", system)
```

This function exports capacity results for all commodities and asset types defined in your case inputs. 

You can filter the results by commodity, asset type, or both using the `commodity` and `asset_type` parameters:

```julia
# Filter results by commodity
write_capacity("capacity.csv", system, commodity="Electricity")
# Filter results by asset type
write_capacity("capacity.csv", system, asset_type="ThermalPower")
# Filter results by commodity and asset type
write_capacity("capacity.csv", system, commodity="Electricity", asset_type=["VRE", "Battery"])
```

The `*` wildcard character enables pattern matching for asset types. For example, the following command exports results for all asset types beginning with `ThermalPower` (e.g., `ThermalPower`, `ThermalPowerCCS`):

```julia
# Filter using wildcard matching for asset types
write_capacity("capacity.csv", system, commodity="Electricity", asset_type="ThermalPower*")
```

Similarly, you can use wildcard matching for commodities:

```julia
# Filter using wildcard matching for commodities
write_capacity("capacity.csv", system, commodity="CO2*")
```

!!! note "Output Layout"
    Results are written in *long* format by default. To use *wide* format, configure the `OutputLayout: {"Capacity": "wide"}` setting in your Macro settings JSON file (see [Output Files Layout](@ref) for details).

## Curtailment Results

Export curtailment results for variable renewable energy (VRE) assets using the [`write_curtailment`](@ref) function:

```julia
write_curtailment("curtailment.csv", system)
```

Curtailment is the difference between available VRE generation (capacity × availability factor) and actual generation (flow). It represents energy that could have been produced but was not dispatched.

!!! note "Output Layout"
    Results are written in *long* format by default. To use *wide* format, configure the `OutputLayout: {"Curtailment": "wide"}` setting in your Macro settings JSON file (see [Output Files Layout](@ref) for details).

## Costs

Export system-wide cost results using the [`write_costs`](@ref) function:

```julia
write_costs("costs.csv", system, model)
```

Note that the `write_costs` function requires both the `system` and `model` arguments, unlike the `write_capacity` function.

To export undiscounted costs (fixed, variable, total) instead of discounted costs, use [`write_undiscounted_costs`](@ref):

```julia
write_undiscounted_costs("undiscounted_costs.csv", system, model)
```

For a detailed cost breakdown by category (Investment, FixedOM, VariableOM, Fuel, NonServedDemand, etc.) and by asset type or zone, use [`write_detailed_costs`](@ref). This writes both discounted and undiscounted breakdown files:

```julia
write_detailed_costs(results_dir, system, model, settings)
```

To obtain detailed costs as DataFrames for programmatic use, use [`get_detailed_costs`](@ref):

```julia
costs = get_detailed_costs(system, settings)
# costs.discounted and costs.undiscounted are DataFrames with columns: zone, type, category, value
```

!!! note "Output Layout"
    Results are written in *long* format by default. To use *wide* format, configure the `OutputLayout: {"Costs": "wide"}` setting in your Macro settings JSON file (see [Output Files Layout](@ref) for details).

## Flow Results

Export system-level flow results using the [`write_flow`](@ref) function:

```julia
write_flow("flows.csv", system)
```

Filter results by commodity, asset type, or both using the `commodity` and `asset_type` parameters:

```julia
# Filter by commodity
write_flow("flows.csv", system, commodity="Electricity")

# Filter by asset type using parameter-free matching
write_flow("flows.csv", system, asset_type="ThermalPower")

# Filter by asset type using wildcard matching
write_flow("flows.csv", system, asset_type="ThermalPower*")
```

!!! note "Output Layout"
    Results are written in *long* format by default. To use *wide* format, configure the `OutputLayout: {"Flow": "wide"}` setting in your Macro settings JSON file (see [Output Files Layout](@ref) for details).

## Non-Served Demand Results

Export non-served demand results for all nodes with demand using the [`write_non_served_demand`](@ref) function:

```julia
write_non_served_demand("non_served_demand.csv", system)
```

This function exports non-served demand values only for nodes that have non-served demand variables defined (i.e., nodes with `max_nsd != [0.0]` in the input data). 

!!! note "Segment Handling"
    Non-served demand can have multiple segments (for piecewise linear cost curves). In *long* format, the `segment` column indicates which segment each value belongs to. In *wide* format, compound column names are used: `{node_id}_seg{segment}` (e.g., `elec_SE_seg1`, `elec_SE_seg2`).

!!! note "Output Layout"
    Results are written in *long* format by default. To use *wide* format, configure the `OutputLayout: {"NonServedDemand": "wide"}` setting in your Macro settings JSON file (see [Output Files Layout](@ref) for details).

## Storage Level Results

Export storage level results for all storage units using the [`write_storage_level`](@ref) function:

```julia
write_storage_level("storage_level.csv", system)
```

Filter results by commodity or asset type using the `commodity` and `asset_type` parameters:

```julia
# Filter by commodity
write_storage_level("storage_level.csv", system, commodity="Electricity")

# Filter by asset type
write_storage_level("storage_level.csv", system, asset_type="Battery")
```

!!! note "Output Layout"
    Results are written in *long* format by default. To use *wide* format, configure the `OutputLayout: {"StorageLevel": "wide"}` setting in your Macro settings JSON file (see [Output Files Layout](@ref) for details).

## [Time Weights](@id time_weights_results)

When using time-domain reduction (TDR), export the timestep-to-weight mapping using the [`write_time_weights`](@ref) function:

```julia
write_time_weights("time_weights.csv", system)
```

The CSV maps every optimization timestep to its representative sub-period index and the corresponding sub-period weight. This is needed for downstream post-processing — energy revenue, capacity factor calculations, and any other weighted annual sums require knowing each timestep's weight. Weights are normalized so that `Σ_k weight(k) × hours_per_subperiod(k) = TotalHoursModeled`, for each representative sub-period `k`. Without TDR, every timestep receives weight 1.0, unless `TotalHoursModeled` differs from the sum of timestep durations in the model (e.g., partial-year or leap-year), in which case the same normalization applies.

Output columns: 
- `time`: 1-based timestep index
- `subperiod_index`: index of the representative sub-period that the timestep belongs to
- `weight`: weight of the representative sub-period (hours it represents in the full year)

## [Full Time Series Reconstruction](@id full_time_series_reconstruction)

When using time-domain reduction (TDR), the optimization model runs on a reduced set of representative sub-periods (e.g., 3 representative weeks of 168 hours each instead of a full year of 8760 hours). The full time series reconstruction feature expands the optimized results back to the full `TotalHoursModeled` hours using the sub-period map (`Period_map.csv`).

### Enabling Full Time Series Output

Set the `WriteFullTimeseries` option to `true` in your `case_settings.json`:

```json
{
  "WriteFullTimeseries": true
}
```

When enabled, the following time-series outputs are reconstructed and written to a `full_time_series/` subdirectory inside the results directory:

| File | Description |
|------|-------------|
| `flows.csv` | Commodity flow through each edge |
| `non_served_demand.csv` | Non-served demand for each node |
| `storage_level.csv` | Storage state for each storage unit |
| `curtailment.csv` | VRE curtailment |
| `balance_duals.csv` | Balance constraint duals (only when `DualExportsEnabled` is also `true`) |

Each file contains one row per hour for the full modeled year (e.g., 8760 rows), with the same column structure as the corresponding representative-period output file.

### How Reconstruction Works

The reconstruction uses the `Period_map.csv` file (in the `system/` folder) to map each calendar sub-period to its representative sub-period. For example, if the period map assigns weeks 1, 2, and 4 to representative week 1, then the optimized values for representative week 1 are copied into the full time series at positions corresponding to weeks 1, 2, and 4.

If the period map covers fewer hours than `TotalHoursModeled` (e.g., 52 × 168 = 8736 < 8760), the remaining hours are padded by repeating values from the representative period that corresponds to the last calendar sub-period.

### Calling Directly

You can also call the reconstruction function directly after solving:

```julia
write_full_timeseries(results_dir, system)
```

This writes all four time-series files to `results_dir/full_time_series/`. The function checks whether TDR is active and skips silently if no time-domain reduction is detected.

To check whether a system uses TDR:

```julia
has_tdr(system)  # returns true if the system uses time-domain reduction
```

!!! note "Output Layout and Compression"
    Full time series files follow the same `OutputLayout` setting as other outputs. In *long* format, files are written as compressed `.csv.gz` to reduce disk usage (a full-year long-format file can be very large). In *wide* format, files are written as plain `.csv`.

!!! note "Solution Algorithms"
    Full time series reconstruction is supported for all solution algorithms: Monolithic, Myopic, and Benders decomposition. When `WriteFullTimeseries` is enabled, reconstruction happens automatically as part of `write_outputs`.

## Writing Case Settings

To export case and system settings to a JSON file, use the [`write_settings`](@ref) function:

```julia
write_settings(case, "output/settings.json")
```

This function automatically writes:
- Case-level settings
- System-level settings for all systems in the case

The settings file is useful for:
- Documentation and reproducibility
- Sharing configuration with other users
- Debugging and troubleshooting

!!! note "Automatic Settings Writing"
    The `write_settings` function is automatically called when using the main output writing functions (`write_outputs`) for different solution algorithms (Monolithic, Myopic, Benders).

## Output Format

Macro supports multiple output formats to suit different needs:

- **CSV**: Comma-separated values
  - Ideal for small datasets and human-readable output
  - Directly compatible with spreadsheet software
  - Less efficient for large datasets
- **CSV.GZ**: Compressed CSV
  - Balances readability and file size
  - Reduces storage requirements while maintaining CSV format
  - Requires decompression for reading
- **Parquet**: Column-based data store
  - Optimal for large datasets
  - Superior compression and faster read/write operations
  - Requires specialized tools for reading

The output format is determined by the file extension. For example, to export results in Parquet format:

```julia
write_capacity("results.parquet", system)
write_costs("results.parquet", system, model)
write_flow("results.parquet", system)
```

## Output Files Layout

By default, all results are written in *long* format for optimal storage efficiency and performance, particularly for large systems. The *wide* format is also available for easier reading and visualization.

Configure the output layout using the `OutputLayout` setting in your Macro settings JSON file:

```json
{
  "OutputLayout": "wide"
}
```

or

```json
{
  "OutputLayout": {
    "Capacity": "wide",
    "Costs": "long",
    "Curtailment": "long",
    "Flow": "long",
    "NonServedDemand": "long",
    "StorageLevel": "wide"
  }
}
```

Available options:
- `"OutputLayout": "long"` (applies to all outputs)
- `"OutputLayout": "wide"` (applies to all outputs)
- `"OutputLayout": {"Capacity": "wide", "Costs": "long", "Curtailment": "long", "Flow": "long", "NonServedDemand": "long", "StorageLevel": "wide"}` (individual layout settings)

## Output Files Location

Macro provides two settings to control output file locations:
- `OutputDir`: Specifies the output directory name
- `OverwriteResults`: Controls whether to overwrite existing files

For example:

```json
{
  "OutputDir": "results",
  "OverwriteResults": true
}
```

Users can obtain the output directory path programmatically using the [`create_output_path`](@ref) function:

```julia
output_path = create_output_path(system)
```

and then pass this path to the write functions:

```julia
write_capacity(joinpath(output_path, "capacity.csv"), system)
```

By default, the `create_output_path` function creates a `results` directory in the same location as your input data (i.e., the directory containing `system_data.json`). For more information about the input folder structure, refer to the [Creating a new System](@ref) guide.

If `OverwriteResults` is `true`, existing files will be overwritten. Otherwise, the function appends a number to the directory name to prevent overwriting.

Users can specify a custom base path for the output directory:

```julia
output_path = create_output_path(system, "path/to/output")
write_capacity(joinpath(output_path, "capacity.csv"), system) # Creates /path/to/output/results/capacity.csv
```

In this case, the function creates a directory named according to the `OutputDir` setting (e.g., `results`) within your specified path (e.g., `path/to/output/results`).

## Exporting System Data to JSON

To serialize a solved `System` or `Case` object back to a JSON file, use the [`write_to_json`](@ref) function. This is useful for saving the full system state — including all asset parameters, solved variable values, and constraint duals — so it can be inspected or reloaded later.

### Writing a single system

```julia
write_to_json(system, "output/system_data.json")
```

### Writing a full case (all periods + settings)

```julia
write_to_json(case, "output/case_data.json")
```

When writing a `Case`, the output contains two top-level keys:
- `case`: an array of per-period system data objects
- `settings`: the case-level settings

### Compression

By default, output is gzip-compressed. If the provided file path does not end in `.gz`, the extension is appended automatically:

```julia
# Both of these write to output/case_data.json.gz
write_to_json(case, "output/case_data.json")
write_to_json(case, "output/case_data.json.gz")
```

To write uncompressed JSON, pass `compress=false`:

```julia
write_to_json(case, "output/case_data.json"; compress=false)
```

If `file_path` is omitted entirely, the output is written to `output_system_data.json` (or `.gz`) in the current working directory.
