# Natural Gas DAC

## Graph structure
A natural gas DAC is represented in MACRO using the following graph structure:

```@raw html
<img width="400" src="../../images/natgasdac.png" />
```

A natural gas DAC asset is made of:

- 1 `Transformation` component, representing the natural gas DAC process.
- 5 `Edge` components:
    - 1 **incoming** `NaturalGas` `Edge`, representing the natural gas supply.
    - 1 **incoming** `CO2` `Edge`, representing the CO2 that is absorbed by the natural gas DAC process.
    - 1 **outgoing** `Electricity` `Edge`, representing the electricity production.
    - 1 **outgoing** `CO2Captured` `Edge`, representing the CO2 that is captured.
    - 1 **outgoing** `CO2` `Edge`, representing the CO2 that is emitted.

## Attributes
The structure of the input file for a natural gas DAC asset follows the graph representation. Each `global_data` and `instance_data` will look like this:

```json
{
    "transforms":{
        // ... transformation-specific attributes ...
    },
    "edges":{
        "ng_edge": {
            // ... ng_edge-specific attributes ...
        },
        "co2_edge": {
            // ... co2_edge-specific attributes ...
        },
        "elec_edge": {
            // ... elec_edge-specific attributes ...
        },
        "co2_emission_edge": {
            // ... co2_emission_edge-specific attributes ...
        },
        "co2_captured_edge": {
            // ... co2_captured_edge-specific attributes ...
        }
    }
}
```

### Transformation
The definition of the transformation object can be found here [Macro.Transformation](@ref).

| **Attribute** |  **Type** | **Values** | **Default** | **Description/Units** |
|:--------------| :------: | :------: | :------: |:-------|
| **timedata** | `String` | `String` | Required | Time resolution for the time series data linked to the transformation. E.g. "NaturalGas". |
| **constraints** | `Dict{String,Bool}` | Any MACRO constraint type for vertices| Empty | List of constraints applied to the transformation. E.g. `{"BalanceConstraint": true}`. |
| **capture_rate** $\epsilon_{co2\_capture\_rate}$ | `Float64` | `Float64` | 1.0 | $t_{CO2}/MWh_{ng}$ |
| **electricity_production** $\epsilon_{elec\_prod}$ | `Float64` | `Float64` | 0.0 | $MWh_{elec}/MWh_{ng}$ |
| **emission_rate** $\epsilon_{emission\_rate}$ | `Float64` | `Float64` | 1.0 | $t_{CO2}/MWh_{ng}$ |
| **fuel_consumption** $\epsilon_{fuel\_consumption}$ | `Float64` | `Float64` | 1.0 | $MWh_{ng}/t_{CO2}$ |

!!! tip "Default constraints"
    The **default constraint** for the transformation part of the natural gas DAC asset is the following:
    - [Balance constraint](@ref)

#### Flow equations
In the following equations, $\phi$ is the flow of the commodity and $\epsilon$ is the stoichiometric coefficient defined in the transformation table below.

!!! note "NaturalGasDAC"
    ```math
    \begin{aligned}
    \phi_{elec} &= \phi_{co2} \cdot \epsilon_{elec\_prod} \\
    \phi_{ng} &= -\phi_{co2} \cdot \epsilon_{fuel\_consumption} \\
    \phi_{co2} &= \phi_{ng} \cdot \epsilon_{emission\_rate} \\
    \phi_{co2\_captured} + \phi_{co2} &= \phi_{ng} \cdot \epsilon_{co2\_capture\_rate} \\
    \end{aligned}
    ```


### Edges
!!! warning "Asset expansion"
    As a modeling decision, only the incoming `CO2` edge is allowed to expand. Therefore, the `has_capacity` attribute can only be set for this edge. For all the other edges, this attribute is pre-set to `false` to ensure the correct modeling of the asset. 

!!! warning "Directionality"
    The `unidirectional` attribute is only available for the incoming `CO2` edge. For the other edges, this attribute is pre-set to `true` to ensure the correct modeling of the asset. 

The definition of the `Edge` object can be found here [Macro.Edge](@ref).

| **Attribute** | **Type** | **Values** | **Default** | **Description** |
|:--------------| :------: |:------: | :------: |:-------|
| **type** | `String` | Any MACRO commodity type matching the commodity of the edge | Required | Commodity of the edge. E.g. "Electricity". |
| **start_vertex** | `String` | Any node id present in the system matching the commodity of the edge | Required | ID of the starting vertex of the edge. The node must be present in the `nodes.json` file. E.g. "natgas\_node\_1". |
| **end_vertex** | `String` | Any node id present in the system matching the commodity of the edge | Required | ID of the ending vertex of the edge. The node must be present in the `nodes.json` file. E.g. "elec\_node\_1". |
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
| **max\_capacity** | `Float64` | `Float64` | `Inf` | Maximum allowed capacity of the edge (MW). **Note: add the `MaxCapacityConstraint` to the constraints dictionary to activate this constraint**. |
| **min\_capacity** | `Float64` | `Float64` | `0.0` | Minimum allowed capacity of the edge (MW). **Note: add the `MinCapacityConstraint` to the constraints dictionary to activate this constraint**. |
| **min\_flow\_fraction** | `Float64` | Number $\in$ [0,1] | `0.0` | Minimum flow of the edge as a fraction of the total capacity. **Note: add the `MinFlowConstraint` to the constraints dictionary to activate this constraint**. |
| **ramp\_down\_fraction** | `Float64` | Number $\in$ [0,1] | `1.0` | Maximum decrease in flow between two time steps, reported as a fraction of the capacity. **Note: add the `RampingLimitConstraint` to the constraints dictionary to activate this constraint**. |
| **ramp\_up\_fraction** | `Float64` | Number $\in$ [0,1] | `1.0` | Maximum increase in flow between two time steps, reported as a fraction of the capacity. **Note: add the `RampingLimitConstraint` to the constraints dictionary to activate this constraint**. |
| **unidirectional** | `Bool` | `Bool` | `false` | Whether the edge is unidirectional. |
| **variable\_om\_cost** | `Float64` | `Float64` | `0.0` | Variable operation and maintenance cost (USD/MWh). |

!!! tip "Default constraints"
    The only **default constraint** for the edges of the natural gas DAC asset is the [Capacity constraint](@ref) applied to the incoming `CO2` edge. 

## Example

The following input file example shows how to create a natural gas DAC asset in each of the three zones NE, SE and MIDAT.

```json
{
    "NaturalGasDAC": [
        {
            "type": "NaturalGasDAC",
            "global_data": {
                "transforms": {
                    "timedata": "NaturalGas",
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
                        "integer_decisions": false,
                        "uc": false,
                        "constraints": {
                            "CapacityConstraint": true,
                            "RampingLimitConstraint": true
                        }
                    },
                    "co2_emission_edge": {
                        "type": "CO2",
                        "unidirectional": true,
                        "has_capacity": false,
                        "end_vertex": "co2_sink"
                    },
                    "ng_edge": {
                        "type": "NaturalGas",
                        "unidirectional": true,
                        "has_capacity": false
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
                    "id": "SE_Sorbent_DAC",
                    "transforms": {
                        "emission_rate": 0.005516648,
                        "capture_rate": 0.546148172,
                        "electricity_production": 0.125,
                        "fuel_consumption": 3.047059915
                    },
                    "edges": {
                        "co2_edge": {
                            "availability": {
                                "timeseries": {
                                    "path": "assets/availability.csv",
                                    "header": "SE_Sorbent_DAC"
                                }
                            },
                            "existing_capacity": 0.0,
                            "investment_cost": 869000.00,
                            "fixed_om_cost": 384000.00,
                            "variable_om_cost": 58.41,
                            "ramp_up_fraction": 1.0,
                            "ramp_down_fraction": 1.0
                        },
                        "ng_edge": {
                            "start_vertex": "natgas_SE"
                        },
                        "elec_edge": {
                            "end_vertex": "elec_SE"
                        }
                    }
                },
                {
                    "id": "MIDAT_Sorbent_DAC",
                    "transforms": {
                        "emission_rate": 0.005516648,
                        "capture_rate": 0.546148172,
                        "electricity_production": 0.125,
                        "fuel_consumption": 3.047059915
                    },
                    "edges": {
                        "co2_edge": {
                            "availability": {
                                "timeseries": {
                                    "path": "assets/availability.csv",
                                    "header": "MIDAT_Sorbent_DAC"
                                }
                            },
                            "existing_capacity": 0.0,
                            "investment_cost": 869000.00,
                            "fixed_om_cost": 384000.00,
                            "variable_om_cost": 58.41,
                            "ramp_up_fraction": 1.0,
                            "ramp_down_fraction": 1.0
                        },
                        "ng_edge": {
                            "start_vertex": "natgas_MIDAT"
                        },
                        "elec_edge": {
                            "end_vertex": "elec_MIDAT"
                        }
                    }
                },
                {
                    "id": "NE_Sorbent_DAC",
                    "transforms": {
                        "emission_rate": 0.005516648,
                        "capture_rate": 0.546148172,
                        "electricity_production": 0.125,
                        "fuel_consumption": 3.047059915
                    },
                    "edges": {
                        "co2_edge": {
                            "availability": {
                                "timeseries": {
                                    "path": "assets/availability.csv",
                                    "header": "NE_Sorbent_DAC"
                                }
                            },
                            "existing_capacity": 0.0,
                            "investment_cost": 869000.00,
                            "fixed_om_cost": 384000.00,
                            "variable_om_cost": 58.41,
                            "ramp_up_fraction": 1.0,
                            "ramp_down_fraction": 1.0
                        },
                        "ng_edge": {
                            "start_vertex": "natgas_NE"
                        },
                        "elec_edge": {
                            "end_vertex": "elec_NE"
                        }
                    }
                }
            ]
        }
    ]
}
```