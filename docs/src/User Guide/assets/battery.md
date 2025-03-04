# Battery

## Graph structure
A battery is a storage technology that is represented in Macro by the following graph structure:

```@raw html
<img width="270" src="../../images/battery.png" />
```

Therefore, a battery asset is made of:

- 1 `Storage` component, representing the battery storage.
- 2 `Electricity` `Edge` components:
    - one **incoming** representing the charge edge from the electricity network to the storage.
    - one **outgoing** representing the discharge edge from the storage to the electricity network.

## Attributes
As for all the other assets, the structure of the input file for a battery asset follows the graph representation. Each `global_data` and `instance_data` will look like this:

```json
{
    "storage":{
        // ... storage-specific attributes ...
    },
    "edges":{
        "charge_edge": {
            // ... charge_edge-specific attributes ...
        },
        "discharge_edge": {
            // ... discharge_edge-specific attributes ...
        }
    }
}
```
where the possible attributes that the user can set are reported in the following tables. 

### Storage component
The definition of the `Storage` object can be found here [MacroEnergy.Storage](@ref).

| **Attribute** | **Type** | **Values** | **Default** | **Description** |
|:--------------| :------: |:------: | :------: |:-------|
| **commodity** | `String` | `Electricity` | Required | Commodity being stored. |
| **constraints** | `Dict{String,Bool}` | Any Macro constraint type for storage | `BalanceConstraint`, `StorageCapacityConstraint`, `StorageMaxDurationConstraint`, `StorageMinDurationConstraint`, `StorageSymmetricCapacityConstraint` | List of constraints applied to the storage. E.g. `{"BalanceConstraint": true}`. |
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
    As noted in the above table, the **default constraints** for the storage component of the battery are the following:

    - [Balance constraint](@ref)
    - [Storage capacity constraint](@ref)
    - [Storage max duration constraint](@ref)
    - [Storage min duration constraint](@ref)
    - [Storage symmetric capacity constraint](@ref)

### Charge and discharge edges
Both the charge and discharge edges are represented by the same set of attributes. The definition of the `Edge` object can be found here [MacroEnergy.Edge](@ref).

| **Attribute** | **Type** | **Values** | **Default** | **Description** |
|:--------------| :------: |:------: | :------: |:-------|
| **type** | `String` | `Electricity` | Required | Commodity of the edge. E.g. "Electricity". |
| **start_vertex** | `String` | Any electricity node id present in the system | Required | ID of the starting vertex of the edge. The node must be present in the `nodes.json` file. E.g. "elec\_node\_1". |
| **end_vertex** | `String` | Any electricity node id present in the system | Required | ID of the ending vertex of the edge. The node must be present in the `nodes.json` file. E.g. "elec\_node\_2". |
| **constraints** | `Dict{String,Bool}` | Any Macro constraint type for Edges | Empty | List of constraints applied to the edge. E.g. `{"CapacityConstraint": true}`. |
| **can_expand** | `Bool` | `Bool` | `false` | Whether the edge is eligible for capacity expansion. |
| **can_retire** | `Bool` | `Bool` | `false` | Whether the edge is eligible for capacity retirement. |
| **efficiency** | `Float64` | Number $\in$ [0,1] | `1.0` | Efficiency of the charging/discharging process. |
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

!!! tip "Efficiency"
    The efficiency of the charging/discharging process can be set in the `charge_edge` and `discharge_edge` parts of the input file. These parameters are used, for example, in the [Balance constraint](@ref) to balance the charge and discharge flows. 

!!! tip "Default constraints"
    The **default constraints** for the discharge edge are the following:

    - [Capacity constraint](@ref)
    - [Storage discharge limit constraint](@ref)
    - [Ramping limits constraint](@ref)

## Example
The following is an example of the input file for a battery asset that creates three batteries, one in each of the SE, MIDAT and NE regions.

```json
{
    "elec_stor": [
        {
            "type": "Battery",
            "global_data": {
                "storage": {
                    "commodity": "Electricity",
                    "can_expand": true,
                    "can_retire": false,
                    "constraints": {
                        "StorageCapacityConstraint": true,
                        "StorageSymmetricCapacityConstraint": true,
                        "StorageMinDurationConstraint": true,
                        "StorageMaxDurationConstraint": true,
                        "BalanceConstraint": true
                    }
                },
                "edges": {
                    "discharge_edge": {
                        "type": "Electricity",
                        "unidirectional": true,
                        "has_capacity": true,
                        "can_expand": true,
                        "can_retire": false,
                        "constraints": {
                            "CapacityConstraint": true,
                            "StorageDischargeLimitConstraint": true
                        }
                    },
                    "charge_edge": {
                        "type": "Electricity",
                        "unidirectional": true,
                        "has_capacity": false
                    }
                }
            },
            "instance_data": [
                {
                    "id": "battery_SE",
                    "edges": {
                        "discharge_edge": {
                            "end_vertex": "elec_SE",
                            "capacity_size": 1.0,
                            "existing_capacity": 0.0,
                            "fixed_om_cost": 4536.98,
                            "investment_cost": 17239.56121,
                            "variable_om_cost": 0.15,
                            "efficiency": 0.92
                        },
                        "charge_edge": {
                            "start_vertex": "elec_SE",
                            "efficiency": 0.92,
                            "variable_om_cost": 0.15
                        }
                    },
                    "storage": {
                        "existing_capacity_storage": 0.0,
                        "fixed_om_cost_storage": 2541.19,
                        "investment_cost_storage": 9656.002735,
                        "max_duration": 10,
                        "min_duration": 1
                    }
                },
                {
                    "id": "battery_MIDAT",
                    "edges": {
                        "discharge_edge": {
                            "end_vertex": "elec_SE",
                            "capacity_size": 1.0,
                            "existing_capacity": 0.0,
                            "fixed_om_cost": 4536.98,
                            "investment_cost": 17239.56121,
                            "variable_om_cost": 0.15,
                            "efficiency": 0.92
                        },
                        "charge_edge": {
                            "start_vertex": "elec_SE",
                            "efficiency": 0.92,
                            "variable_om_cost": 0.15
                        }
                    },
                    "storage": {
                        "existing_capacity_storage": 0.0,
                        "fixed_om_cost_storage": 2541.19,
                        "investment_cost_storage": 9656.002735,
                        "max_duration": 10,
                        "min_duration": 1
                    }
                },
                {
                    "id": "battery_NE",
                    "edges": {
                        "discharge_edge": {
                            "end_vertex": "elec_SE",
                            "capacity_size": 1.0,
                            "existing_capacity": 0.0,
                            "fixed_om_cost": 4536.98,
                            "investment_cost": 17239.56121,
                            "variable_om_cost": 0.15,
                            "efficiency": 0.92
                        },
                        "charge_edge": {
                            "start_vertex": "elec_SE",
                            "efficiency": 0.92,
                            "variable_om_cost": 0.15
                        }
                    },
                    "storage": {
                        "existing_capacity_storage": 0.0,
                        "fixed_om_cost_storage": 2541.19,
                        "investment_cost_storage": 9656.002735,
                        "max_duration": 10,
                        "min_duration": 1
                    }
                }
            ]
        }
    ]
}
```