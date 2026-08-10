# Macro Input Data

*Macro version 0.1.0*

Macro input files are organized into **three** main directories:

- **[Settings folder](@ref)**: Contains all the settings for the run and the solver.
- **[System folder](@ref)**: Contains all files related to the system, such as sectors, time resolution, nodes, demand, etc.
- **[Assets folder](@ref)**: Contains all the files that define the assets, such as transmission lines, power plants, storage units, etc.

In addition to these folders, the user should provide a [`system_data.json`](@ref) file that contains the paths to the input folders and files.

As a result, the folder structure for a Macro case should be as follows:

```
MacroCase
│ 
├── 📁 settings
│   └── macro_settings.yml      
│ 
├── 📁 system
│   ├── commodities.json 
│   ├── time_data.json
│   ├── nodes.json
│   ├── demand.csv
│   └── fuel_prices.csv
│ 
├── 📁 assets
│   ├──battery.json
│   ├──electrolyzers.json
│   ├──fuel_prices.csv
│   ├──fuelcell.json
│   ├──h2storage.json
│   ├──power_lines.json
│   ├──thermal_h2.json
│   ├──thermal_power.json
│   ├──vre.json
| [...other asset types...]
│   └──availability.csv
│ 
└── system_data.json
```

!!! note "Units in Macro"
    Macro is agnostic to the units of the input data. Special attention should be paid to the units of the transformation parameters (e.g., conversion efficiency, fuel-to-energy production, etc.). It is the user's responsibility to ensure that the units are consistent across the system input data.

    The following table shows the **default units** of the input data that are used, for instance, in the example system provided with the package:

    | **Sector/Quantity** | **Units** |
    | :-----------------: | :---------: |
    | **Electricity** | MWh |
    | **Hydrogen** | MWh |
    | **NaturalGas** | MWh |
    | **Uranium** | MWh |
    | **Coal** | MWh |
    | **CO2** | ton |
    | **CO2Captured** | ton |
    | **Biomass** | ton |
    | **Time** | hours |
    | **Price** | USD |

    Commodities that require only an energy representation (e.g., Hydrogen) have units of MWh.
    Commodities that require a physical representation (e.g., Biomass, where regional supply curve is important) have units of metric tonnes.
    The recommended convention is MWh on a higher heating value basis for transformations where hydrogen is involved, and tonnes on a dry basis for transformations where biomass is involved.

!!! warning "Comments in JSON files"
    The comments (e.g. `//`) in the JSON file examples are for illustrative purposes only. They should be removed before using these lines as input, as JSON does not support comments.

In the following section, we will go through each folder and file in detail.

## Settings folder

The `settings` folder currently contains only one file, `macro_settings.yml`, which contains the settings for the run.

### macro_settings.json

**Format**: JSON

| **Attribute** | **Values** | **Default** | **Description** |
|---------------| :-----------------: | :---------: |-----------------|
| ConstraintScaling | True, False | False | If true, the model will scale the optimization model constraints to make it more numerically stable. |
| AllowImplicitTopLevelCommodities | True, False | True | If true, unknown plain commodity names in `commodities.json` are treated as new top-level commodities inheriting from `Commodity`; if false, unknown names raise an error. |
| WriteSubcommodities | True, False | True | If true, the model will write the subcommodities created by the user to file. |
| OverwriteResults | True, False | False | If true, the model will overwrite the results file if it already exists. |
| OutputDir | String | "results" | The directory where the results will be saved. |
| OutputLayout | "long", "wide" | "long" | Switch between "long" and "wide" layouts for CSV output files. |
| DualExportsEnabled | True, False | False | If true, the model will write duals for balance equations in the results folder |
| EnableJuMPStringNames | True, False | False | If true, the model will attach a string name to each JuMP variables. Ignored when Benders decomposition is used. |
| EnableJuMPDirectModel | True, False | False | If true, the model will be generate a JuMP direct model. Ignored when Benders decomposition is used. |
| AutoCreateNodes | True, False | False | If true, the model will automatically create a new Node if Macro is asked to find a Node of a given Commodity at a Location and the Node does not exist. |
| AutoCreateLocations | True, False | True |  If true, the model will automatically create a new Location if Macro comes across a Node which is a assigned to a Location that does not exist. |
| Retrofitting | True, False | False | If true, the model will consider retrofi investments |

## System folder

The `system` folder currently contains five main files:

- [commodities.json](@ref): Defines the sectors/commodities used in the system.
- **`time_data.json`**: Defines the time resolution data for each sector.
- [nodes.json](@ref): Defines the nodes in the system.
- [demand.csv](@ref): Contains the demand data.
- [fuel_prices.csv](@ref): Contains the prices of fuels.

### commodities.json

**Format**: JSON

This file contains a list of sectors/commodities used in the system. The file is a list of string for each sector/commodity:

```json
{
    "commodities": [
        "Sector_1",
        "Sector_2",
        ...
    ]
}
```

**Example**: Energy system with electricity, hydrogen, natural gas, CO2, uranium, and coal sectors:

```json
{
    "commodities": [
        "Electricity",
        "Hydrogen",
        "NaturalGas",
        "CO2", 
        "Uranium",
        "Coal"
    ]
}
```

### nodes.json

**Format**: JSON

This file defines the regions/nodes for each sector. It is structured as a list of dictionaries, where each dictionary defines a network for a given sector.

Each dictionary has three main attributes:

- `type`: The type of the network (e.g. "NaturalGas", "Electricity", etc.).
- `global_data`: attributes that are the same for all the nodes in the network.
- `instance_data`: attributes that are different for each node in the network.

This structure for the network has the advantage of **grouping the common attributes** for all the nodes in a single place, avoiding to repeat the same attribute for all the nodes.

This is the structure of the `nodes.json` file:

```json
{
    "nodes": [
        {
            "type": "NaturalGas", // NaturalGas network
            "global_data": {},    // attributes that are the same for all the nodes in the network
            "instance_data": [
                // NaturalGas node 1 ...
                // NaturalGas node 2 ...
                // ...
            ]
        },
        {
            "type": "Electricity", // Electricity network
            "global_data": {},     // attributes that are the same for all the nodes in the network
            "instance_data": [
                // Electricity node 1 ...
                // Electricity node 2 ...
                // ...
            ]
        }
    ]
}
```

The attributes that can be set for each node (either in `global_data` or `instance_data`) are the following:

| **Attribute** | **Type** | **Values** | **Default** | **Description** |
|:--------------| :------: | :------: | :------: |:-------|
| **id** | `String` | `String` | Required | Unique identifier for the node. E.g. "elec\_node\_1". |
| **type** | `String` | Any Macro commodity type | Required | Commodity type. E.g. "Electricity".|
| **time_interval** | `String` | Any Macro commodity type | Required | Time resolution for the time series data linked to the node. E.g. "Electricity".|
| **constraints** | `Dict{String,Bool}` | Any Macro constraint type | Empty | List of constraints applied to the node. E.g. `{"BalanceConstraint": true, "MaxNonServedDemandConstraint": true}`.|
| **demand** | `Dict` | Demand file path and header | Empty | Path to the demand file and column name for the demand time series to link to the node. E.g. `{"timeseries": {"path": "system/demand.csv", "header": "Demand_MW_z1"}}`.|
| **max_nsd** | `Vector{Float64}` | Vector of numbers $\in$ [0,1] | [0.0] | Maximum allowed non-served demand for each demand segment as a fraction of the total demand. E.g. `[1.0]` for a single segment. |
| **supply** | `Dict{String,Dict{String,Any}}` | Segment-keyed supply objects | Empty | Preferred external supply format. Each segment must define `price`, may define `min`, and may define `max`. Missing `min` defaults to `0.0`; missing `max` defaults to `Inf`. |
| **price** | `Vector{Float64}` | Postprocessed output | Empty | Effective node price computed during postprocessing from realized supply flows. This is typically not provided as an input. |
| **price_nsd** | `Vector{Float64}` | Vector of numbers | [0.0] | Price/penalty for non-served demand by segment. E.g. `[5000.0]` for a single segment. |
| **price\_unmet\_policy** | `Dict{DataType,Float64}` | Dict of Macro policy types and numbers | Empty | Price/penalty for unmet policy constraints. |
| **rhs\_policy** | `Dict{DataType,Float64}` | Dict of Macro constraint types and numbers | Empty | Right hand side of the policy constraints. E.g. `{"CO2CapConstraint": 200}`, carbon price of 200 USD/ton. |

!!! note "Supply input format"
    The preferred format for node supply inputs is a single `supply` dictionary keyed by segment name. Each segment must contain a `price` entry and may optionally contain `min` and `max`. Legacy `price_supply` / `min_supply` / `max_supply` inputs are still accepted and converted internally to the `supply` representation.

!!! tip "Constraints"
    One of the main features of Macro is the ability to include constraints on the system from a pre-defined library of constraints (see [Macro Constraint Library](@ref macro_constraint_library) for more details). To include a constraint to a node, the user needs to add the constraint name to the `constraints` attribute of the node. The example below will show how to include constraints to node instances. 

**Example**: the following is an example of a `nodes.json` file with both electricity, natural gas, CO2 and biomass sectors covering most of the attributes present above. The (multiplex)-network in the system is made of the following sub-networks:

- NaturalGas (three nodes)
    - `natgas_SE`
    - `natgas_MIDAT`
    - `natgas_NE`
- Electricity (three nodes)
    - `elec_SE`
    - `elec_MIDAT`
    - `elec_NE`
- CO2 (one node)
    - `co2_sink`
- Biomass (one node)
    - `bioherb_SE`

Therefore, the system has 4 networks and 8 nodes in total.

```json
{
    "nodes": [
        {
            "type": "NaturalGas",
            "global_data": {
                "time_interval": "NaturalGas" // time resolution as defined in the time_data.json file
            },
            "instance_data": [
                {   // NaturalGas node 1
                    "id": "natgas_SE",
                    "supply": {
                        "segment1": {
                            "price": {
                                "timeseries": {
                                    "path": "system/fuel_prices.csv", // path to the price file
                                    "header": "natgas_SE" // column name in the price file for the price time series
                                }
                            },
                            "max": [Infinity]
                        }
                    }
                },  // End of NaturalGas node 1
                {   // NaturalGas node 2
                    "id": "natgas_MIDAT",
                    "supply": {
                        "segment1": {
                            "price": {
                                "timeseries": {
                                    "path": "system/fuel_prices.csv",
                                    "header": "natgas_MIDAT"
                                }
                            },
                            "max": [Infinity]
                        }
                    }
                },  // End of NaturalGas node 2
                {   // NaturalGas node 3
                    "id": "natgas_NE",
                    "supply": {
                        "segment1": {
                            "price": {
                                "timeseries": {
                                    "path": "system/fuel_prices.csv",
                                    "header": "natgas_NE"
                                }
                            }
                            },
                            "max": [Infinity]
                        }
                    }
                },  // End of NaturalGas node 3
            ]
        },
        {
            "type": "Electricity",
            "global_data": {
                "time_interval": "Electricity",
                "max_nsd": [  // maximum allowed non-served demand for each demand segment as a fraction of the total demand
                    1
                ],
                "price_nsd": [  // price/penalty for non-served demand by segment
                    5000.0
                ],
                "constraints": {    // constraints applied to the nodes
                    "BalanceConstraint": true,
                    "MaxNonServedDemandConstraint": true,
                    "MaxNonServedDemandPerSegmentConstraint": true
                }
            },
            "instance_data": [
                {
                    "id": "elec_SE",
                    "demand": {
                        "timeseries": {
                            "path": "system/demand.csv", // path to the demand file
                            "header": "Demand_MW_z1" // column name in the demand file for the demand time series
                        }
                    }
                },
                {
                    "id": "elec_MIDAT",
                    "demand": {
                        "timeseries": {
                            "path": "system/demand.csv",
                            "header": "Demand_MW_z2"
                        }
                    }
                },
                {
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
            "type": "CO2",
            "global_data": {
                "time_interval": "CO2"
            },
            "instance_data": [
                {
                    "id": "co2_sink",
                    "constraints": {
                        "CO2CapConstraint": true
                    },
                    "rhs_policy": {  // right hand side of the policy constraints
                        "CO2CapConstraint": 0
                    },
                    "price_unmet_policy": {  // price/penalty for unmet policy constraints
                        "CO2CapConstraint": 250.0
                    }
                }
            ]
        },
        {
            "type": "Biomass",
            "global_data": {
                "time_interval": "Biomass",
                "constraints": {
                    "BalanceConstraint": true
                }
            },
            "instance_data": [
                {
                    "id": "bioherb_SE",
                    "demand": {
                        "timeseries": {
                            "path": "system/demand.csv",
                            "header": "Demand_Zero"
                        }
                    },
                    "supply": {
                        "base": {
                            "price": [40],
                            "min": [500],
                            "max": [10000]
                        },
                        "mid": {
                            "price": [60],
                            "max": [20000]
                        },
                        "peak": {
                            "price": [80],
                            "max": [30000]
                        }
                    }
                }
            ]
        }
    ]
}
```

In this example, `BalanceConstraint`, `MaxNonServedDemandConstraint`, and `MaxNonServedDemandPerSegmentConstraint` are applied to all the nodes in the electricity network. In particular, the `MaxNonServedDemandConstraint` limits the maximum amount of demand that can be unmet in a given time step, and the `MaxNonServedDemandPerSegmentConstraint` limits the maximum amount of demand that can be unmet in each demand segment. In addition, the `CO2CapConstraint` is applied to the $\text{CO}_2$ node to model a greenfield scenario with a carbon price of 250 USD/ton.

### demand.csv
**Format**: CSV

This file contains the demand data for each region/node. 

- **First column**: Time step.
- **Remaining columns**: Demand for each region/node (units: MWh).

##### Example:

| TimeStep | Demand_MW_z1 | Demand_MW_z2 | Demand_MW_z3 |
| -------- | ------------ | ------------ | ------------ |
| 1        | 100          | 200          | 300          |
| 2        | 110          | 210          | 310          |
| ...      | ...          | ...          | ...          |

### fuel_prices.csv
**Format**: CSV

This file contains the prices for each fuel for each region/node.

- **First column**: Time step.
- **Remaining columns**: Prices for each region/node (units: USD/MWh).

##### Example:

| TimeStep | natgas_SE | natgas_MIDAT | natgas_NE |
| -------- | --------- | ------------- | --------- |
| 1        | 100       | 110           | 120       |
| 2        | 110       | 120           | 130       |
| ...      | ...       | ...           | ...       |

## Assets folder
The `assets` folder contains all the files that define the resources and technologies that are included in the system. As a general rule, each asset type has its own file, where each file is structured in a similar way to the `nodes.json` file. 

### Asset files
**Format**: JSON

Similar to the `nodes.json` file, each asset file has the following three main parameters:
- `type`: The type of the asset (e.g. "Battery", "FuelCell", "TransmissionLink", etc.).
- `global_data`: attributes that are the same for all the assets of the same type (e.g., unit commitment constraints applied to all the power plants).
- `instance_data`: attributes that are different for each asset of the same type (e.g., investment costs, lifetime, etc.).

Depending on the graph structure of the asset, both `global_data` and `instance_data` can have different attributes, one for each transformation, edge, and storage present in the asset. 

!!! tip "Example: natural gas power plant"
    For example, a natural gas combined cycle power plant is represented by an asset made of: 
    - **1 transformation** (combustion and electricity generation)
    - **3 edges** 
        - natural gas flow
        - electricity flow
        - CO2 flow

    Then, both `global_data` and `instance_data` will have the following structure:
    ```json
    {
        "transforms":{
            // ... transformation-specific attributes ...
        },
        "edges":{
            "elec_edge": {
                // ... elec_edge-specific attributes ...
            },
            "fuel_edge": {
                // ... fuel_edge-specific attributes ...
            },
            "co2_edge": {
                // ... co2_edge-specific attributes ...
            }
        }
    }
    ```

In the following sections, we will go through each asset type and show the attributes that can be set for each of them.
Each section will contain the following three parts:
- **Graph structure**: a graphical representation of the asset, showing the transformations, edges, and storages present in the asset.
- **Attributes**: a table with the attributes that can be set for each asset type.
- **Example**: an example of the asset type file (`.json`).

## `system_data.json`
**Format**: JSON

This file contains the paths to the input folders and files, and is structured as follows:

```json
{
    "commodities": {
        "path": "system/commodities.json"
    },
    "locations": {
        "path": "locations"
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