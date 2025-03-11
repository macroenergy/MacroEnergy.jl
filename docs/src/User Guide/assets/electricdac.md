# Electric DAC

## Graph structure
An electric direct air capture (DAC) asset is represented in Macro using the following graph structure:

```@raw html
<img width="400" src="../../images/elecdac.png" />
```

An electric DAC asset is made of:

- 1 `Transformation` component, representing the DAC process.
- 3 `Edge` components:
    - 1 **incoming** `Electricity` `Edge`, representing the electricity consumption.
    - 1 **incoming** `CO2` `Edge`, representing the CO2 that is captured.
    - 1 **outgoing** `CO2 Captured` `Edge`, representing the CO2 that is captured.

## Attributes
The structure of the input file for an electric DAC asset follows the graph representation. Each `global_data` and `instance_data` will look like this:

```json
{
    "transforms":{
        // ... transformation-specific attributes ...
    },
    "edges":{
        "elec_edge": {
            // ... elec_edge-specific attributes ...
        },
        "co2_edge": {
            // ... co2_edge-specific attributes ...
        },
        "co2_captured_edge": {
            // ... co2_captured_edge-specific attributes ...
        }
    }
}
```

### Transformation

The definition of the transformation object can be found here [MacroEnergy.Transformation](@ref).

| **Attribute** | **Type** | **Values** | **Default** | **Description/Units** |
|:--------------| :------: |:------: | :------: |:-------|
| **timedata** | `String` | `String` | Required | Time resolution for the time series data linked to the transformation. E.g. "Electricity". |
| **constraints** | `Dict{String,Bool}` | Any Macro constraint type for vertices| `BalanceConstraint` | List of constraints applied to the transformation. E.g. `{"BalanceConstraint": true}`. |
| **electricity_consumption** $\epsilon_{elec\_consumption}$ | `Float64` | `Float64` | 0.0 | $MWh_{elec}/t_{CO2}$ |

!!! tip "Default constraints"
    The **default constraint** for the transformation part of the ElectricDAC asset is the following:
    - [Balance constraint](@ref)

#### Flow equations
In the following equations, $\phi$ is the flow of the commodity and $\epsilon$ is the stoichiometric coefficient defined in the transformation table below.

!!! note "ElectricDAC"
    ```math
    \begin{aligned}
    \phi_{elec} &= \phi_{co2\_captured} \cdot \epsilon_{elec\_consumption} \\
    \phi_{co2} &= \phi_{co2\_captured} \\
    \end{aligned}
    ```

### Edge
Both the incoming and outgoing edges are represented by the same set of attributes. The definition of the `Edge` object can be found here [MacroEnergy.Edge](@ref).

| **Attribute** | **Type** | **Values** | **Default** | **Description** |
|:--------------| :------: |:------: | :------: |:-------|
| **type** | `String` | Any Macro commodity type matching the commodity of the edge | Required | Commodity of the edge. E.g. "Electricity". |
| **start_vertex** | `String` | Any node id present in the system matching the commodity of the edge | Required | ID of the starting vertex of the edge. The node must be present in the `nodes.json` file. E.g. "elec\_node\_1". |
| **end_vertex** | `String` | Any node id present in the system matching the commodity of the edge | Required | ID of the ending vertex of the edge. The node must be present in the `nodes.json` file. E.g. "elec\_node\_2". |
| **constraints** | `Dict{String,Bool}` | Any Macro constraint type for Edges | Check box below | List of constraints applied to the edge. E.g. `{"CapacityConstraint": true}`. |
| **availability** | `Dict` | Availability file path and header | Empty | Path to the availability file and column name for the availability time series to link to the edge. E.g. `{"timeseries": {"path": "assets/availability.csv", "header": "Availability_MW_z1"}}`.|
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
    The only **default constraint** for the edges of the ElectricDAC asset is the [Capacity constraint](@ref) applied to the CO2 edge. 

## Example
The following is an example of the input file for an ElectricDAC asset that creates three electric DAC units, each for a different region.

```json
{
    "ElectricDAC": [
        {
            "type": "ElectricDAC",
            "global_data": {
                "transforms": {
                    "timedata": "Electricity",
                    "constraints": {
                        "BalanceConstraint": true
                    }
                },
                "edges": {
                    "co2_edge": {
                        "type": "CO2",
                        "unidirectional": true,
                        "has_capacity": true,
                        "start_vertex": "co2_sink",
                        "can_retire": true,
                        "can_expand": true,
                        "uc": false,
                        "constraints": {
                            "CapacityConstraint": true,
                            "RampingLimitConstraint": true
                        },
                        "integer_decisions": false
                    },
                    "elec_edge": {
                        "type": "Electricity",
                        "unidirectional": true,
                        "has_capacity": false
                    },
                    "co2_captured_edge": {
                        "type": "CO2Captured",
                        "unidirectional": true,
                        "has_capacity": false,
                        "end_vertex": "co2_captured_sink"
                    }
                }
            },
            "instance_data": [
                {
                    "id": "SE_Solvent_DAC",
                    "transforms": {
                        "electricity_consumption": 4.38
                    },
                    "edges": {
                        "co2_edge": {
                            "availability": {
                                "timeseries": {
                                    "path": "assets/availability.csv",
                                    "header": "SE_Solvent_DAC"
                                }
                            },
                            "existing_capacity": 0.0,
                            "investment_cost": 939000.00,
                            "fixed_om_cost": 747000.00,
                            "variable_om_cost": 22.00,
                            "ramp_up_fraction": 1.0,
                            "ramp_down_fraction": 1.0
                        },
                        "elec_edge": {
                            "start_vertex": "elec_SE"
                        }
                    }
                },
                {
                    "id": "MIDAT_Solvent_DAC",
                    "transforms": {
                        "electricity_consumption": 4.38
                    },
                    "edges": {
                        "co2_edge": {
                            "availability": {
                                "timeseries": {
                                    "path": "assets/availability.csv",
                                    "header": "MIDAT_Solvent_DAC"
                                }
                            },
                            "existing_capacity": 0.0,
                            "investment_cost": 939000.00,
                            "fixed_om_cost": 747000.00,
                            "variable_om_cost": 22.00,
                            "ramp_up_fraction": 1.0,
                            "ramp_down_fraction": 1.0
                        },
                        "elec_edge": {
                            "start_vertex": "elec_MIDAT"
                        }
                    }
                },
                {
                    "id": "NE_Solvent_DAC",
                    "transforms": {
                        "electricity_consumption": 4.38
                    },
                    "edges": {
                        "co2_edge": {
                            "availability": {
                                "timeseries": {
                                    "path": "assets/availability.csv",
                                    "header": "NE_Solvent_DAC"
                                }
                            },
                            "existing_capacity": 0.0,
                            "investment_cost": 939000.00,
                            "fixed_om_cost": 747000.00,
                            "variable_om_cost": 22.00,
                            "ramp_up_fraction": 1.0,
                            "ramp_down_fraction": 1.0
                        },
                        "elec_edge": {
                            "start_vertex": "elec_NE"
                        }
                    }
                }
            ]
        }
    ]
}
```