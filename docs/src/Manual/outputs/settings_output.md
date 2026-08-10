# [Settings Output](@id manual-outputs-settings-output)

## Contents

[Overview](@ref "manual-outputs-settings-output-overview") | [Structure](@ref "manual-outputs-settings-output-structure") | [Assumptions](@ref "manual-outputs-settings-output-assumptions") | [Examples](@ref "manual-outputs-settings-output-examples") | [See Also](@ref "manual-outputs-settings-output-see-also")

## [Overview](@id manual-outputs-settings-output-overview)

**File:** `settings.json`

**Location:** Inside the outer results directory (e.g., `results_001/settings.json`), alongside the `results/` or `results_period_N/` subdirectories

`settings.json` is a snapshot of all case-level and system-level settings used for the model run. It is written automatically after every solve, regardless of other output settings.

This file serves as a reproducibility record: given the same input data and the `settings.json` file, you can reconstruct the exact settings used for any run. It is also useful for debugging, comparing runs, and sharing results with collaborators.

## [Structure](@id manual-outputs-settings-output-structure)

`settings.json` contains two top-level keys:

| Key | Description |
|---|---|
| `case_settings` | Settings from `case_settings.json` (solution algorithm, period lengths, discount rate, start year, full time series flag, etc.) |
| `system_settings` | Settings from `macro_settings.json` (output layout, dual exports, overwrite behavior, constraint scaling, etc.) |

The `system_settings` are written as JSON arrays (one entry per period for multi-period models, or a single entry for single-period models).

## [Assumptions](@id manual-outputs-settings-output-assumptions)

- **File location.** `settings.json` is written inside the **outer results directory** (e.g., `results_001/settings.json`), alongside the `results/` or `results_period_N/` subdirectories that contain the CSV output files. It is not written at the case root.

## [Examples](@id manual-outputs-settings-output-examples)

### Example `settings.json` (single-period model)

```json
{
    "case_settings": [
        {
            "SolutionAlgorithm": "Monolithic",
            "PeriodLengths": [1],
            "DiscountRate": 0.0,
            "WriteFullTimeseries": false
        }
    ],
    "system_settings": [
        {
            "OutputLayout": "long",
            "DualExportsEnabled": true,
            "OverwriteResults": false,
            "OutputDir": "results",
            "ConstraintScaling": false,
            "Retrofitting": false,
            "AutoCreateLocations": true,
            "AutoCreateNodes": false
        }
    ]
}
```

### Reading the Settings Snapshot

```julia
using JSON3

settings = JSON3.read("settings.json")
println("Solution algorithm: ", settings.case_settings.SolutionAlgorithm)
println("Output layout: ", settings.system_settings[1].OutputLayout)
```

## [See Also](@id manual-outputs-settings-output-see-also)

- [Outputs Overview](@ref "manual-outputs-overview") — overview of all output files and settings
- [Output Settings](@ref "manual-outputs-settings") — the full list of settings that affect outputs
- [Benders Convergence Output](@ref "manual-outputs-benders") — also written at the case root (Benders only)
