# Fuel Cell

## Graph structure
A fuel cell is represented in MACRO using the following graph structure:

```@raw html
<img width="400" src="../../images/fuelcell.png" />
```

A fuel cell asset is made of:

- 1 `Transformation` component, representing the fuel cell process.
- 2 `Edge` components:
    - 1 **incoming** `Hydrogen` `Edge`, representing the hydrogen supply.
    - 1 **outgoing** `Electricity` `Edge`, representing the electricity production.

## Attributes
The structure of the input file for a fuel cell asset follows the graph representation. Each `global_data` and `instance_data` will look like this:

```json
{
    "transforms":{
        // ... transformation-specific attributes ...
    },
    "edges":{
        "h2_edge": {
            // ... h2_edge-specific attributes ...
        },
        "elec_edge": {
            // ... elec_edge-specific attributes ...
        }
    }
}
```

### Transformation
The definition of the transformation object can be found here [Macro.Transformation](@ref).

| **Attribute** | **Type** | **Values** | **Default** | **Description/Units** |
|:--------------| :------: |:------: | :------: |:-------|
| **timedata** | `String` | `String` | Required | Time resolution for the time series data linked to the transformation. E.g. "Hydrogen". |
| **constraints** | `Dict{String,Bool}` | Any MACRO constraint type for vertices | Empty | List of constraints applied to the transformation. E.g. `{"BalanceConstraint": true}`. |
| **efficiency_rate** $\epsilon_{efficiency}$ | `Float64` | `Float64` | `1.0` | $MWh_{elec}/MWh_{h2}$ |

!!! tip "Default constraints"
    The **default constraint** for the transformation part of the fuel cell asset is the following:
    - [Balance constraint](@ref)

#### Flow equations
In the following equations, $\phi$ is the flow of the commodity and $\epsilon$ is the stoichiometric coefficient defined in the transformation table below.

!!! note "Fuel Cell"
    ```math
    \begin{aligned}
    \phi_{elec} &= \phi_{h2} \cdot \epsilon_{efficiency} \\
    \end{aligned}
    ```

### Edges
Both the electricity and hydrogen edges are represented by the same set of attributes. The definition of the `Edge` object can be found here [Macro.Edge](@ref).

| **Attribute** | **Type** | **Values** | **Default** | **Description** |
|:--------------| :------: |:------: | :------: |:-------|
| **type** | `String` | Any MACRO commodity type matching the commodity of the edge | Required | Commodity of the edge. E.g. "Electricity". |
| **start_vertex** | `String` | Any node id present in the system matching the commodity of the edge | Required | ID of the starting vertex of the edge. The node must be present in the `nodes.json` file. E.g. "elec\_node\_1". |
| **end_vertex** | `String` | Any node id present in the system matching the commodity of the edge | Required | ID of the ending vertex of the edge. The node must be present in the `nodes.json` file. E.g. "elec\_node\_2". |
| **constraints** | `Dict{String,Bool}` | Any MACRO constraint type for Edges | Empty | List of constraints applied to the edge. E.g. `{"CapacityConstraint": true}`. |
| **availability** | `Dict` | Availability file path and header | Empty | Path to the availability file and column name for the availability time series to link to the edge. E.g. `{"timeseries": {"path": "system/availability.csv", "header": "Availability_MW_z1"}}`.|
| **can_expand** | `Bool` | `Bool` | `false` | Whether the edge is eligible for capacity expansion. |
| **can_retire** | `Bool` | `Bool` | `false` | Whether the edge is eligible for capacity retirement. |
| **capacity_size** | `Float64` | `Float64` | `1.0` | Size of the edge capacity. |
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
| **unidirectional** | `Bool` | `Bool` | `false` | Whether the edge is unidirectional. |
| **variable\_om\_cost** | `Float64` | `Float64` | `0.0` | Variable operation and maintenance cost (USD/MWh). |

!!! tip "Default constraints"
    The only **default constraint** for the edges of the fuel cell asset is the [Capacity constraint](@ref) applied to the electricity edge. 

## Example
The following is an example of the input file for a fuel cell asset that creates three fuel cells, each for each of the SE, MIDAT and NE regions.

```json
{
    "fuelcell": [
        {
            "type": "FuelCell",
            "global_data": {
                "nodes": {},
                "transforms": {
                    "timedata": "Hydrogen",
                    "constraints": {
                        "BalanceConstraint": true
                    }
                },
                "edges": {
                    "elec_edge": {
                        "type": "Electricity",
                        "unidirectional": true,
                        "has_capacity": true,
                        "can_retire": true,
                        "can_expand": true,
                        "constraints": {
                            "CapacityConstraint": true,
                            "RampingLimitConstraint": true,
                            "MinFlowConstraint": true
                        }
                    },
                    "h2_edge": {
                        "type": "Hydrogen",
                        "unidirectional": true,
                        "has_capacity": false
                    }
                }
            },
            "instance_data": [
                {
                    "id": "SE_Electrolyzer",
                    "transforms": {
                        "efficiency_rate": 0.875111139
                    },
                    "edges": {
                        "h2_edge": {
                            "start_vertex": "h2_SE"
                        },
                        "elec_edge": {
                            "end_vertex": "elec_SE",
                            "existing_capacity": 0,
                            "investment_cost": 41112.53426,
                            "fixed_om_cost": 1052.480877,
                            "variable_om_cost": 0.0,
                            "capacity_size": 1.5752,
                            "ramp_up_fraction": 1,
                            "ramp_down_fraction": 1,
                            "min_flow_fraction": 0.1
                        }
                    }
                },
                {
                    "id": "MIDAT_FuelCell",
                    "transforms": {
                        "efficiency_rate": 0.875111139
                    },
                    "edges": {
                        "h2_edge": {
                            "start_vertex": "h2_MIDAT"
                        },
                        "elec_edge": {
                            "end_vertex": "elec_MIDAT",
                            "existing_capacity": 0,
                            "investment_cost": 41112.53426,
                            "fixed_om_cost": 1052.480877,
                            "variable_om_cost": 0.0,
                            "capacity_size": 1.5752,
                            "ramp_up_fraction": 1,
                            "ramp_down_fraction": 1,
                            "min_flow_fraction": 0.1
                        }
                    }
                },
                {
                    "id": "NE_FuelCell",
                    "transforms": {
                        "efficiency_rate": 0.875111139
                    },
                    "edges": {
                        "h2_edge": {
                            "start_vertex": "h2_NE"
                        },
                        "elec_edge": {
                            "end_vertex": "elec_NE",
                            "existing_capacity": 0,
                            "investment_cost": 41112.53426,
                            "fixed_om_cost": 1052.480877,
                            "variable_om_cost": 0.0,
                            "capacity_size": 1.5752,
                            "ramp_up_fraction": 1,
                            "ramp_down_fraction": 1,
                            "min_flow_fraction": 0.1
                        }
                    }
                }
            ]
        }
    ]
}
```