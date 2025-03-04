# Variable Renewable Energy resources (VRE)

## Graph structure
A Variable Renewable Energy asset is represented in Macro using the following graph structure:

```@raw html
<img width="400" src="../../images/vre.png" />
```

A Variable Renewable Energy asset is made of:

- 1 `Transformation` component, representing the VRE transformation.
- 1 `Edge` component:
    - 1 **outgoing** `Electricity` `Edge`, representing the electricity production.

## Attributes
The structure of the input file for a VRE asset follows the graph representation. Each `global_data` and `instance_data` will look like this:

```json
{
    "transforms":{
        // ... transformation-specific attributes ...
    },
    "edges":{
        "edge": {
            // ... electricity edge-specific attributes ...
        }
    }
}
```

### Transformation
The definition of the transformation object can be found here [MacroEnergy.Transformation](@ref).

| **Attribute** | **Type** | **Values** | **Default** | **Description** |
|:--------------| :------: |:------: | :------: |:-------|
| **timedata** | `String` | `String` | Required | Time resolution for the time series data linked to the transformation. E.g. "Electricity". |
| **constraints** | `Dict{String,Bool}` | Any Macro constraint type for vertices | Empty | List of constraints applied to the transformation. E.g. `{"BalanceConstraint": true}`. |

### Edges
The definition of the `Edge` object can be found here [MacroEnergy.Edge](@ref).

| **Attribute** | **Type** | **Values** | **Default** | **Description** |
|:--------------| :------: |:------: | :------: |:-------|
| **type** | `String` | `Electricity` | Required | Commodity of the edge. |
| **end_vertex** | `String` | Any electricity node id present in the system | Required | ID of the ending vertex of the edge. The node must be present in the `nodes.json` file. E.g. "elec\_node\_1". |
| **constraints** | `Dict{String,Bool}` | Any Macro constraint type for Edges | Empty | List of constraints applied to the edge. E.g. `{"MustRunConstraint": true}`. |
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
| **unidirectional** | `Bool` | `Bool` | `true` | Whether the edge is unidirectional. |
| **variable\_om\_cost** | `Float64` | `Float64` | `0.0` | Variable operation and maintenance cost (USD/MWh). |

!!! tip "Default constraint"
    **Default constraint** for the electricity edge of the VRE is the [Capacity constraint](@ref).

## Example
The following input file example shows how to create four existing VRE assets (two utility-scale solar and two onshore wind facilities) and four new VRE assets (one offshore wind, one onshore wind, and two utility-scale solar facilities).
```json
{
    "existing_vre": [
        {
            "type": "VRE",
            "global_data": {
                "transforms": {
                    "timedata": "Electricity"
                },
                "edges": {
                    "edge": {
                        "type": "Electricity",
                        "unidirectional": true,
                        "can_expand": false,
                        "can_retire": true,
                        "has_capacity": true,
                        "constraints": {
                            "CapacityConstraint": true
                        }
                    }
                },
                "storage": {}
            },
            "instance_data": [
                {
                    "id": "existing_solar_SE",
                    "edges": {
                        "edge": {
                            "fixed_om_cost": 22887,
                            "capacity_size": 17.142,
                            "existing_capacity": 8502.2,
                            "end_vertex": "elec_SE",
                            "availability": {
                                "timeseries": {
                                    "path": "assets/availability.csv",
                                    "header": "SE_solar_photovoltaic_1"
                                }
                            }
                        }
                    },
                },
                {
                    "id": "existing_solar_NE",
                    "edges": {
                        "edge": {
                            "fixed_om_cost": 22887,
                            "capacity_size": 3.63,
                            "existing_capacity": 1629.6,
                            "end_vertex": "elec_NE",
                            "availability": {
                                "timeseries": {
                                    "path": "assets/availability.csv",
                                    "header": "NE_solar_photovoltaic_1"
                                }
                            }
                        }
                    },
                },
                {

                    "id": "existing_wind_NE",
                    "edges": {
                        "edge": {
                            "fixed_om_cost": 43000,
                            "capacity_size": 86.17,
                            "existing_capacity": 3654.5,
                            "end_vertex": "elec_NE",
                            "availability": {
                                "timeseries": {
                                    "path": "assets/availability.csv",
                                    "header": "NE_onshore_wind_turbine_1"
                                }
                            }
                        }
                    },
                },
                {
                    "id": "existing_wind_MIDAT",
                    "edges": {
                        "edge": {
                            "fixed_om_cost": 43000,
                            "capacity_size": 161.2,
                            "existing_capacity": 3231.6,
                            "end_vertex": "elec_MIDAT",
                            "availability": {
                                "timeseries": {
                                    "path": "assets/availability.csv",
                                    "header": "MIDAT_onshore_wind_turbine_1"
                                }
                            }
                        }
                    },
                }
            ]
        }
    ],
    "new_vre": [
        {
            "type": "VRE",
            "global_data": {
                "transforms": {
                    "timedata": "Electricity"
                },
                "edges": {
                    "edge": {
                        "type": "Electricity",
                        "unidirectional": true,
                        "can_expand": true,
                        "can_retire": false,
                        "has_capacity": true,
                        "constraints": {
                            "CapacityConstraint": true,
                            "MaxCapacityConstraint": true
                        }
                    }
                },
            },
            "instance_data": [
                {
                    "id": "NE_offshorewind_class10_moderate_floating_1_1",
                    "edges": {
                        "edge": {
                            "fixed_om_cost": 56095.98976,
                            "investment_cost": 225783.4407,
                            "max_capacity": 32928.493,
                            "end_vertex": "elec_NE",
                            "availability": {
                                "timeseries": {
                                    "path": "assets/availability.csv",
                                    "header": "NE_offshorewind_class10_moderate_floating_1_1"
                                }
                            }
                        }
                    },
                },
                {
                    "id": "SE_utilitypv_class1_moderate_70_0_2_1",
                    "edges": {
                        "edge": {
                            "fixed_om_cost": 15390.48615,
                            "investment_cost": 49950.17548,
                            "max_capacity": 1041244,
                            "end_vertex": "elec_SE",
                            "availability": {
                                "timeseries": {
                                    "path": "assets/availability.csv",
                                    "header": "SE_utilitypv_class1_moderate_70_0_2_1"
                                }
                            }
                        }
                    },
                },
                {
                    "id": "MIDAT_utilitypv_class1_moderate_70_0_2_1",
                    "edges": {
                        "edge": {
                            "fixed_om_cost": 15390.48615,
                            "investment_cost": 51590.03227,
                            "max_capacity": 26783,
                            "end_vertex": "elec_MIDAT",
                            "availability": {
                                "timeseries": {
                                    "path": "assets/availability.csv",
                                    "header": "MIDAT_utilitypv_class1_moderate_70_0_2_1"
                                }
                            }
                        }
                    },
                },
                {
                    "id": "NE_landbasedwind_class4_moderate_70_3",
                    "edges": {
                        "edge": {
                            "fixed_om_cost": 34568.125,
                            "investment_cost": 86536.01624,
                            "max_capacity": 65324,
                            "end_vertex": "elec_NE",
                            "availability": {
                                "timeseries": {
                                    "path": "assets/availability.csv",
                                    "header": "NE_landbasedwind_class4_moderate_70_3"
                                }
                            }
                        }
                    }
                }
            ]
        }
    ]
}
```