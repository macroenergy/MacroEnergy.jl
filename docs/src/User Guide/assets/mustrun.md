# Must Run

## Graph structure
A MustRun asset is represented in MACRO using the following graph structure:

```@raw html
<img width="400" src="../../images/vre.png" />
```

A MustRun asset is very similar to a `VRE` asset, and is made of:

- 1 `Transformation` component, representing the MustRun transformation.
- 1 `Edge` component:
    - 1 **outgoing** `Electricity` `Edge`, representing the electricity production.

## Attributes
The structure of the input file for a hydroelectric reservoir asset follows the graph representation. Each `global_data` and `instance_data` will look like this:

```json
{
    "transforms":{
        // ... transformation-specific attributes ...
    },
    "edges":{
        "elec_edge": {
            // ... elec_edge-specific attributes ...
        }
    }
}
```

### Transformation
The definition of the transformation object can be found here [Macro.Transformation](@ref).

| **Attribute** | **Asset** | **Type** | **Values** | **Default** | **Description** |
|:--------------| :------: |:------: | :------: | :------: |:-------|
| **timedata** | All | `String` | `String` | Required | Time resolution for the time series data linked to the transformation. E.g. "Electricity". |
| **constraints** | All | `Dict{String,Bool}` | Any MACRO constraint type for vertices | Empty | List of constraints applied to the transformation. E.g. `{"BalanceConstraint": true}`. |

### Edges
The definition of the `Edge` object can be found here [Macro.Edge](@ref).

| **Attribute** | **Type** | **Values** | **Default** | **Description** |
|:--------------| :------: |:------: | :------: |:-------|
| **end_vertex** | `String` | Any electricity node id present in the system | Required | ID of the ending vertex of the edge. The node must be present in the `nodes.json` file. E.g. "elec\_node\_1". |
| **constraints** | `Dict{String,Bool}` | Any MACRO constraint type for Edges | Empty | List of constraints applied to the edge. E.g. `{"MustRunConstraint": true}`. |
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

!!! tip "Default constraints"
    **Default constraints** for the edges of the MustRun asset are only applied to the inflow edge. These constraints are:

    - [Must run constraint](@ref)

## Example
The following input file example shows how to create a MustRun asset in each of the three zones SE, MIDAT and NE.
```json
{
    "mustrun": [
        {
            "type": "MustRun",
            "global_data": {
                "nodes": {},
                "transforms": {
                    "timedata": "Electricity"
                },
                "edges": {
                    "elec_edge": {
                        "unidirectional": true,
                        "can_expand": false,
                        "can_retire": false,
                        "has_capacity": true,
                        "constraints": {
                            "MustRunConstraint": true
                        }
                    }
                }
            },
            "instance_data": [
                {
                    "id": "SE_small_hydroelectric_1",
                    "edges": {
                        "elec_edge": {
                            "end_vertex": "elec_SE",
                            "existing_capacity": 249.895,
                            "capacity_size": 1.219,
                            "fixed_om_cost": 45648,
                            "availability": {
                                "timeseries": {
                                    "path": "assets/availability.csv",
                                    "header": "SE_small_hydroelectric_1"
                                }
                            }
                        }
                    }
                },
                {
                    "id": "MIDAT_small_hydroelectric_1",
                    "edges": {
                        "elec_edge": {
                            "end_vertex": "elec_MIDAT",
                            "existing_capacity": 263.268,
                            "capacity_size": 1.236,
                            "fixed_om_cost": 45648,
                            "availability": {
                                "timeseries": {
                                    "path": "assets/availability.csv",
                                    "header": "MIDAT_small_hydroelectric_1"
                                }
                            }
                        }
                    }
                },
                {
                    "id": "NE_small_hydroelectric_1",
                    "edges": {
                        "elec_edge": {
                            "end_vertex": "elec_NE",
                            "existing_capacity": 834.494,
                            "capacity_size": 1.051,
                            "fixed_om_cost": 45648,
                            "availability": {
                                "timeseries": {
                                    "path": "assets/availability.csv",
                                    "header": "NE_small_hydroelectric_1"
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