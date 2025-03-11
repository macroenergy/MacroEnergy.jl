# Power Line

## Graph structure
A power line is represented in Macro using the following graph structure:

```@raw html
<img width="400" src="../../images/powerline.png" />
```

A power line asset is very simple and is made of:

- 1 `Edge` component:
    - 1 `Electricity` `Edge`, representing the flow of electricity between two nodes.
            
## Attributes
The structure of the input file for a power line asset follows the graph representation. Each `global_data` and `instance_data` will look like this:

```json
{
    "edges":{
        "elec_edge": {
            // ... elec_edge-specific attributes ...
        }
    }
}
```

### Edges
The definition of the `Edge` object can be found here [MacroEnergy.Edge](@ref).

| **Attribute** | **Type** | **Values** | **Default** | **Description** |
|:--------------| :------: |:------: | :------: |:-------|
| **type** | `String` | `Electricity` | Required | Commodity flowing through the edge. |
| **start_vertex** | `String` | Any electricity node id present in the system | Required | ID of the starting vertex of the edge. The node must be present in the `nodes.json` file. E.g. "elec\_node\_1". |
| **end_vertex** | `String` | Any electricity node id present in the system | Required | ID of the ending vertex of the edge. The node must be present in the `nodes.json` file. E.g. "elec\_node\_2". |
| **constraints** | `Dict{String,Bool}` | Any Macro constraint type for Edges | `CapacityConstraint` | List of constraints applied to the edge. E.g. `{"CapacityConstraint": true}`. |
| **can_expand** | `Bool` | `Bool` | `false` | Whether the edge is eligible for capacity expansion. |
| **can_retire** | `Bool` | `Bool` | `false` | Whether the edge is eligible for capacity retirement. |
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
    The **default constraint** for power lines is the [Capacity constraint](@ref). 

## Example
The following is an example of the input file for a power line asset that creates two power lines, one connecting the SE and MIDAT regions, and one connecting the MIDAT and NE regions.

```json
{
    "line": [
        {
            "type": "PowerLine",
            "global_data": {
                "edges": {
                    "elec_edge": {
                        "type": "Electricity",
                        "has_capacity": true,
                        "unidirectional": false,
                        "can_expand": true,
                        "can_retire": false,
                        "integer_decisions": false,
                        "constraints": {
                            "CapacityConstraint": true,
                            "MaxCapacityConstraint": true
                        }
                    }
                }
            },
            "instance_data": [
                {
                    "id": "SE_to_MIDAT",
                    "edges": {
                        "elec_edge": {
                            "start_vertex": "elec_SE",
                            "end_vertex": "elec_MIDAT",
                            "distance": 491.4512001,
                            "existing_capacity": 5552,
                            "max_capacity": 33312,
                            "investment_cost": 35910,
                            "loss_fraction": 0.04914512
                        }
                    }
                },
                {
                    "id": "MIDAT_to_NE",
                    "edges": {
                        "elec_edge": {
                            "start_vertex": "elec_MIDAT",
                            "end_vertex": "elec_NE",
                            "distance": 473.6625536,
                            "existing_capacity": 1915,
                            "max_capacity": 11490,
                            "investment_cost": 55639,
                            "loss_fraction": 0.047366255
                        }
                    }
                }
            ]
        }
    ]
}
```
