# Adding a Location to a System

You can define a Location and its commodity Nodes together in `locations.json` using a `commodities` object:

```json
{
  "locations": [
    {
      "id": "SE",
      "commodities": {
        "Hydrogen": {},
        "Electricity": {"id": "elec_SE", "demand": [100.0]}
      }
    }
  ]
}
```

Each commodity must be defined in the system. Empty node details use the existing node defaults, including a balance constraint. Without an explicit node ID, Macro generates `<location>_<commodity>` (here, `SE_Hydrogen`). The parent supplies location membership. Details can contain the same demand, supply, time series and constraints as independent node inputs. See [Defining Commodity Nodes Within a Location](@ref) for details.

These explicit nodes are created even when `AutoCreateNodes` is false. You can combine this format with `nodes.json`, but node IDs must be unique and each location can contain only one node of a given commodity. Repeated location IDs are errors.

Alternatively, keep the Nodes in `nodes.json` and assign them to Locations in two steps:

1. Add the new Location to the list of Locations
2. Tag any Nodes you wish to assign to the Location

## Adding the Location to the Location list

The Location list is a JSON file containing an array of unique Location names or objects. A name string is shorthand for an object with only an `id` field.

The most straightforward way of adding a new Location is to use the template functions.

You can add one or more Locations by providing the Location file as an argument. In this example, we will assume your have created a system called `ExampleSystems/template_example` and that you have created an `assets` folder in that directory.

```julia
julia> template_location("ExampleSystems/template_example/system/locations.json", "Boston")
julia> template_location("ExampleSystems/template_example/system/locations.json", ["Boston", "NYC", "Princeton"])
```

Or by providing the associated System:

```julia
julia> template_location(system, ["Boston", "NYC", "Princeton"])
```

[You can learn how to create or load the System here.](@ref "Creating a new System")

With either approach, doing so will leave you with the following Locations file:

```json
{
    "locations": [
        "Boston",
        "NYC",
        "Princeton"
    ]
}
```

The template function avoids appending duplicate name strings. This differs from loading a file containing repeated location IDs, which throws an error. If we next call:

```julia
julia> template_location(system, ["Boston", "New London", "Princeton"])
```

Our locations file will be:

```json
{
    "locations": [
        "Boston",
        "NYC",
        "Princeton",
        "New London"
    ]
}
```

Alternatively, you can directly add names to the locations.json file. However, in the future, the template functions will take care of additional steps so we recommend using them whenever possible.

## Adding Nodes to a Location

The next step is to let Macro know which Nodes are part of your new Location.  

In your Nodes file (at `system/nodes.json` by default), add a "location" field to the instance data of each Node you would like to include, and the name of the Location. [You can find a guide on how to add a Node to a System here.](@ref "Adding a Node to a System")

For example, if you have a three-Location system and each Location requires an Electricity Node, you could add the following:

```json
{"nodes": [
    {
        "type": "Electricity",
        "global_data": {
            "time_interval": "Electricity",
            "max_nsd": [
                1
            ],
            "price_nsd": [
                5000.0
            ],
            "constraints": {
                "BalanceConstraint": true,
                "MaxNonServedDemandConstraint": true,
                "MaxNonServedDemandPerSegmentConstraint": true
            }
        },
        "instance_data": [
            {
                "id": "elec_SE",
                "location": "SE",
                "demand": {
                    "timeseries": {
                        "path": "system/demand.csv",
                        "header": "Demand_MW_z1"
                    }
                }
            },
            {
                "id": "elec_MIDAT",
                "location": "MIDAT",
                "demand": {
                    "timeseries": {
                        "path": "system/demand.csv",
                        "header": "Demand_MW_z2"
                    }
                }
            },
            {
                "id": "elec_NE",
                "location": "NE",
                "demand": {
                    "timeseries": {
                        "path": "system/demand.csv",
                        "header": "Demand_MW_z3"
                    }
                }
            }
        ]
    }
]}
```

The Location information must be added to the instance data, not the global data, as you can only have one Node of each Commodity at any given Location.

To distinguish multiple versions of a Commodity at one Location, use sub-Commodities, each of which can have its own Node.

[You can learn more about sub-Commodities here.](@ref "Creating a new sub-Commodity")

For example, if you wish to differentiate between high and low emission electricity, you could create two sub-Commodities: LowEmissElectricity, and HighEmissElectricity. Now, you can add Electricity, LowEmissElectricity, and HighEmissElectricity to a Location:

```json
{"nodes": [
    {
        "type": "Electricity",
        "instance_data": {
            "id": "elec_SE",
            "time_interval": "Electricity",
            "location": "SE",
            "demand": {
                "timeseries": {
                    "path": "system/demand.csv",
                    "header": "Demand_MW_z1"
                }
            }
        }
    },
    {
        "type": "LowEmissElectricity",
        "instance_data": {
            "id": "lowemisselec_SE",
            "time_interval": "LowEmissElectricity",
            "location": "SE",
            "demand": [0.0]
        }
    },
    {
        "type": "HighEmissElectricity",
        "instance_data": {
            "id": "highemisselec_SE",
            "time_interval": "HighEmissElectricity",
            "location": "SE",
            "demand": [0.0]
        }
    }
]}
```

As a reminder, sub-Commodities can flow into Nodes of the same type or one of their supertypes types. This means LowEmissElectricity can flow into LowEmissElectricity Nodes or Electricity Nodes. However, HighEmissElectricity and Electricity cannot flow into LowEmissElectricity Nodes.

Also, if you connect an Asset producing LowEmissElectricity to our new "SE" Location, it will be connected to the LowEmissElectricity Node. If you want the LowEmissElectricity to be able to meet the Electricity demand then you will have to specify that the Asset be connected to the "elec_SE" Node, or add an edge connecting the "lowemisselec_SE" and "elec_SE" Nodes.

## Important Settings for Locations

There are two important settings when using Locations in your System:

- AutoCreateLocations: default = true. When set to true, this feature will automatically create a new Location if Macro comes across a Node which is a assigned to a Location that does not exist. Macro will print an info statement to let the user know that the Location has been created and its name.

- AutoCreateNodes: default = false. When set to true, this feature creates a missing commodity Node during endpoint lookup within an existing Location. Its ID is `<location>_<commodity>`. Unlike explicitly declared commodity nodes, these automatically created Nodes have no demand, supply or constraints. An unknown endpoint ID throws an error; this setting does not create missing Locations.
