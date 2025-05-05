# Adding a Commodity to a System

In Macro, the production, transport, and consumption of energy and materials is described by flows of Commodities. To include Assets, Locations and/or Nodes which include one or more of these flows, you must add the relevant Commodities to your System.

## Adding a Commodity

The list of Commodities in your System is defined in your `system_data.json` file. By default, the Commodities list is defined in `system/commodities.json`. If you [created your System using the template functions](@ref "Creating a System"), then your Commodity list will include all of Macro's default Commodities:

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

There is almost no overhead to including Commodities which are not used by your System, so we recommend adding all of the default Commododities to your Commodities list. If you want to list all of the Commoditities available in Macro, use the following function:

```julia
julia> MacroEnergy.commodity_types()
```

## Creating a new sub-Commodity
