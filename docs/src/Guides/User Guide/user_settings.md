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

Macro checks all the settings before it stops, and lists every invalid setting in one error, with its full name:

```
InputValidationError: 2 invalid inputs:
  case_settings: unknown key(s) ConstraintScalling. Valid keys are: PeriodLengths, DiscountRate, ...
  case_settings.DiscountRate: expected a number ≥ 0, got -0.05
```

JSON has no comments, so keys starting with `#` are treated as comments and ignored, at any level of the file:

```json
{
    "PeriodLengths": [10, 10],
    "#PeriodLengths": "the two periods start in 2030 and 2040"
}
```

For a complete list of available settings, their default values, and detailed descriptions, please refer to the [Inputs](@ref) section.

## Updating older cases

Earlier versions of Macro split the settings between two files:

- `settings/case_settings.json` held the settings of the whole case, such as `PeriodLengths`, `DiscountRate`, `SolutionAlgorithm` and `WriteFullTimeseries`.
- `settings/macro_settings.json`, referenced by the `settings` entry of each period, held everything else, such as `ConstraintScaling`, `AutoCreateNodes` and the output settings.

Cases written that way still load, as long as every period has the same settings and they do not contradict `case_settings.json`. Until you update the case, loading it logs two warnings: one about the per-period settings, and one listing each old name that was translated.

To update a case:

1. Move the contents of `macro_settings.json` into `case_settings.json`, and delete `macro_settings.json`.
2. Rename the old names, using the table at the end of this section. The output settings now go in an `OutputSettings` block.
3. Delete the `settings` entry of each period in `system_data.json`. You can keep the top-level entry, or delete it too: without it, Macro reads `settings/case_settings.json`.

`MacroEnergy.migrate_settings` can do these steps for you. It reads the settings as `load_case` does, and writes only the settings the case sets, under their new names. By default it is a dry run, which only shows the changes:

```julia
using MacroEnergy
MacroEnergy.migrate_settings("path/to/case")                  # show the changes
MacroEnergy.migrate_settings("path/to/case"; dry_run=false)   # make them
```

It also replaces the deprecated `"SolutionAlgorithm": "Myopic"` with `"SolutionAlgorithm": "Monolithic"` and `"ExpansionHorizon": "Myopic"`.

To check the update, the report has a table of the settings that are not at their default, before and after: the file each one is in, its name there, and its value. Settings whose value changes come first, in a table of their own. After a real update, the settings are read back from the files for this table. For the example below, the dry run shows:

```
The settings that are not at their default, now and as they will be after the update. After it, they will all be in settings/case_settings.json.
┌─────────────────────────────────────┬──────────────────────────────┬──────────────────────────┬──────────┬──────────┐
│ Setting                             │ Before: file                 │ Before: name             │ Before   │ After    │
├─────────────────────────────────────┼──────────────────────────────┼──────────────────────────┼──────────┼──────────┤
│ PeriodLengths                       │ settings/case_settings.json  │ PeriodLengths            │ [5,5]    │ [5,5]    │
│ DiscountRate                        │ settings/case_settings.json  │ DiscountRate             │ 0.045    │ 0.045    │
│ ConstraintScaling                   │ settings/macro_settings.json │ ConstraintScaling        │ true     │ true     │
│ AutoCreateNodes                     │ settings/macro_settings.json │ AutoCreateNodes          │ true     │ true     │
│ OutputSettings.Overwrite            │ settings/macro_settings.json │ OverwriteResults         │ true     │ true     │
│ OutputSettings.Format               │ settings/macro_settings.json │ OutputFormat             │ "csv.gz" │ "csv.gz" │
│ OutputSettings.Layout.Capacity      │ settings/macro_settings.json │ OutputLayout.Capacity    │ "wide"   │ "wide"   │
│ OutputSettings.Write.Curtailment    │ settings/macro_settings.json │ WriteOutputs.Curtailment │ false    │ false    │
│ OutputSettings.Write.FullTimeseries │ settings/case_settings.json  │ WriteFullTimeseries      │ true     │ true     │
└─────────────────────────────────────┴──────────────────────────────┴──────────────────────────┴──────────┴──────────┘
All of them keep their values.
Settings that are not listed are at their default. To see the defaults, run MacroEnergy.default_settings().
```

Settings that are not listed are at their default, such as `"OutputDir": "results"` and `"OutputLayout": {"Flow": "long"}` here. `MacroEnergy.default_settings()` returns every default, and they are also listed in [Inputs](@ref). The table at the end of this section shows where each setting of earlier versions goes.

It does not delete the old settings files: it lists the ones that are no longer used. Comments (keys starting with `#`) are not carried over, and rewriting `system_data.json` may change its formatting.

It only changes files inside the case folder. If the top-level `settings` entry of `system_data.json` points to a file outside the folder, which other cases may use too, it stops with an error. Copy that file into the case, point the entry to the copy, and run it again.

### Example

Here is a multi-period case written for an earlier version.

**Before:** `settings/case_settings.json`

```json
{
    "SolutionAlgorithm": "Monolithic",
    "PeriodLengths": [5, 5],
    "DiscountRate": 0.045,
    "WriteFullTimeseries": true
}
```

**Before:** `settings/macro_settings.json`

```json
{
    "ConstraintScaling": true,
    "AutoCreateNodes": true,
    "OverwriteResults": true,
    "OutputDir": "results",
    "OutputFormat": "csv.gz",
    "OutputLayout": {"Capacity": "wide", "Flow": "long"},
    "WriteOutputs": {"Curtailment": false}
}
```

**Before:** `system_data.json`, where `...` stands for the other inputs of each period

```json
{
    "settings": {"path": "settings/case_settings.json"},
    "case": [
        {
            "settings": {"path": "settings/macro_settings.json"},
            ...
        },
        {
            "settings": {"path": "settings/macro_settings.json"},
            ...
        }
    ]
}
```

**After:** `settings/case_settings.json` holds every setting. The output settings, including `WriteFullTimeseries` from the old `case_settings.json`, are in `OutputSettings`:

```json
{
    "SolutionAlgorithm": "Monolithic",
    "PeriodLengths": [5, 5],
    "DiscountRate": 0.045,
    "ConstraintScaling": true,
    "AutoCreateNodes": true,
    "OutputSettings": {
        "Dir": "results",
        "Overwrite": true,
        "Format": "csv.gz",
        "Layout": {"Capacity": "wide", "Flow": "long"},
        "Write": {"Curtailment": false, "FullTimeseries": true}
    }
}
```

**After:** `system_data.json`, with no `settings` entry in the periods

```json
{
    "settings": {"path": "settings/case_settings.json"},
    "case": [
        {
            ...
        },
        {
            ...
        }
    ]
}
```

`macro_settings.json` is no longer needed. `BendersSettings` and `MyopicSettings` stay in `case_settings.json`, and `settings/benders_settings.json` still works.

A single-period case written without a `case` key has one `settings` entry, at the top of `system_data.json`, pointing to `macro_settings.json`. Point it to `settings/case_settings.json` instead, or delete it.

### Periods with different settings

Every period now uses the same settings. If the periods of a case pointed to different `macro_settings.json` files whose settings differ, for example to write different outputs in different periods, loading the case is an error that names the period and the first setting that differs. Choose one set of settings for the whole case.

### Julia code

`case.settings` and the `settings` of every `System` in a case are now the same object. They cannot be changed once the case is loaded: assigning `system.settings` is an error. To change a setting, change `case_settings.json` and load the case again. Read the output settings from `OutputSettings`, for example `system.settings.OutputSettings.Dir` instead of `system.settings.OutputDir`. Reading an old name is an error.

### Where each setting goes

Every setting of the earlier versions now goes in `case_settings.json`. Most keep their name, and the output settings move into `OutputSettings`:

| Setting | Was in | Now in `case_settings.json` |
|---|---|---|
| `PeriodLengths` | `case_settings.json` | `PeriodLengths` |
| `DiscountRate` | `case_settings.json` | `DiscountRate` |
| `StartYear` | `case_settings.json` | `StartYear` |
| `SolutionAlgorithm` | `case_settings.json` | `SolutionAlgorithm` |
| `ExpansionHorizon` | `case_settings.json` | `ExpansionHorizon` |
| `ParameterScaling` | `case_settings.json` | `ParameterScaling` |
| `ParameterScalingFactor` | `case_settings.json` | `ParameterScalingFactor` |
| `BendersSettings` | `case_settings.json` | `BendersSettings` |
| `MyopicSettings` | `case_settings.json` | `MyopicSettings` |
| `WriteFullTimeseries` | `case_settings.json` | `OutputSettings.Write.FullTimeseries` |
| `ConstraintScaling` | `macro_settings.json` | `ConstraintScaling` |
| `EnableJuMPDirectModel` | `macro_settings.json` | `EnableJuMPDirectModel` |
| `EnableJuMPStringNames` | `macro_settings.json` | `EnableJuMPStringNames` |
| `AllowImplicitTopLevelCommodities` | `macro_settings.json` | `AllowImplicitTopLevelCommodities` |
| `WriteSubcommodities` | `macro_settings.json` | `WriteSubcommodities` |
| `AutoCreateNodes` | `macro_settings.json` | `AutoCreateNodes` |
| `AutoCreateLocations` | `macro_settings.json` | `AutoCreateLocations` |
| `Retrofitting` | `macro_settings.json` | `Retrofitting` |
| `OutputDir` | `macro_settings.json` | `OutputSettings.Dir` |
| `OverwriteResults` | `macro_settings.json` | `OutputSettings.Overwrite` |
| `OutputFormat` | `macro_settings.json` | `OutputSettings.Format` |
| `OutputLayout` | `macro_settings.json` | `OutputSettings.Layout` |
| `WriteOutputs` | `macro_settings.json` | `OutputSettings.Write` |
| `OutputSignificantDigits` | `macro_settings.json` | `OutputSettings.SignificantDigits` |
| `OutputAssetTags` | `macro_settings.json` | `OutputSettings.AssetTags` |
| `DualExportsEnabled` | `macro_settings.json` | `OutputSettings.Write.Duals` |

The old names still work, with a deprecation warning. Setting an old name and its new name to different values is an error, unless the old name is at its default: older versions wrote every default into new cases, so an old name at its default is ignored next to the new name.
