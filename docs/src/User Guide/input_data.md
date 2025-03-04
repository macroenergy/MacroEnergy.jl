# Macro Input Data
*Macro version 0.1.0*

!!! tip "Tutorial 1"
    We recommend to check the [Tutorial 1](../Tutorials/tutorial_1_input_files.md) for a step-by-step guide on how to create the input data.

All input files are divided into **three** main folders:

- **settings**: Contains all the settings for the run and the solver.
- **system**: Contains all files related to the system, such as sectors, time resolution, nodes, demand, etc.
- **assets**: Contains all the files that define the assets, such as transmission lines, power plants, storage units, etc.

In the following section, we will go through each folder and file in detail.

###  Units
Before be dive into the input data, let's define the units of the input data:

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

## Settings folder
The `settings` folder currently contains only one file, `macro_settings.yml`, which contains the settings for the run.

### macro_settings.json
**Format**: JSON

| **Attribute** | **Values** | **Default** | **Description** |
|---------------| :-----------------: | :---------: |-----------------|
| Scaling | True, False | False | If true, the model will scale the input data to the following units: MWh → GWh, tons → ktons, \$\/MWh → M\$\/GWh, \$\/ton → M\$\/kton |

## System folder
The `system` folder currently contains five main files:

- `commodities.json`: Defines the sectors/commodities used in the system.
- `time_data.json`: Defines the time resolution data for each sector.
- `nodes.json`: Defines the nodes in the system.
- `demand.csv`: Contains the demand data.
- `fuel_prices.csv`: Contains the prices of fuels.

### commodities.json
**Format**: JSON

This file contains a list of sectors/commodities used in the system. This is how the file is structured:

```json
{
    "commodities": [
        "Sector_1",
        "Sector_2",
        ...
    ]
}
```
For instance, if we want to include the electricity, hydrogen, natural gas, CO2, uranium, and coal sectors, the file should look like this:

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

### time_data.json
**Format**: JSON

This file contains the data related to the time resolution for each sector. The file is structured as follows:

```json
{
    "PeriodLength": <Integer>,  // units: hours
    "HoursPerTimeStep": {
        "Sector_1": <Integer>,  // units: hours
        "Sector_2": <Integer>,  // units: hours
        ...
    },
    "HoursPerSubperiod": {
        "Sector_1": <Integer>,
        "Sector_2": <Integer>,
        ...
    }
}
```

| **Attribute** | **Values** | **Description** |
|---------------| :-----------------: |-----------------|
| PeriodLength | Integer | Total number of **hours** in the simulation. |
| HoursPerTimeStep | Integer | Number of **hours** in each time step **for each sector**. |
| HoursPerSubperiod | Integer | Number of **hours** in each subperiod **for each sector**. |

!!! note "Subperiods"
    Subperiods represent the time slices of the simulation used to perform time wrapping for time-coupling constraints (see, for example, [MacroEnergy.timestepbefore](@ref)).

For instance, if we want to run the model for one year (non leap year), with one hour per time step and a single subperiod, the file should look like this:

```json
{
    "PeriodLength": 8760,  // one year
    "HoursPerTimeStep": {
        "Electricity": 1,
        "Hydrogen": 1,
        "NaturalGas": 1,
        "CO2": 1,
        "Uranium": 1,
        "Coal": 1
    },
    "HoursPerSubperiod": {
        "Electricity": 8760,
        "Hydrogen": 8760,
        "NaturalGas": 8760,
        "CO2": 8760,
        "Uranium": 8760,
        "Coal": 8760
    }
}
```

A more complex example is the following:

```json
{
    "PeriodLength": 504,  // 3 weeks
    "HoursPerTimeStep": {
        "Electricity": 1,
        "Hydrogen": 1,
        "NaturalGas": 1,
        "CO2": 1,
        "Uranium": 1,
        "Coal": 1
    },
    "HoursPerSubperiod": {
        "Electricity": 168,  // 1 week
        "Hydrogen": 168,
        "NaturalGas": 168,
        "CO2": 168,
        "Uranium": 168,
        "Coal": 168
    }
}
```

In this example, the simulation will run for 504 hours (3 weeks), with one hour per time step and 1 week per subperiod.

### nodes.json
**Format**: JSON

This file defines the regions/nodes for each sector. It is structured as a list of dictionaries, where each dictionary defines a network for a given sector. 

Each dictionary (network) has three main attributes:
- `type`: The type of the network (e.g. "NaturalGas", "Electricity", etc.).
- `global_data`: attributes that are the same for all the nodes in the network.
- `instance_data`: attributes that are different for each node in the network.

This structure for the network has the advantage of **grouping the common attributes** for all the nodes in a single dictionary, avoiding to repeat the same attribute for each node.

#### Node attributes
The `Node` object is defined in the file `nodes.jl` and can be found here [MacroEnergy.Node](@ref).

| **Attribute** | **Type** | **Values** | **Default** | **Description** |
|:--------------| :------: | :------: | :------: |:-------|
| **id** | `String` | `String` | Required | Unique identifier for the node. E.g. "elec\_node\_1". |
| **type** | `String` | Any Macro commodity type | Required | Commodity type. E.g. "Electricity".|
| **time_interval** | `String` | Any Macro commodity type | Required | Time resolution for the time series data linked to the node. E.g. "Electricity".|
| **constraints** | `Dict{String,Bool}` | Any Macro constraint type | Empty | List of constraints applied to the node. E.g. `{"BalanceConstraint": true, "MaxNonServedDemandConstraint": true}`.|
| **demand** | `Dict` | Demand file path and header | Empty | Path to the demand file and column name for the demand time series to link to the node. E.g. `{"timeseries": {"path": "system/demand.csv", "header": "Demand_MW_z1"}}`.|
| **price** | `Dict` | Price file path and header | Empty | Path to the price file and column name for the price time series to link to the node. E.g. `{"timeseries": {"path": "system/fuel_prices.csv", "header": "natgas_SE"}}`.|
| **max_nsd** | `Vector{Float64}` | Vector of numbers $\in$ [0,1] | [0.0] | Maximum allowed non-served demand for each demand segment as a fraction of the total demand. E.g. `[1.0]` for a single segment. |
| **price_nsd** | `Vector{Float64}` | Vector of numbers | [0.0] | Price/penalty for non-served demand by segment. E.g. `[5000.0]` for a single segment. |
| **price_supply** | `Vector{Float64}` | Vector of numbers | [0.0] | Piecewise linear price for supply curves. E.g. `[0.0, 100.0, 200.0]`. |
| **max_supply** | `Vector{Float64}` | Vector of numbers | [0.0] | Maximum allowed supply for each supply segment. E.g. `[1000.0]` for a single segment. |
| **rhs\_policy** | `Dict{DataType,Float64}` | Dict of Macro constraint types and numbers | Empty | Right hand side of the policy constraints. E.g. `{"CO2CapConstraint": 200}`, carbon price of 200 USD/ton. |
| **price\_unmet\_policy** | `Dict{DataType,Float64}` | Dict of Macro policy types and numbers | Empty | Price/penalty for unmet policy constraints. |

Here is an example of a `nodes.json` file with both electricity, natural gas, CO2 and biomass sectors covering most of the attributes present above. The (multiplex)-network in the system is made of the following networks:
- NaturalGas
    - `natgas_SE`
    - `natgas_MIDAT`
    - `natgas_NE`
- Electricity
    - `elec_SE`
    - `elec_MIDAT`
    - `elec_NE`
- CO2
    - `co2_sink`
- Biomass
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
                {
                    "id": "natgas_SE",
                    "price": {
                        "timeseries": {
                            "path": "system/fuel_prices.csv", // path to the price file
                            "header": "natgas_SE" // column name in the price file for the price time series
                        }
                    }
                },
                {
                    "id": "natgas_MIDAT",
                    "price": {
                        "timeseries": {
                            "path": "system/fuel_prices.csv",
                            "header": "natgas_MIDAT"
                        }
                    }
                },
                {
                    "id": "natgas_NE",
                    "price": {
                        "timeseries": {
                            "path": "system/fuel_prices.csv",
                            "header": "natgas_NE"
                        }
                    }
                }
            ]
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
                    "rhs_policy": {
                        "CO2CapConstraint": 0
                    },
                    "price_unmet_policy": {
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
                    "max_supply": [
                        10000,
                        20000,
                        30000
                    ],
                    "price_supply": [
                        40,
                        60,
                        80
                    ]
                }
            ]
        }
    ]
}
```

### demand.csv
**Format**: CSV

This file contains the demand data for each region/node. 

- First column: Time step.
- Remaining columns: Demand for each region/node (units: MWh).

##### Example:

| TimeStep | Demand_MW_z1 | Demand_MW_z2 | Demand_MW_z3 |
| -------- | ------------ | ------------ | ------------ |
| 1        | 100          | 200          | 300          |
| 2        | 110          | 210          | 310          |
| ...      | ...          | ...          | ...          |

### fuel_prices.csv
**Format**: CSV

This file contains the prices for each fuel for each region/node.

- First column: Time step.
- Remaining columns: Prices for each region/node (units: USD/MWh).

##### Example:

| TimeStep | natgas_SE | natgas_MIDAT | natgas_NE |
| -------- | --------- | ------------- | --------- |
| 1        | 100       | 110           | 120       |
| 2        | 110       | 120           | 130       |
| ...      | ...       | ...           | ...       |

## Assets folder
The `assets` folder contains all the files that define the resources and technologies that are included in the system. As a general rule, each asset type has its own file, where each file is structured in a similar way to the `nodes.json` file. 

### Asset type files
**Format**: JSON

Each asset type file has the following three main parameters:
- `type`: The type of the asset (e.g. "Battery", "FuelCell", "PowerLine", etc.).
- `global_data`: attributes that are the same for all the assets of the same type.
- `instance_data`: attributes that are different for each asset of the same type.

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

# Example of the folder structure for the input data
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

