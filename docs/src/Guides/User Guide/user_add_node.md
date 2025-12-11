# Adding a Node to a System

Adding a new Node to a System requires a few steps:

1. Add the new Node to the Nodes file
2. Give the Node a unique ID
3. Add data and constraints
4. (optionally) Add the Node to a Location

## Adding the Node to the Nodes file

The Nodes file is a JSON file containing an array of Nodes. Single Nodes should be defined by their Commodity (in the "type" field) and instance data. Nodes of the same Commodity with shared attributes can be described using global data.

As an example, this Node file (at `system/nodes.json`, by default) describes a Hydrogen Node, and three Electricity Nodes. The three Electricity Nodes have the same non-served demand (NSD) constraints and prices, so those elements are moved to the global data field to reduce duplicate data.

```json
{"nodes": [
    {
        "type": "Hydrogen",
        "instance_data": {
            "id": "single_h2_node",
            "time_interval": "Hydrogen",
            "location": "SE",
            "demand": {
                "timeseries": {
                    "path": "system/demand.csv",
                    "header": "H2_demand_se"
                }
            }
        }
    },
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

The most straightforward way of adding a new Node is to use the template functions.

You can add one or more Node by providing the Nodes file as an argument. In these examples, we will assume your have created a system called `ExampleSystems/template_example` and that you have created an `assets` folder in that directory.

```julia
julia> template_location("ExampleSystems/template_example/system/nodes.json", Electricity)
julia> template_location("ExampleSystems/template_example/system/nodes.json", [Electricity, Hydrogen])
```

Or by providing the associated System:

```julia
julia> template_location(system, [Electricity, Hydrogen])
```

[You can learn how to create or load the System here.](@ref "Creating a new System")

Each new Node will be added to the end of the existing Nodes in the Nodes file. For example, adding a new Hydrogen Node to the previous Nodes file will result in:

```json
{
    "nodes": [
        {
            "type": "Hydrogen",
            "instance_data": {
                "location": "SE",
                "id": "single_h2_node",
                "demand": {
                    "timeseries": {
                        "path": "system/demand.csv",
                        "header": "H2_demand_se"
                    }
                },
                "time_interval": "Hydrogen"
            }
        },
        {
            "global_data": {
                "constraints": {
                    "MaxNonServedDemandPerSegmentConstraint": true,
                    "MaxNonServedDemandConstraint": true,
                    "BalanceConstraint": true
                },
                "max_nsd": [
                    1
                ],
                "price_nsd": [
                    5000
                ],
                "time_interval": "Electricity"
            },
            "type": "Electricity",
            "instance_data": [
                {
                    "location": "SE",
                    "id": "elec_SE",
                    "demand": {
                        "timeseries": {
                            "path": "system/demand.csv",
                            "header": "Demand_MW_z1"
                        }
                    }
                },
                {
                    "location": "MIDAT",
                    "id": "elec_MIDAT",
                    "demand": {
                        "timeseries": {
                            "path": "system/demand.csv",
                            "header": "Demand_MW_z2"
                        }
                    }
                },
                {
                    "location": "NE",
                    "id": "elec_NE",
                    "demand": {
                        "timeseries": {
                            "path": "system/demand.csv",
                            "header": "Demand_MW_z3"
                        }
                    }
                }
            ]
        },
        {
            "type": "Hydrogen",
            "instance_data": [
                {
                    "location": null,
                    "min_nsd": [
                        0
                    ],
                    "timedata": null,
                    "max_nsd": [
                        0
                    ],
                    "price": [
                    ],
                    "price_nsd": [
                        0
                    ],
                    "max_supply": [
                        0
                    ],
                    "price_supply": [
                        0
                    ],
                    "price_unmet_policy": {
                    },
                    "constraints": {
                    },
                    "rhs_policy": {
                    },
                    "id": null,
                    "demand": [
                    ]
                }
            ]
        }
    ]
}
```

Macro will add all default fields to the new Node. Details on each of these fields can be found here. Most fields can be deleted if you do not want to assign a non-default value. The only field which should not be deleted is the "id" field.

In the future we will add features to allow several Nodes of the same Commodity to be added at once with global data, as well as tools to automatically group Nodes with the same parameters.

## Giving a Node an ID

Each Node must have a unique ID. This can be assigned by entering a name / identifier as a string in the Nodes file (`system/nodes.json`, by default).

Macro does not currently have a way to check if an ID is already in use. This is something we are investigating as a future feature. In the meantime, we recommend using your code editors search features to see if a preferred ID is already in use.

When you try to create a node with an ID that already exists, different things happen depending on the location and commodity:

#### Same location, same commodity
Macro will throw an error: `ERROR: A <Commodity> node already exists in the <Location> location.`

**Solution:** Use a different ID.

#### Different locations, same commodity
**Node creation:**
- If no other nodes of that commodity exist in those locations → Both nodes are created successfully
- If other nodes of that commodity already exist in those locations → The error is thrown as above

**Asset connections:**
- Assets that reference only the location → They should connect to existing nodes automatically (no errors)
- Assets that reference nodes explicitly (e.g., `TransmissionLink`, `GasStorage`) → They may connect to the wrong node (first one with that ID in the `nodes.json` file)

#### Different locations, different commodities
**Asset connections:**
- If an asset references a node explicitly and the first node in the `nodes.json` file with that ID has the wrong commodity → An error is thrown:

```
ERROR: <Edge ID> cannot be connected to its <start/end> vertex, <vertex ID>.
They have different commodities
<Edge ID> is a <commodity> edge.
<vertex ID> is a <commodity> vertex.
```
- If an asset references a node explicitly and the first node in the `nodes.json` file with that ID has the correct commodity → Connected to the first node with that ID (may be the wrong node)

- Assets that don't reference nodes explicitly → They should be created successfully

#### Recommendation
**Always use unique IDs** to avoid these complications. If you must reuse IDs, be very careful about asset connections and test thoroughly.

## Adding data and constraints

You should parameterize your new Node by adding data and constraints to the relevant fields of the JSON file.

Details on the Node fields can be found in [the Nodes page of the manual](@ref "Nodes").

Details on adding timeseries data can be found [here](@ref "Timeseries").

## Assing the Node to a Location

It is recommended to add Nodes to a Location whenever the design of your System allows. This will allow you to use several features which simplify the process of connecting a Node to Assets and other Nodes.

To assign a Node to a Location, input the Location name as a string in the "location" field of the Node.

[Adding a Location to a System](@ref) details how to add new Locations.

In the future, we will add additional features to allow Locations and their constituent Nodes to be added with one template function call.
