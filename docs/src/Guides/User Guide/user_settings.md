# Configuring Settings

Macro provides various settings that allow the user to customize model runs and control specific features. All of them are in one file, `settings/case_settings.json`, and they apply to every period of the case.

These are the steps to configure settings:

1. Create a `case_settings.json` file in a `settings` folder in the case directory.
2. Customize the JSON file to enable or disable features as needed.
3. Add the path to the settings JSON file in the `system_data.json` file. The user can use either a relative path (from the `system_data.json` location) or an absolute path. Without this entry, Macro reads `settings/case_settings.json` if it exists, and otherwise uses the default values.

!!! note "system_data.json"
    For more information about the `system_data.json` file, please see the [Inputs](@ref) section.

Here's an example of a `case_settings.json` file:

```json
{
    "SolutionAlgorithm": "Monolithic",
    "PeriodLengths": [10, 10],
    "DiscountRate": 0.05,
    "ConstraintScaling": true,
    "AllowImplicitTopLevelCommodities": true,
    "AutoCreateNodes": true,
    "OutputSettings": {
        "Overwrite": true,
        "Layout": {
            "Capacity": "wide",
            "Costs": "long",
            "Flow": "long"
        }
    }
}
```

The `system_data.json` file should include this entry at its top level:

```json
{
    "settings": {
        "path": "settings/case_settings.json"
    }
}
```

In this example, the user has enabled:
- two periods of ten years each, with costs discounted at 5%.
- scaling the constraints in the model during the optimization.
- allowing unknown plain commodity names to be created automatically as top-level commodities.
- creating nodes automatically from locations.
- overwriting the results folder if it already exists.
- setting the layout for the results files to "wide" for the capacity variables, and to "long" for costs and flow variables.

Settings that are not listed keep their default values. Unknown settings are an error, so a misspelled name cannot be silently ignored.

JSON has no comments, so keys starting with `#` are treated as comments and ignored, at any level of the file:

```json
{
    "PeriodLengths": [10, 10],
    "#PeriodLengths": "the two periods start in 2030 and 2040"
}
```

For a complete list of available settings, their default values, and detailed descriptions, please refer to the [Inputs](@ref) section.

## Updating older cases

Earlier versions of Macro used a second file, `macro_settings.json`, referenced by the `settings` entry of each period in `system_data.json`. Cases written that way still load, with a deprecation warning, as long as:

- every period has the same settings. Output settings can no longer vary between periods, and one period having settings while another has none is an error.
- they do not contradict `case_settings.json`.

To update a case, move the contents of `macro_settings.json` into `case_settings.json`, delete the `settings` entry of each period, and rename the output settings:

| Deprecated name | New name |
|---|---|
| `OutputDir` | `OutputSettings.Dir` |
| `OverwriteResults` | `OutputSettings.Overwrite` |
| `OutputFormat` | `OutputSettings.Format` |
| `OutputLayout` | `OutputSettings.Layout` |
| `WriteOutputs` | `OutputSettings.Write` |
| `WriteFullTimeseries` | `OutputSettings.Write.FullTimeseries` |
| `OutputSignificantDigits` | `OutputSettings.SignificantDigits` |
| `OutputAssetTags` | `OutputSettings.AssetTags` |
| `DualExportsEnabled` | `OutputSettings.Write.Duals` |

The old names still work, with a deprecation warning. Setting an old name and its new name to different values is an error.
