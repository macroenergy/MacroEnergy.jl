# Battery

## Contents

[Overview](@ref battery_overview) | [Asset Structure](@ref battery_asset_structure) | [Symmetric and Asymmetric Battery](@ref battery_symmetric_and_asymmetric) | [Input File (Standard Format)](@ref battery_input_file) | [Types - Asset Structure](@ref battery_type_definition) | [Constructors](@ref battery_constructors) | [Examples](@ref battery_examples) | [Best Practices](@ref battery_best_practices) | [Input File (Advanced Format)](@ref battery_advanced_json_csv_input_format)

## [Overview](@id battery_overview)

Battery assets in Macro represent electricity storage technologies that can charge from and discharge to the electricity network. These assets are defined using either JSON or CSV input files placed in the `assets` directory, typically named `electricity_stor.json` or `electricity_stor.csv`.

## [Asset Structure](@id battery_asset_structure)

A battery storage asset consists of three main components:

1. **Storage Component**: Tracks the energy level in the battery over time
2. **Charge Edge**: Represents electricity flow from the grid to the battery
3. **Discharge Edge**: Represents electricity flow from the battery to the grid

Here is a graphical representation of the battery asset:

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'background': '#D1EBDE' }}}%%
flowchart LR
  subgraph Battery
  direction BT
    A((Electricity)) e1@-->|Charge| B[Storage]
    B e2@-->|Discharge| A
    e1@{ animate: true }
    e2@{ animate: true }
 end
    style A font-size:19px,r:55px,fill:#FFD700,stroke:black,color:black,stroke-dasharray: 3,5;
    style B fill:#FFD700,stroke:black,color:black;
    linkStyle 0,1 stroke:#FFD700, stroke-width: 2px;
```

## [Symmetric and Asymmetric Battery](@id battery_symmetric_and_asymmetric)

Macro supports a variety of battery technologies, both with symmetric and asymmetric charge/discharge capacities. Examples of symmetric batteries are lithium-ion batteries, while asymmetric batteries are thermal storage systems.

The user can configure the battery asset to be symmetric or asymmetric simply by using the input file as described in the following section. By default, the battery asset is configured to be symmetric.

## [Input File (Standard Format)](@id battery_input_file)

The easiest way to include a battery asset in a model is to create a new file (either JSON or CSV) and place it in the `assets` directory together with the other assets. 

```
your_case/
├── assets/
│   ├── electricity_stor.json    # or electricity_stor.csv
│   ├── other_assets.json
│   └── ...
├── system/
├── settings/
└── ...
```

This file can either be created manually, or using the `template_asset` function, as shown in the [Adding an Asset to a System](@ref) section of the User Guide. The file will be automatically loaded when you run your Macro model. 

The following is an example of a battery asset input file:
```json
{
    "elec_stor": [
        {
            "type": "Battery",
            "global_data": {
                "storage_constraints": {
                    "StorageMinDurationConstraint": true,
                    "StorageMaxDurationConstraint": true,
                }
            },
            "instance_data": [
                {
                    "id": "battery_1_SE",
                    "location": "SE",
                    "storage_investment_cost": 10000,
                    "storage_fixed_om_cost": 500,
                    "storage_max_duration": 10,
                    "storage_min_duration": 1,
                    "discharge_investment_cost": 20000,
                    "discharge_fixed_om_cost": 1000,
                    "discharge_variable_om_cost": 1,
                    "charge_variable_om_cost": 1,
                    "discharge_efficiency": 0.95,
                    "charge_efficiency": 0.95
                }
            ]
        }
    ]
}
```

!!! tip "Global Data vs Instance Data"
    When working with JSON input files, the `global_data` field can be used to group data that is common to all instances of the same asset type. This is useful for setting constraints that are common to all instances of the same asset type and avoid repeating the same data for each instance. See the [Examples](@ref "battery_examples") section below for an example.

The following tables outlines the attributes that can be set for a battery asset.

### Essential Attributes
| Field | Type | Description |
|--------------|---------|------------|
| `type` | String | Asset type identifier: "Battery" |
| `id` | String | Unique identifier for the battery instance |
| `location` | String | Geographic location/node identifier |

### [Constraints configuration](@id "battery_constraints")
Battery assets can have different constraints applied to them, and the user can configure them using the following fields:

| Field | Type | Description |
|--------------|---------|------------|
| `storage_constraints` | Dict{String,Bool} | List of constraints applied to the storage component. |
| `discharge_constraints` | Dict{String,Bool} | List of constraints applied to the discharge edge. |
| `charge_constraints` | Dict{String,Bool} | List of constraints applied to the charge edge. |

For example, if the user wants to apply the [`StorageMinDurationConstraint`](@ref storage_min_duration_constraint_ref) to the storage component and the [`MinFlowConstraint`](@ref min_flow_constraint_ref) to the discharge edge, the `storage_constraints` and `discharge_constraints` fields should be set to `{"StorageMinDurationConstraint": true}` and `{"MinFlowConstraint": true}`, respectively:

```json
{
    "storage_constraints": {
        "StorageMinDurationConstraint": true
    },
    "discharge_constraints": {
        "MinFlowConstraint": true
    }
}
```

Users can refer to the [Adding Asset Constraints to a System](@ref) section of the User Guide for a list of all the constraints that can be applied to a battery asset.

#### Default constraints
To simplify the input file and the asset configuration, the following constraints are applied to the battery asset by default:

- [Balance constraint](@ref balance_constraint_ref) (applied to the storage component)
- [Storage capacity constraint](@ref storage_capacity_constraint_ref) (applied to the storage component)
- [Storage symmetric capacity constraint](@ref storage_symmetric_capacity_constraint_ref) (applied to the storage component)
- [Capacity constraint](@ref capacity_constraint_ref) (applied to the discharge edge)
- [Storage discharge limit constraint](@ref storage_discharge_limit_constraint_ref) (applied to the discharge edge)
- [Storage charge limit constraint](@ref storage_charge_limit_constraint_ref) (applied to the charge edge)

If the storage is a long-duration storage, the following additional constraints are applied:
- [Long-duration storage constraints](@ref long_duration_storage_constraints_ref) (applied to the storage component)

### Investment Parameters
| Field | Type | Description | Units | Default |
|--------------|---------|------------|----------------|----------|
| `storage_can_retire` | Boolean | Whether storage capacity can be retired | - | true |
| `storage_can_expand` | Boolean | Whether storage capacity can be expanded | - | true |
| `storage_existing_capacity` | Float64 | Initial installed storage capacity | MWh | 0.0 |
| `storage_capacity_size` | Float64 | Unit size for capacity decisions | - | 1.0 |
| `discharge_can_retire` | Boolean | Whether discharge capacity can be retired | - | true |
| `discharge_can_expand` | Boolean | Whether discharge capacity can be expanded | - | true |
| `discharge_existing_capacity` | Float64 | Initial installed discharge capacity | MWh/hr | 0.0 |
| `discharge_capacity_size` | Float64 | Unit size for capacity decisions | - | 1.0 |

#### Integer capacity decisions
Battery charge and discharge edges can be configured to build in integer multiples of `*_capacity_size`. This is controlled by the following fields:

| Field | Type | Description | Default |
|--------------|---------|------------|----------|
| `integer_decisions` | Boolean | Apply integer capacity decisions to both charge and discharge edges | false |
| `charge_integer_decisions` | Boolean | Apply integer capacity decisions to the charge edge only | false |
| `discharge_integer_decisions` | Boolean | Apply integer capacity decisions to the discharge edge only | false |

Notes:
- If `integer_decisions` is set, it applies to both edges unless overridden by `charge_integer_decisions` or `discharge_integer_decisions`.
- These flags apply to edge capacity decisions (MW). Storage energy capacity (MWh) remains continuous.

##### Asymmetric battery
If the battery is asymmetric, the following investment parameters are also used:

| Field | Type | Description | Units | Default |
|--------------|---------|------------|----------------|----------|
| `charge_has_capacity` | Boolean | Whether the charge edge has capacity variables and limits | - | false |
| `charge_can_retire` | Boolean | Whether charge capacity can be retired | - | false |
| `charge_can_expand` | Boolean | Whether charge capacity can be expanded | - | false |
| `charge_existing_capacity` | Float64 | Initial installed charge capacity | MWh/hr | 0.0 |
| `charge_capacity_size` | Float64 | Unit size for capacity decisions | - | 1.0 |

#### Additional Investment Parameters

**Maximum and minimum capacity constraints**

If [`MaxCapacityConstraint`](@ref max_capacity_constraint_ref) or [`MinCapacityConstraint`](@ref min_capacity_constraint_ref) are added to the constraints dictionary for any of the three components, the following parameters are used by Macro:

| Field | Type | Description | Units | Default |
|--------------|---------|------------|----------------|----------|
| `storage_max_capacity` | Float64 | Maximum allowed storage capacity | MWh | Inf |
| `storage_min_capacity` | Float64 | Minimum allowed storage capacity | MWh | 0.0 |
| `discharge_max_capacity` | Float64 | Maximum allowed discharge capacity | MWh/hr | Inf |
| `discharge_min_capacity` | Float64 | Minimum allowed discharge capacity | MWh/hr | 0.0 |
| `charge_max_capacity` | Float64 | Maximum allowed charge capacity | MWh/hr | Inf |
| `charge_min_capacity` | Float64 | Minimum allowed charge capacity | MWh/hr | 0.0 |

### Economic Parameters
| Field | Type | Description | Units | Default |
|--------------|---------|------------|----------------|----------|
| `storage_investment_cost` | Float64 | CAPEX per unit storage capacity | \$/MWh | 0.0 |
| `storage_annualized_investment_cost` | Union{Nothing,Float64} | Annualized CAPEX | \$/MWh/yr | calculated |
| `storage_fixed_om_cost` | Float64 | Fixed O&M costs of the storage component | \$/MWh/yr | 0.0 |
| `storage_variable_om_cost` | Float64 | Variable O&M costs of the storage component | \$/MWh | 0.0 |
| `storage_wacc` | Float64 | Weighted average cost of capital | fraction | 0.0 |
| `storage_lifetime` | Int | Asset lifetime in years | years | 1 |
| `storage_capital_recovery_period` | Int | Investment recovery period | years | 1 |
| `storage_retirement_period` | Int | Retirement period | years | 0 |
| `discharge_investment_cost` | Float64 | CAPEX per unit discharge capacity | \$/MW | 0.0 |
| `discharge_annualized_investment_cost` | Union{Nothing,Float64} | Annualized CAPEX | \$/MW/yr | calculated |
| `discharge_fixed_om_cost` | Float64 | Fixed O&M costs of the discharge edge | \$/MW/yr | 0.0 |
| `discharge_variable_om_cost` | Float64 | Variable O&M costs of the discharge edge | \$/MWh | 0.0 |
| `discharge_wacc` | Float64 | Weighted average cost of capital | fraction | 0.0 |
| `discharge_lifetime` | Int | Asset lifetime in years | years | 1 |
| `discharge_capital_recovery_period` | Int | Investment recovery period | years | 1 |
| `discharge_retirement_period` | Int | Retirement period | years | 0 |
| `charge_variable_om_cost` | Float64 | Variable O&M costs of the charge edge | \$/MWh | 0.0 |


##### Asymmetric battery
If the battery is asymmetric, the following economic parameters are also used:

| Field | Type | Description | Units | Default |
|--------------|---------|------------|----------------|----------|
| `charge_investment_cost` | Float64 | CAPEX per unit charge capacity | \$/MW | 0.0 |
| `charge_annualized_investment_cost` | Union{Nothing,Float64} | Annualized CAPEX | \$/MW/yr | calculated |
| `charge_fixed_om_cost` | Float64 | Fixed O&M costs of the charge edge | \$/MW/yr | 0.0 |

### Charge and Discharge Efficiency

| Field | Type | Description | Default |
|--------------|---------|------------|----------|
| `discharge_efficiency` | Float64 | Efficiency of discharging process | 1.0 |
| `charge_efficiency` | Float64 | Efficiency of charging process | 1.0 |

### Operational Parameters
| Field | Type | Description | Units | Default |
|--------------|---------|------------|----------------|----------|
| `storage_loss_fraction` | Float64 | Fraction of stored energy lost per timestep | fraction | 0.0 |

#### Additional Operational Parameters

**Storage duration constraints**

If [`StorageMaxDurationConstraint`](@ref storage_max_duration_constraint_ref) or [`StorageMinDurationConstraint`](@ref storage_min_duration_constraint_ref) are added to the constraints dictionary for the storage component, the following parameters are used:

| Field | Type | Description | Units | Default |
|--------------|---------|------------|----------------|----------|
| `storage_max_duration` | Float64 | Maximum storage duration | hours | 0.0 |
| `storage_min_duration` | Float64 | Minimum storage duration | hours | 0.0 |

**Maximum and minimum storage level constraints**

If [`MaxStorageLevelConstraint`](@ref max_storage_level_constraint_ref) or [`MinStorageLevelConstraint`](@ref min_storage_level_constraint_ref) are added to the constraints dictionary for the storage component, the following parameters are used:

| Field | Type | Description | Units | Default |
|--------------|---------|------------|----------------|----------|
| `storage_max_storage_level` | Float64 | Maximum storage level as fraction of capacity | fraction | 1.0 |
| `storage_min_storage_level` | Float64 | Minimum storage level as fraction of capacity | fraction | 0.0 |

**Storage charge/discharge ratio constraint**

If [`StorageChargeDischargeRatioConstraint`](@ref storage_charge_discharge_ratio_constraint_ref) is added to the constraints dictionary for the storage component, the following parameter is used:

| Field | Type | Description | Units | Default |
|--------------|---------|------------|----------------|----------|
| `storage_charge_discharge_ratio` | Float64 | Ratio between charging and discharging rates | fraction | 1.0 |

**Long-duration storage constraint**

If [`LongDurationStorageImplicitMinMaxConstraint`](@ref long_duration_storage_constraints_ref) is added to the constraints dictionary for the storage component, the following parameter is used:

| Field | Type | Description | Default |
|--------------|---------|------------|----------|
| `storage_long_duration` | Boolean | Whether this is long-duration storage | false |

**Minimum flow constraint**

If [`MinFlowConstraint`](@ref min_flow_constraint_ref) is added to the constraints dictionary for the discharge edge, the following parameter is used:

| Field | Type | Description | Units | Default |
|--------------|---------|------------|----------------|----------|
| `discharge_min_flow_fraction` | Float64 | Minimum discharge as fraction of capacity | fraction | 0.0 |
| `charge_min_flow_fraction` | Float64 | Minimum charge as fraction of capacity | fraction | 0.0 |

**Ramping limit constraint**

If [`RampingLimitConstraint`](@ref ramping_limits_constraint_ref) is added to the constraints dictionary for the discharge edge, the following parameter is used:

| Field | Type | Description | Units | Default |
|--------------|---------|------------|----------------|----------|
| `discharge_ramp_up_fraction` | Float64 | Maximum increase in discharge between timesteps | fraction | 1.0 |
| `discharge_ramp_down_fraction` | Float64 | Maximum decrease in discharge between timesteps | fraction | 1.0 |
| `charge_ramp_up_fraction` | Float64 | Maximum increase in charge between timesteps | fraction | 1.0 |
| `charge_ramp_down_fraction` | Float64 | Maximum decrease in charge between timesteps | fraction | 1.0 |

## [Types - Asset Structure](@id battery_type_definition)

The `Battery` asset is defined as follows:

```julia
struct Battery <: AbstractAsset
    id::AssetId
    battery_storage::AbstractStorage{<:Electricity}
    discharge_edge::Edge{<:Electricity}
    charge_edge::Edge{<:Electricity}
end
```

## [Constructors](@id battery_constructors)

### Default constructor

```julia
Battery(id::AssetId, storage::AbstractStorage{<:Electricity}, discharge_edge::Edge{<:Electricity}, charge_edge::Edge{<:Electricity})
```

### Factory constructor
```julia
make(asset_type::Type{Battery}, data::AbstractDict{Symbol,Any}, system::System)
```

| Field | Type | Description |
|--------------|---------|------------|
| `asset_type` | `Type{Battery}` | Macro type of the asset |
| `data` | `AbstractDict{Symbol,Any}` | Dictionary containing the input data for the asset |
| `system` | `System` | System to which the asset belongs |

## [Examples](@id battery_examples)
This section contains examples of how to use the battery asset in a Macro model.

### Two batteries in the same zone "SE"

This example shows two batteries in the same zone "SE" with different investment costs and O&M costs. The discharge efficiency and charge efficiency are set to 0.95 and 0.92, respectively. Both batteries have the [`StorageMinDurationConstraint`](@ref storage_min_duration_constraint_ref) and [`StorageMaxDurationConstraint`](@ref storage_max_duration_constraint_ref) constraints applied to the storage component.

**JSON Format:**

Note that the `global_data` field is used to set the fields and constraints that are common to all instances of the same asset type.

```json
{
    "elec_stor": [
        {
            "type": "Battery",
            "global_data": {
                "storage_constraints": {
                    "StorageMinDurationConstraint": true,
                    "StorageMaxDurationConstraint": true,
                }
            },
            "instance_data": [
                {
                    "id": "battery_1_SE",
                    "location": "SE",
                    "storage_investment_cost": 10000,
                    "storage_fixed_om_cost": 500,
                    "storage_max_duration": 10,
                    "storage_min_duration": 1,
                    "discharge_investment_cost": 20000,
                    "discharge_fixed_om_cost": 1000,
                    "discharge_variable_om_cost": 1,
                    "charge_variable_om_cost": 1,
                    "discharge_efficiency": 0.95,
                    "charge_efficiency": 0.95
                },
                {
                    "id": "battery_2_SE",
                    "location": "SE",
                    "storage_investment_cost": 15000,
                    "storage_fixed_om_cost": 800,
                    "storage_max_duration": 4,
                    "storage_min_duration": 1,
                    "discharge_investment_cost": 25000,
                    "discharge_fixed_om_cost": 1200,
                    "discharge_variable_om_cost": 1.2,
                    "charge_variable_om_cost": 1.2,
                    "discharge_efficiency": 0.92,
                    "charge_efficiency": 0.92
                }
            ]
        }
    ]
}
```

**CSV Format:**

| Type | id | location | storage\_constraints--StorageMinDurationConstraint | storage\_constraints--StorageMaxDurationConstraint | storage\_investment\_cost | storage\_fixed\_om\_cost | storage\_max\_duration | storage\_min\_duration | discharge\_investment\_cost | discharge\_fixed\_om\_cost | discharge\_variable\_om\_cost | charge\_variable\_om\_cost | discharge\_efficiency | charge\_efficiency |
|------|----|----------|--------------------------------------------------|--------------------------------------------------|------------------------|---------------------|---------------------|---------------------|---------------------------|------------------------|---------------------------|------------------------|---------------------|-------------------|
| Battery | battery\_1\_SE | SE | true | true | 10000 | 500 | 10 | 1 | 20000 | 1000 | 1 | 1 | 0.95 | 0.95 |
| Battery | battery\_2\_SE | SE | true | true | 15000 | 800 | 4 | 1 | 25000 | 1200 | 1.2 | 1.2 | 0.92 | 0.92 |

### Pumped Hydro Storage
This example shows a pumped hydro storage asset with a fixed discharge and storage capacity (capacity cannot be expanded or retired) and a minimum discharge flow constraint of 0.5.

**JSON Format:**
```json
{
    "elec_stor": [
        {
            "type": "Battery",
            "global_data": {
                "discharge_can_expand": false,
                "discharge_can_retire": false,
                "storage_can_expand": false,
                "storage_can_retire": false,
                "discharge_constraints": {
                    "MinFlowConstraint": true
                }
            },
            "instance_data": [
                {
                    "id": "pumpedhydro_SE",
                    "location": "SE",
                    "discharge_capacity_size": 200,
                    "discharge_existing_capacity": 5000,
                    "discharge_fixed_om_cost": 40000,
                    "discharge_min_flow_fraction": 0.5,
                    "discharge_efficiency": 0.87,
                    "charge_efficiency": 0.87
                }
            ]
        }
    ]
}
```

**CSV Format:**

| Type | id | location | discharge\_can\_expand | discharge\_can\_retire | storage\_can\_expand | storage\_can\_retire | discharge\_constraints--MinFlowConstraint | discharge\_capacity\_size | discharge\_existing\_capacity | discharge\_fixed\_om\_cost | discharge\_min\_flow\_fraction | discharge\_efficiency | charge\_efficiency |
|------|----|----------|---------------------|---------------------|-------------------|-------------------|------------------------------------------|------------------------|------------------------------|------------------------|------------------------------|---------------------|-------------------|
| Battery | pumpedhydro\_SE | SE | false | false | false | false | true | 200 | 5000 | 40000 | 0.5 | 0.87 | 0.87 |

## [Best Practices](@id battery_best_practices)

1. **Use global data for common fields and constraints**: Use the `global_data` field to set the fields and constraints that are common to all instances of the same asset type.
2. **Set realistic efficiencies**: Make sure the efficiencies are realistic for the technology being modeled
3. **Use meaningful IDs**: Choose descriptive identifiers that indicate location and technology type
4. **Consider duration constraints**: Set appropriate min/max duration based on technology
5. **Use constraints selectively**: Only enable constraints that are necessary for your modeling needs
6. **Validate costs**: Ensure investment and O&M costs are in appropriate units
7. **Test configurations**: Start with simple configurations and gradually add complexity

## [Input File (Advanced Format)](@id battery_advanced_json_csv_input_format)

Macro provides an advanced format for defining battery assets, offering users and modelers detailed control over asset specifications. This format builds upon the standard format and is ideal for those who need more comprehensive customization.

To understand the advanced format, consider the [graph representation](@ref battery_asset_structure) and the [type definition](@ref battery_type_definition) of a battery asset. The input file mirrors this hierarchical structure.

A battery asset in Macro is composed of a storage component, represented by a `Storage` object, and two edges (charge and discharge), each represented by an `Edge` object. The input file for a battery asset is therefore organized as follows:

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
Each top-level key (e.g., "storage" or "edges") denotes a component type. The second-level keys either specify the attributes of the component (when there is a single instance) or identify the instances of the component (e.g., "discharge\_edge" or "charge\_edge") when there are multiple instances. For multiple instances, a third-level key details the attributes for each instance.

Below is an example of an input file for a battery asset that sets up three batteries, located in the SE, MIDAT, and NE regions.

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
                        "StorageMinDurationConstraint": true,
                        "StorageMaxDurationConstraint": true,
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
                            "StorageDischargeLimitConstraint": true,
                            "StorageChargeLimitConstraint": true
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
                        "existing_capacity": 0.0,
                        "fixed_om_cost": 2541.19,
                        "investment_cost": 9656.002735,
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
                        "existing_capacity": 0.0,
                        "fixed_om_cost": 2541.19,
                        "investment_cost": 9656.002735,
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
                        "existing_capacity": 0.0,
                        "fixed_om_cost": 2541.19,
                        "investment_cost": 9656.002735,
                        "max_duration": 10,
                        "min_duration": 1
                    }
                }
            ]
        }
    ]
}
```

### Key Points

- The `global_data` field is utilized to define attributes and constraints that apply universally to all instances of a particular asset type.
- The `start_vertex` and `end_vertex` fields indicate the nodes to which the charge and discharge edges are connected. These nodes must be defined in the `nodes.json` file.
- For a comprehensive list of attributes that can be configured for the storage and edge components, refer to the [storage](@ref manual-storage-fields) and [edges](@ref manual-edges-fields) pages of the Macro manual.

!!! note "The `has_capacity` Edge Attribute"
    The `has_capacity` attribute is a flag that indicates whether a specific edge of an asset has a capacity variable, allowing it to be expanded or retired. Typically, users do not need to manually adjust this flag, as the asset creators in Macro have already configured it correctly for each edge. However, advanced users can use this flag to override the default settings for each edge if needed.