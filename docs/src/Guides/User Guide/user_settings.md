# Configuring Settings

Macro provides various settings that allow the user to customize model runs and control specific features.

These are the steps to configure settings:

1. Create a new settings JSON file (e.g., `macro_settings.json`) in the preferred location (we recommend creating a `settings` folder in the case directory).
2. Customize the JSON file to enable or disable features as needed.
3. Add the path to the settings JSON file in the `system_data.json` file. The user can use either a relative path (from the `system_data.json` location) or an absolute path.

!!! note "system_data.json"
    For more information about the `system_data.json` file, please see the [Inputs](@ref) section.

Here's an example of a `macro_settings.json` file:

```json
{
    "ConstraintScaling": true,
    "AllowImplicitTopLevelCommodities": true,
    "OverwriteResults": true,
    "AutoCreateNodes": true,
    "OutputLayout": {
        "Capacity": "wide",
        "Costs": "long",
        "Flow": "long"
  }
}
```

If the user created the `macro_settings.json` file in a `settings` folder, the `system_data.json` file should include this entry:

```json
{
    "settings": {
        "path": "settings/macro_settings.json"
    }
}
```

In this example, the user has enabled:
- scaling the constraints in the model during the optimization.
- allowing unknown plain commodity names to be created automatically as top-level commodities.
- overwriting the results folder if it already exists.
- creating nodes automatically from locations.
- setting the layout for the results files to "wide" for the capacity variables, and to "long" for costs and flow variables.

For a complete list of available settings, their default values, and detailed descriptions, please refer to the [Inputs](@ref) section.

