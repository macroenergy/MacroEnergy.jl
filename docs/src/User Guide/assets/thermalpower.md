# Thermal Power Plant (with and without CCS)

## Graph structure
A thermal power plant (with and without CCS) is represented in MACRO using the following graph structure:

```@raw html
<img width="400" src="../../images/thermalpower.png" />
```

A thermal power plant (with and without CCS) is made of:
- 1 `Transformation` component, representing the thermal power plant (with and without CCS).
- 4 `Edge` components:
    - 1 **incoming** `Fuel` `Edge`, representing the fuel supply. 
    - 1 **outgoing** `Electricity` `Edge`, representing the electricity production. **This edge can have unit commitment operations**.
    - 1 **outgoing** `CO2` `Edge`, representing the CO2 that is emitted.
    - 1 **outgoing** `CO2Captured` `Edge`, representing the CO2 that is captured **(only if CCS is present)**.

## Attributes
The structure of the input file for a ThermalPower asset follows the graph representation. Each `global_data` and `instance_data` will look like this:

```json
{
    "transforms":{
        // ... transformation-specific attributes ...
    },
    "edges":{
        "fuel_edge": {
            // ... fuel_edge-specific attributes ...
        },
        "elec_edge": {
            // ... elec_edge-specific attributes ...
        },
        "co2_edge": {
            // ... co2_edge-specific attributes ...
        },
        "co2_captured_edge": {
            // ... co2_captured_edge-specific attributes, only if CCS is present ...
        }
    }
}
```

### Transformation
The definition of the transformation object can be found here [Macro.Transformation](@ref).

| **Attribute** | **Type** | **Values** | **Default** | **Description/Units** |
|:--------------| :------: |:------: | :------: |:-------|
| **timedata** | `String` | `String` | Required | Time resolution for the time series data linked to the transformation. E.g. "NaturalGas". |
| **constraints** | `Dict{String,Bool}` | Any MACRO constraint type for vertices| Empty | List of constraints applied to the transformation. E.g. `{"BalanceConstraint": true}`. |
| **efficiency_rate** $\epsilon_{efficiency}$ | `Float64` | `Float64` | 1.0 | $MWh_{elec}/MWh_{fuel}$|
| **emission_rate** $\epsilon_{emission\_rate}$ | `Float64` | `Float64` | 1.0 | $t_{CO2}/MWh_{fuel}$ |
| **capture_rate** $\epsilon_{co2\_capture\_rate}$ | `Float64` | `Float64` | 1.0 | $t_{CO2}/MWh_{fuel}$ |

!!! tip "Default constraints"
    The **default constraint** for the transformation part of the thermal power asset is the following:
    - [Balance constraint](@ref)

#### Flow equations
In the following equations, $\phi$ is the flow of the commodity and $\epsilon$ is the stoichiometric coefficient defined in the transformation table below.

!!! note "ThermalPower"
    **Note**: Fuel is the type of the fuel being converted.
    ```math
    \begin{aligned}
    \phi_{elec} &= \phi_{fuel} \cdot \epsilon_{efficiency} \\
    \phi_{co2} &= \phi_{fuel} \cdot \epsilon_{emission\_rate} \\
    \phi_{co2\_captured} &= \phi_{fuel} \cdot \epsilon_{co2\_capture\_rate} \quad \text{(if CCS)} \\
    \end{aligned}
    ```

### Edges
!!! warning "Asset expansion"
    As a modeling decision, only the `Electricity` and `Fuel` edges are allowed to expand. Therefore, both the `has_capacity` and `constraints` attributes can only be set for those edges. For all the other edges, these attributes are pre-set to `false` and to an empty list respectively to ensure the correct modeling of the asset. 

!!! warning "Directionality"
    The `unidirectional` attribute is set to `true` for all the edges.

!!! note "Unit commitment and default constraints"
    The `Electricity` edge **can have unit commitment operations**. To enable it, the user needs to set the `uc` attribute to `true`. The default constraints for unit commitment case are the following:
    - [Capacity constraint](@ref)
    - [Ramping limits constraint](@ref)
    - [Minimum up and down time constraint](@ref)

    In case of no unit commitment, the `uc` attribute is set to `false` and the default constraints are the following:
    - [Capacity constraint](@ref)

All the edges are represented by the same set of attributes. The definition of the `Edge` object can be found here [Macro.Edge](@ref).

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
| **has\_capacity** | `Bool` | `Bool` | `false` | Whether capacity variables are created for the edge **(only available for the `Hydrogen` and `Fuel` edges)**. |
| **integer\_decisions** | `Bool` | `Bool` | `false` | Whether capacity variables are integers. |
| **investment\_cost** | `Float64` | `Float64` | `0.0` | Annualized capacity investment cost (USD/MW-year) |
| **loss\_fraction** | `Float64` | Number $\in$ [0,1] | `0.0` | Fraction of transmission loss. |
| **max\_capacity** | `Float64` | `Float64` | `Inf` | Maximum allowed capacity of the edge (MW). **Note: add the `MaxCapacityConstraint` to the constraints dictionary to activate this constraint**. |
| **min\_capacity** | `Float64` | `Float64` | `0.0` | Minimum allowed capacity of the edge (MW). **Note: add the `MinCapacityConstraint` to the constraints dictionary to activate this constraint**. |
| **min\_flow\_fraction** | `Float64` | Number $\in$ [0,1] | `0.0` | Minimum flow of the edge as a fraction of the total capacity. **Note: add the `MinFlowConstraint` to the constraints dictionary to activate this constraint**. |
| **min\_down\_time** | `Int64` | `Int64` | `0` | Minimum amount of time the edge has to remain in the shutdown state before starting up again. **Note: add the `MinDownTimeConstraint` to the constraints dictionary to activate this constraint**. |
| **min\_up\_time** | `Int64` | `Int64` | `0` | Minimum amount of time the edge has to remain in the committed state. **Note: add the `MinUpTimeConstraint` to the constraints dictionary to activate this constraint**. |
| **ramp\_down\_fraction** | `Float64` | Number $\in$ [0,1] | `1.0` | Maximum decrease in flow between two time steps, reported as a fraction of the capacity. **Note: add the `RampingLimitConstraint` to the constraints dictionary to activate this constraint**. |
| **ramp\_up\_fraction** | `Float64` | Number $\in$ [0,1] | `1.0` | Maximum increase in flow between two time steps, reported as a fraction of the capacity. **Note: add the `RampingLimitConstraint` to the constraints dictionary to activate this constraint**. |
| **startup\_cost** | `Float64` | `Float64` | `0.0` | Cost per MW of capacity to start a generator (USD/MW per start). |
| **startup\_fuel** | `Float64` | `Float64` | `0.0` | Startup fuel use per MW of capacity (MWh/MW per start). |
| **variable\_om\_cost** | `Float64` | `Float64` | `0.0` | Variable operation and maintenance cost (USD/MWh). |

## Example
The following is an example of the input file for a ThermalPowerCCS asset that creates three ThermalPowerCCS assets, one in each of the SE, MIDAT and NE regions.

```json
{
    "NaturalGasPowerCCS": [
        {
            "type": "ThermalPowerCCS",
            "global_data": {
                "transforms": {
                    "timedata": "NaturalGas",
                    "constraints": {
                        "BalanceConstraint": true
                    }
                },
                "edges": {
                    "elec_edge": {
                        "type": "Electricity",
                        "uc": true,
                        "unidirectional": true,
                        "has_capacity": true,
                        "can_expand": true,
                        "can_retire": true,
                        "integer_decisions": false,
                        "constraints": {
                            "CapacityConstraint": true,
                            "RampingLimitConstraint": true,
                            "MinFlowConstraint": true,
                            "MinUpTimeConstraint": true,
                            "MinDownTimeConstraint": true
                        }
                    },
                    "fuel_edge": {
                        "type": "NaturalGas",
                        "unidirectional": true,
                        "has_capacity": false
                    },
                    "co2_edge": {
                        "type": "CO2",
                        "unidirectional": true,
                        "has_capacity": false,
                        "end_vertex": "co2_sink"
                    },
                    "co2_captured_edge": {
                        "type": "CO2Captured",
                        "unidirectional": true,
                        "has_capacity": false,
                        "end_vertex": "co2_captured_sink"
                    }
                },
            },
            "instance_data": [
                {
                    "id": "SE_naturalgas_ccccsavgcf_conservative_0",
                    "transforms": {
                        "efficiency_rate": 0.476622662,
                        "emission_rate": 0.018104824,
                        "capture_rate": 0.162943412
                    },
                    "edges": {
                        "elec_edge": {
                            "end_vertex": "elec_SE",
                            "investment_cost": 150408.6558,
                            "existing_capacity": 0.0,
                            "fixed_om_cost": 65100,
                            "variable_om_cost": 5.73,
                            "capacity_size": 377,
                            "startup_cost": 97,
                            "startup_fuel": 0.058614214,
                            "min_up_time": 4,
                            "min_down_time": 4,
                            "ramp_up_fraction": 1,
                            "ramp_down_fraction": 1,
                            "min_flow_fraction": 0.5
                        },
                        "fuel_edge": {
                            "start_vertex": "natgas_SE"
                        }
                    }
                },
                {
                    "id": "MIDAT_naturalgas_ccccsavgcf_conservative_0",
                    "transforms": {
                        "efficiency_rate": 0.476622662,
                        "emission_rate": 0.018104824,
                        "capture_rate": 0.162943412
                    },
                    "edges": {
                        "elec_edge": {
                            "end_vertex": "elec_MIDAT",
                            "investment_cost": 158946.1077,
                            "existing_capacity": 0.0,
                            "fixed_om_cost": 65100,
                            "variable_om_cost": 5.73,
                            "capacity_size": 377,
                            "startup_cost": 97,
                            "startup_fuel": 0.058614214,
                            "min_up_time": 4,
                            "min_down_time": 4,
                            "ramp_up_fraction": 1,
                            "ramp_down_fraction": 1,
                            "min_flow_fraction": 0.5
                        },
                        "fuel_edge": {
                            "start_vertex": "natgas_MIDAT"
                        }
                    }
                },
                {
                    "id": "NE_naturalgas_ccccsavgcf_conservative_0",
                    "transforms": {
                        "efficiency_rate": 0.476622662,
                        "emission_rate": 0.018104824,
                        "capture_rate": 0.162943412
                    },
                    "edges": {
                        "elec_edge": {
                            "end_vertex": "elec_NE",
                            "investment_cost": 173266.9946,
                            "existing_capacity": 0.0,
                            "fixed_om_cost": 65100,
                            "variable_om_cost": 5.73,
                            "capacity_size": 377,
                            "startup_cost": 97,
                            "startup_fuel": 0.058614214,
                            "min_up_time": 4,
                            "min_down_time": 4,
                            "ramp_up_fraction": 1,
                            "ramp_down_fraction": 1,
                            "min_flow_fraction": 0.5
                        },
                        "fuel_edge": {
                            "start_vertex": "natgas_NE"
                        }
                    }
                }
            ]
        }
    ]
}
```