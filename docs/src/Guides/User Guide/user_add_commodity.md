# Adding a Commodity to a System

In Macro, the production, transport, and consumption of energy and materials is described by flows of Commodities. To include Assets, Locations and/or Nodes which include one or more of these flows, you must add the relevant Commodities to your System.

## Adding a Commodity

The file containing the list of Commodities in your System is defined in the System's `system_data.json` file. The default file is `system/commodities.json`. If you [created your System using the template functions](@ref "Creating a System"), then your Commodity list will include all of Macro's default Commodities:

```json
{
    "commodities": [
        "Electricity",
        "NaturalGas",
        "CO2",
        "Hydrogen",
        "CO2Captured",
        "Biomass",
        "Uranium",
        "LiquidFuels",
    ]
}
```

If you created your System from scratch, you will have to add the Commodities you require yourself. If preferred, you can add the list directly to your `system_data.json` file. In that case, it will look something like:

```json
{
    "commodities": [
        "Electricity",
        "NaturalGas",
        "CO2",
        "Hydrogen",
        "CO2Captured",
        "Biomass",
        "Uranium",
        "LiquidFuels",
    ],
    "locations": {
        "path": "system/locations.json"
    },
    "settings": {
        "path": "settings/macro_settings.json"
    },
    "assets": {
        "path": "assets"
    },
    "time_data": {
        "path": "system/time_data.json"
    },
    "nodes": {
        "path": "system/nodes.json"
    }
}
```

### Listing Macro Commodities

There is almost no overhead to including Commodities which are not used by your System, so we recommend adding all of the default Commodities to your Commodities list. If you want to see a list all of the Commodities available in Macro, call the following function in the REPL or a script:

```julia
julia> using MacroEnergy
julia> MacroEnergy.commodity_types()
```

### Specifying time data for Commodities

As well as being included in the Commodities list, each Commodity must be included in the System's time data file. This file is `system/time_data.json` by default.

The time data file defines the representative periods (aka subperiods) which Macro should use to build the System, as well as the time-discretization of the operating decisions for each Commodity.

The latter is determined by two field:

- HoursPerSubperiod: The number of hours in each representative period / subperiod.
- HoursPerTimeStep: The number of hours per operational time step in each representative period / subperiod.

For now, all Commodities must have the same HoursPerSubperiod. In the future we will allow this to vary.

The HoursPerTimeStep variable can be different for different Commodities. As an example of how this might be used, let's consider a System with Electricity and Natural Gas Commodities.

```json
{
    "commodities": [
        "Electricity",
        "NaturalGas"
    ]
}
```

The System is a one-year model, made up of ten week-long representative periods / subperiods. We want the Electricity decisions to be optimized hourly, to capture hourly variation in demand and renewable energy availability. However, we don't anticipate that the Natural Gas systems will need to vary operations as frequently. To reduce our Model size and decrease runtime, we limit Natural Gas operating decisions to every 12 hours.

Our time data file is then:

```json
{
    "HoursPerSubperiod": {
        "Electricity": 168,
        "NaturalGas": 168
    },
    "HoursPerTimeStep": {
        "Electricity": 1,
        "NaturalGas": 12
    },
    "TotalHoursModeled": 8760,
    "NumberOfSubperiods": 10,
    "SubPeriodMap": {
        "path": "system/Period_map.csv"
    }
}
```

Further details about time data files, including how period maps work, [can be found here.](@ref "Time Data")

## Creating a new sub-Commodity

There are many circumstances in which you may want to differentiate between two flows of the same Commodity. For example, you may want to differentiate between biofuels produced from wood vs. crops, or hydrogen produced by electrolysis vs. steam methane reforming. The easiest solution is usually to create sub-Commodities for each version of the Commodity you require.

[The manual contains more detail on how sub-Commodities function and examples of how you can use them.](@ref "Sub-Commodities")

Sub-Commodities are additional Commodities created specifically for your System, which inherit the time data and other properties of an existing Commodity. To create a new sub-Commodity, you must therefore tell Macro which Commodity (or existing sub-Commodity) it is inheriting from.

You can add sub-Commodities by manually editing your Commodities file. However, Macro also has template functions to do so which will also help catch errors.

To create sub-Commodities for electrolysis-produced vs.SMR-produced hydrogen, we will create two new sub-Commodities which inherit from the Hydrogen Commodity. First, we must make sure that our System includes the Hydrogen Commodity.

We'll create a new System using the `template_system` function. [This guide gives more details on how to create a System.](@ref "Creating a new System")

```julia
system = template_system("ExampleSystems/template_example")
```

The template will add all Commodities to the System, but we'll only consider Hydrogen for now:

```json
{
    "commodities": [
        "Hydrogen",
        ...
    ]
}
```

We next use the `template_subcommodity` to add our two new sub-Commodities, with Hydrogen as the base Commodity in both cases.

```julia
template_subcommodity("ExampleSystems/template_example/system/commodities.json", "ElectrolysisHydrogen", "Hydrogen")
template_subcommodity("ExampleSystems/template_example/system/commodities.json", "SMRHydrogen", "Hydrogen")
```

Your Commodity file should now look like this:

```json
{
    "commodities": [
        "Hydrogen",
        {
            "name": "ElectrolysisHydrogen",
            "acts_like": "Hydrogen"
        },
        {
            "name": "SMRHydrogen",
            "acts_like": "Hydrogen"
        },
        ...
    ]
}
```

Regular Commodities are always listed as strings in the Commodity file, while sub-Commodities are short dictionaries defining its name and super-Commmodity.

For now, Macro adds Commodities and sub-Commodities in the order they are listed in the Commodity file. You should make sure that new sub-Commodities are always listed after the Commodity they inherit from.

You can also have the `template_subcommodity` function target the System, rather than the Commodity file itself.

```julia
template_subcommodity(system, "ElectrolysisHydrogen", "Hydrogen")
template_subcommodity(system, "SMRHydrogen", "Hydrogen")
```

You can combine these two function calls using lists of arguments.

```julia
template_subcommodity(system, ["ElectrolysisHydrogen", "SMRHydrogen"], ["Hydrogen", "Hydrogen"])
```

If you only give one super-Commodity, Macro will assume that all new sub-Commodities should inherit from it.

```julia
template_subcommodity(system, ["ElectrolysisHydrogen", "SMRHydrogen"], "Hydrogen")
```

As mentioned, you can also have sub-Commodities inherit from other sub-Commodities:

```julia
template_subcommodity(system, ["HighEmissElectrolysisHydrogen", "LowEmissElectrolysisHydrogen"], "ElectrolysisHydrogen")
```

This will leave you with the following Commodity file:

```json
{
    "commodities": [
        "Hydrogen",
        {
            "name": "ElectrolysisHydrogen",
            "acts_like": "Hydrogen"
        },
        {
            "name": "SMRHydrogen",
            "acts_like": "Hydrogen"
        },
        {
            "name": "HighEmissElectrolysisHydrogen",
            "acts_like": "ElectrolysisHydrogen"
        },
        {
            "name": "LowEmissElectrolysisHydrogen",
            "acts_like": "ElectrolysisHydrogen"
        },
        ...
    ]
}
```