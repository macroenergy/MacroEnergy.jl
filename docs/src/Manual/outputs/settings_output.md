# [Settings Output](@id manual-outputs-settings-output)

## Contents

[Overview](@ref "manual-outputs-settings-output-overview") | [Structure](@ref "manual-outputs-settings-output-structure") | [Assumptions](@ref "manual-outputs-settings-output-assumptions") | [Examples](@ref "manual-outputs-settings-output-examples") | [See Also](@ref "manual-outputs-settings-output-see-also")

## [Overview](@id manual-outputs-settings-output-overview)

**File:** `settings.json`

**Location:** Inside the outer results directory (e.g., `results_001/settings.json`), alongside the `results/` or `results_period_N/` subdirectories

`settings.json` is a snapshot of all the settings used for the model run. It is written automatically after every solve, regardless of other output settings.

This file serves as a reproducibility record: given the same input data and the `settings.json` file, you can reconstruct the exact settings used for any run. It is also useful for debugging, comparing runs, and sharing results with collaborators.

## [Structure](@id manual-outputs-settings-output-structure)

`settings.json` contains all the settings of the run, in the same form as `case_settings.json` and with the default values filled in. The `Case` and every period of a multi-period model share these settings.

To rerun a case with the settings of an earlier run, copy that run's `settings.json` to `settings/case_settings.json`.

## [Assumptions](@id manual-outputs-settings-output-assumptions)

- **File location.** `settings.json` is written inside the **outer results directory** (e.g., `results_001/settings.json`), alongside the `results/` or `results_period_N/` subdirectories that contain the CSV output files. It is not written at the case root.

## [Examples](@id manual-outputs-settings-output-examples)

### Example `settings.json` (single-period model)

```json
{
    "PeriodLengths": [1],
    "DiscountRate": 0.0,
    "SolutionAlgorithm": "Monolithic",
    "ExpansionHorizon": "PerfectForesight",
    "ConstraintScaling": false,
    "Retrofitting": false,
    "AutoCreateLocations": true,
    "AutoCreateNodes": false,
    "OutputSettings": {
        "Dir": "results",
        "Overwrite": false,
        "Format": "csv",
        "Layout": "long",
        "Write": {},
        "SignificantDigits": null,
        "AssetTags": true
    }
}
```

### Reading the Settings Snapshot

```julia
using JSON3

settings = JSON3.read("settings.json")
println("Solution algorithm: ", settings.SolutionAlgorithm)
println("Output layout: ", settings.OutputSettings.Layout)
```

## [See Also](@id manual-outputs-settings-output-see-also)

- [Outputs Overview](@ref "manual-outputs-overview") — overview of all output files and settings
- [Output Settings](@ref "manual-outputs-settings") — the full list of settings that affect outputs
- [Benders Convergence Output](@ref "manual-outputs-benders") — also written at the case root (Benders only)
