# Hydro Reservoir

## Graph structure
A hydroelectric reservoir is represented in Macro using the following graph structure:

```@raw html
<img width="400" src="../../images/hydrores.png" />
```

A hydroelectric reservoir asset is made of:

- 1 `Storage` component, representing the hydroelectric reservoir.
- 3 `Edge` components:
    - 1 **incoming** `Electricity` `Edge`, representing the electricity supply.
    - 1 **outgoing** `Electricity` `Edge`, representing the electricity production.
    - 1 **outgoing** `Electricity` `Edge`, representing the spillage.

## Flow equation
In the following equation, $\phi$ is the flow of the commodity.

!!! note "HydroRes"
    ```math
    \begin{aligned}
    \phi_{in} &= \phi_{out} + \phi_{spill} \\
    \end{aligned}
    ```

## Attributes
The structure of the input file for a hydroelectric reservoir asset follows the graph representation. Each `global_data` and `instance_data` will look like this:

```json
{
    "transforms":{
        // ... transformation-specific attributes ...
    },
    "edges":{
        "inflow_edge": {
            // ... inflow_edge-specific attributes ...
        },
        "discharge_edge": {
            // ... discharge_edge-specific attributes ...
        },
        "spillage_edge": {
            // ... spillage_edge-specific attributes ...
        }
    }
}
```

### Storage component
The definition of the `Storage` object can be found here [MacroEnergy.Storage](@ref).

| **Attribute** | **Type** | **Values** | **Default** | **Description** |
|:--------------| :------: |:------: | :------: |:-------|
| **commodity** | `String` | `Electricity` | Required | Commodity being stored. |
| **constraints** | `Dict{String,Bool}` | Any Macro constraint type for storage | `BalanceConstraint`, `StorageCapacityConstraint` | List of constraints applied to the storage. E.g. `{"BalanceConstraint": true}`. |
| **can_expand** | `Bool` | `Bool` | `false` | Whether the storage is eligible for capacity expansion. |
| **can\_retire** | `Bool` | `Bool` | `false` | Whether the storage is eligible for capacity retirement. |
| **charge\_discharge\_ratio** | `Float64` | `Float64` | `1.0` | Ratio between charging and discharging rates. |
| **existing\_capacity\_storage** | `Float64` | `Float64` | `0.0` | Initial installed storage capacity (MWh). |
| **fixed\_om\_cost\_storage** | `Float64` | `Float64` | `0.0` | Fixed operations and maintenance cost (USD/MWh-year). |
| **investment\_cost\_storage** | `Float64` | `Float64` | `0.0` | Annualized investment cost of the energy capacity for a storage technology (USD/MWh-year). |
| **max\_capacity\_storage** | `Float64` | `Float64` | `Inf` | Maximum allowed storage capacity (MWh). |
| **max\_duration** | `Float64` | `Float64` | `0.0` | Maximum ratio of installed energy to discharged capacity that can be installed (hours).|
| **min\_capacity\_storage** | `Float64` | `Float64` | `0.0` | Minimum allowed storage capacity (MWh). |
| **min\_duration** | `Float64` | `Float64` | `0.0` | Minimum ratio of installed energy to discharged capacity that can be installed (hours).|
| **min\_outflow\_fraction** | `Float64` | `Float64` | `0.0` | Minimum outflow as a fraction of capacity. |
| **min\_storage\_level** | `Float64` | `Float64` | `0.0` | Minimum storage level as a fraction of capacity. |
| **max\_storage\_level** | `Float64` | `Float64` | `1.0` | Maximum storage level as a fraction of capacity. |
| **storage\_loss\_fraction** | `Float64` | Number $\in$ [0,1] | `0.0` | Fraction of stored commodity lost per timestep. |

!!! tip "Default constraints"
    The **default constraints** for the storage component of the hydroelectric reservoir are the following:

    - [Balance constraint](@ref)

### Edges (discharge\_edge, inflow\_edge, spillage\_edge)
!!! warning "Asset expansion"
    As a modeling decision, only charge and discharge edges are allowed to expand. Therefore, the `has_capacity` attribute can only be set for the `discharge_edge` and `inflow_edge`. For the spillage edge, this attribute is pre-set to `false` to ensure the correct modeling of the asset. 

!!! warning "Directionality"
    All the three edges are unidirectional by construction.

All the edges have the same set of attributes. The definition of the `Edge` object can be found here [MacroEnergy.Edge](@ref).

| **Attribute** | **Type** | **Values** | **Default** | **Description** |
|:--------------| :------: |:------: | :------: |:-------|
| **type** | `String` | `Electricity` | Required | Commodity of the edge. |
| **start_vertex** | `String` | Any electricity node id present in the system | Required | ID of the starting vertex of the edge. The node must be present in the `nodes.json` file. E.g. "elec\_node\_1". |
| **end_vertex** | `String` | Any electricity node id present in the system | Required | ID of the ending vertex of the edge. The node must be present in the `nodes.json` file. E.g. "elec\_node\_2". |
| **constraints** | `Dict{String,Bool}` | Any Macro constraint type for Edges | Empty | List of constraints applied to the edge. E.g. `{"CapacityConstraint": true}`. |
| **can_expand** | `Bool` | `Bool` | `false` | Whether the edge is eligible for capacity expansion. |
| **can_retire** | `Bool` | `Bool` | `false` | Whether the edge is eligible for capacity retirement. |
| **capacity_size** | `Float64` | `Float64` | `1.0` | Size of the edge capacity. |
| **existing_capacity** | `Float64` | `Float64` | `0.0` | Existing capacity of the edge in MW. |
| **fixed\_om\_cost** | `Float64` | `Float64` | `0.0` | Fixed operations and maintenance cost (USD/MW-year). |
| **has\_capacity** | `Bool` | `Bool` | `false` | Whether capacity variables are created for the edge. |
| **integer\_decisions** | `Bool` | `Bool` | `false` | Whether capacity variables are integers. |
| **investment\_cost** | `Float64` | `Float64` | `0.0` | Annualized capacity investment cost (USD/MW-year) |
| **max\_capacity** | `Float64` | `Float64` | `Inf` | Maximum allowed capacity of the edge (MW). **Note: add the `MaxCapacityConstraint` to the constraints dictionary to activate this constraint**. |
| **min\_capacity** | `Float64` | `Float64` | `0.0` | Minimum allowed capacity of the edge (MW). **Note: add the `MinCapacityConstraint` to the constraints dictionary to activate this constraint**. |
| **min\_flow\_fraction** | `Float64` | Number $\in$ [0,1] | `0.0` | Minimum flow of the edge as a fraction of the total capacity. **Note: add the `MinFlowConstraint` to the constraints dictionary to activate this constraint**. |
| **ramp\_down\_fraction** | `Float64` | Number $\in$ [0,1] | `1.0` | Maximum decrease in flow between two time steps, reported as a fraction of the capacity. **Note: add the `RampingLimitConstraint` to the constraints dictionary to activate this constraint**. |
| **ramp\_up\_fraction** | `Float64` | Number $\in$ [0,1] | `1.0` | Maximum increase in flow between two time steps, reported as a fraction of the capacity. **Note: add the `RampingLimitConstraint` to the constraints dictionary to activate this constraint**. |
| **variable\_om\_cost** | `Float64` | `Float64` | `0.0` | Variable operation and maintenance cost (USD/MWh). |

!!! tip "Default constraints"
    **Default constraints** for the edges of the hydroelectric reservoir are only applied to the inflow edge. These constraints are:

    - [Must run constraint](@ref)
    - [Storage charge discharge ratio constraint](@ref)

## Example
The following input file example shows how to create a hydroelectric reservoir asset in each of the three zones SE, MIDAT and NE.
```json
{
    "hydrores": [
        {
            "type": "HydroRes",
            "global_data": {
                "edges": {
                    "discharge_edge": {
                        "type": "Electricity",
                        "unidirectional": true,
                        "has_capacity": true,
                        "can_expand": false,
                        "can_retire": false,
                        "constraints": {
                            "CapacityConstraint": true,
                            "RampingLimitConstraint": true
                        }
                    },
                    "inflow_edge": {
                        "type": "Electricity",
                        "unidirectional": true,
                        "start_vertex": "hydro_source",
                        "has_capacity": true,
                        "can_expand": false,
                        "can_retire": false,
                        "constraints": {
                            "MustRunConstraint": true
                        }
                    },
                    "spill_edge": {
                        "type": "Electricity",
                        "unidirectional": true,
                        "end_vertex": "hydro_source",
                        "can_expand": false,
                        "can_retire": false,
                        "has_capacity": false
                    }
                },
                "storage": {
                    "commodity": "Electricity",
                    "can_expand": false,
                    "can_retire": false,
                    "constraints": {
                        "MinStorageOutflowConstraint": true,
                        "StorageChargeDischargeRatioConstraint": true,
                        "BalanceConstraint": true
                    }
                }
            },
            "instance_data": [
                {
                    "id": "MIDAT_conventional_hydroelectric_1",
                    "edges": {
                        "discharge_edge": {
                            "end_vertex": "elec_MIDAT",
                            "capacity_size": 29.853,
                            "existing_capacity": 2806.182,
                            "fixed_om_cost": 45648,
                            "ramp_down_fraction": 0.83,
                            "ramp_up_fraction": 0.83,
                            "efficiency": 1.0
                        },
                        "inflow_edge": {
                            "efficiency": 1.0,
                            "availability": {
                                "timeseries": {
                                    "path": "assets/availability.csv",
                                    "header": "MIDAT_conventional_hydroelectric_1"
                                }
                            }
                        }
                    },
                    "storage": {
                        "min_outflow_fraction": 0.109311313,
                        "charge_discharge_ratio": 1.0
                    }
                },
                {
                    "id": "NE_conventional_hydroelectric_1",
                    "edges": {
                        "discharge_edge": {
                            "end_vertex": "elec_NE",
                            "capacity_size": 24.13,
                            "existing_capacity": 4729.48,
                            "fixed_om_cost": 45648,
                            "ramp_down_fraction": 0.083,
                            "ramp_up_fraction": 0.083,
                            "efficiency": 1.0
                        },
                        "inflow_edge": {
                            "efficiency": 1.0,
                            "availability": {
                                "timeseries": {
                                    "path": "assets/availability.csv",
                                    "header": "NE_conventional_hydroelectric_1"
                                }
                            }
                        }
                    },
                    "storage": {
                        "min_outflow_fraction": 0.095,
                        "charge_discharge_ratio": 1.0
                    }
                },
                {
                    "id": "SE_conventional_hydroelectric_1",
                    "edges": {
                        "discharge_edge": {
                            "end_vertex": "elec_SE",
                            "capacity_size": 31.333,
                            "existing_capacity": 11123.215,
                            "fixed_om_cost": 45648,
                            "ramp_down_fraction": 0.083,
                            "ramp_up_fraction": 0.083,
                            "efficiency": 1.0
                        },
                        "inflow_edge": {
                            "efficiency": 1.0,
                            "availability": {
                                "timeseries": {
                                    "path": "assets/availability.csv",
                                    "header": "SE_conventional_hydroelectric_1"
                                }
                            }
                        }
                    },
                    "storage": {
                        "min_outflow_fraction": 0.135129141,
                        "charge_discharge_ratio": 1.0
                    }
                }
            ]
        }
    ]
}
```