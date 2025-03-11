# Hydrogen Line

## Graph structure
A hydrogen line is represented in Macro using the following graph structure:

```@raw html
<img width="400" src="../../images/h2line.png" />
```

A hydrogen line asset is very simple and is made of:

- 1 `Edge` component:
    - 1 `Hydrogen` `Edge`, representing the flow of hydrogen between two nodes.
            
## Attributes
The structure of the input file for a hydrogen line asset follows the graph representation. Each `global_data` and `instance_data` will look like this:

```json
{
    "edges":{
        "h2_edge": {
            // ... h2_edge-specific attributes ...
        }
    }
}
```

### Edge
The definition of the `Edge` object can be found here [MacroEnergy.Edge](@ref).

| **Attribute** | **Type** | **Values** | **Default** | **Description** |
|:--------------| :------: |:------: | :------: |:-------|
| **type** | `String` | `Hydrogen` | Required | Commodity flowing through the edge. |
| **start_vertex** | `String` | Any hydrogen node id present in the system | Required | ID of the starting vertex of the edge. The node must be present in the `nodes.json` file. E.g. "h2\_node\_1". |
| **end_vertex** | `String` | Any hydrogen node id present in the system | Required | ID of the ending vertex of the edge. The node must be present in the `nodes.json` file. E.g. "h2\_node\_2". |
| **constraints** | `Dict{String,Bool}` | Any Macro constraint type for Edges | `CapacityConstraint` | List of constraints applied to the edge. E.g. `{"CapacityConstraint": true}`. |
| **can_expand** | `Bool` | `Bool` | `false` | Whether the edge is eligible for capacity expansion. |
| **can_retire** | `Bool` | `Bool` | `false` | Whether the edge is eligible for capacity retirement. |
| **capacity_size** | `Float64` | `Float64` | `1.0` | Size of the edge capacity. |
| **distance** | `Float64` | `Float64` | `0.0` | Distance between the start and end vertex of the edge. |
| **existing_capacity** | `Float64` | `Float64` | `0.0` | Existing capacity of the edge in MW. |
| **fixed\_om\_cost** | `Float64` | `Float64` | `0.0` | Fixed operations and maintenance cost (USD/MW-year). |
| **has\_capacity** | `Bool` | `Bool` | `false` | Whether capacity variables are created for the edge. |
| **integer\_decisions** | `Bool` | `Bool` | `false` | Whether capacity variables are integers. |
| **investment\_cost** | `Float64` | `Float64` | `0.0` | Annualized capacity investment cost (USD/MW-year) |
| **loss\_fraction** | `Float64` | Number $\in$ [0,1] | `0.0` | Fraction of transmission loss. |
| **max\_capacity** | `Float64` | `Float64` | `Inf` | Maximum allowed capacity of the edge (MW). **Note: add the `MaxCapacityConstraint` to the constraints dictionary to activate this constraint**. |
| **min\_capacity** | `Float64` | `Float64` | `0.0` | Minimum allowed capacity of the edge (MW). **Note: add the `MinCapacityConstraint` to the constraints dictionary to activate this constraint**. |
| **min\_flow\_fraction** | `Float64` | Number $\in$ [0,1] | `0.0` | Minimum flow of the edge as a fraction of the total capacity. **Note: add the `MinFlowConstraint` to the constraints dictionary to activate this constraint**. |
| **ramp\_down\_fraction** | `Float64` | Number $\in$ [0,1] | `1.0` | Maximum decrease in flow between two time steps, reported as a fraction of the capacity. **Note: add the `RampingLimitConstraint` to the constraints dictionary to activate this constraint**. |
| **ramp\_up\_fraction** | `Float64` | Number $\in$ [0,1] | `1.0` | Maximum increase in flow between two time steps, reported as a fraction of the capacity. **Note: add the `RampingLimitConstraint` to the constraints dictionary to activate this constraint**. |
| **variable\_om\_cost** | `Float64` | `Float64` | `0.0` | Variable operation and maintenance cost (USD/MWh). |

!!! tip "Default constraints"
    The **default constraints** for the hydrogen line asset are the following:

    - [Capacity constraint](@ref)

## Example
The following is an example of the input file for a hydrogen line asset that creates two hydrogen lines, one connecting the SE and MIDAT regions, and one connecting the NE and SE regions.

```json
{
    "h2transport": [
        {
            "type": "HydrogenLine",
            "global_data": {
                "edges": {
                    "h2_edge": {
                        "type": "Hydrogen",
                        "unidirectional": false,
                        "can_expand": true,
                        "can_retire": false,
                        "has_capacity": true,
                        "integer_decisions": false,
                        "constraints": {
                            "CapacityConstraint": true
                        }
                    }
                }
            },
            "instance_data": [
                {
                    "id": "h2_SE_to_MIDAT",
                    "edges": {
                        "h2_edge": {
                            "start_vertex": "h2_SE",
                            "end_vertex": "h2_MIDAT",
                            "loss_fraction": 0.067724471,
                            "distance": 491.4512001,
                            "capacity_size": 787.6,
                            "investment_cost": 82682.23402
                        }
                    }
                },
                {
                    "id": "h2_NE_to_SE",
                    "edges": {
                        "h2_edge": {
                            "start_vertex": "h2_NE",
                            "end_vertex": "h2_SE",
                            "loss_fraction": 0.06553874,
                            "distance": 473.6625536,
                            "capacity_size": 787.6,
                            "investment_cost": 79896.9841
                        }
                    }
                }
            ]
        }
    ]
}
```
