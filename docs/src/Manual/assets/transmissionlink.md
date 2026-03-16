# Transmission Link

## Contents

[Overview](@ref transmissionlink_overview) | [Asset Structure](@ref transmissionlink_asset_structure) | [Input File (Standard Format)](@ref transmissionlink_input_file) | [Types - Asset Structure](@ref transmissionlink_type_definition) | [Constructors](@ref transmissionlink_constructors) | [Examples](@ref transmissionlink_examples) | [Best Practices](@ref transmissionlink_best_practices) | [Input File (Advanced Format)](@ref transmissionlink_advanced_json_csv_input_format)

## [Overview](@id transmissionlink_overview)

Transmission Link assets in Macro represent a general commodity transmission infrastructure that links various geographic regions or nodes. These assets are specified using JSON or CSV input files located in the `assets` directory, usually named with descriptive identifiers such as `transmissions.json` or `transmissions.csv`.

## [Asset Structure](@id transmissionlink_asset_structure)

A Transmission Link asset consists of one main component:

1. **Transmission Edge**: Represents the flow of a commodity between two nodes with capacity constraints and losses

Here is a graphical representation of the Transmission Link asset:

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'background': '#D1EBDE' }}}%%
flowchart LR
  subgraph TransmissionLink
  direction LR
    A((Commodity)) e1@-->|Transmission| B((Commodity))
    e1@{ animate: true }
 end
    style A r:40,fill:#FFD700,stroke:black,color:black,stroke-dasharray: 3,5;
    style B r:40,fill:#FFD700,stroke:black,color:black,stroke-dasharray: 3,5;
    linkStyle 0 stroke:#FFD700, stroke-width: 2px;
```

## [Input File (Standard Format)](@id transmissionlink_input_file)

The easiest way to include a Transmission Link asset in a model is to create a new file (either JSON or CSV) and place it in the `assets` directory together with the other assets. 

```
your_case/
├── assets/
│   ├── transmissions.json    # or transmissions.csv
│   ├── other_assets.json
│   └── ...
├── system/
├── settings/
└── ...
```

This file can either be created manually, or using the `template_asset` function, as shown in the [Adding an Asset to a System](@ref) section of the User Guide. The file will be automatically loaded when you run your Macro model. 

The following is an example of a Transmission Link asset input file:
```json
{
    "link": [
        {
            "type": "TransmissionLink",
            "instance_data": [
                {
                    "id": "SE_to_MIDAT",
                    "commodity": "Electricity",
                    "transmission_origin": "elec_SE",
                    "transmission_dest": "elec_MIDAT",
                    "distance": 491.4512001,
                    "existing_capacity": 5552,
                    "max_capacity": 27760,
                    "investment_cost": 40219,
                    "loss_fraction": 0.04914512,
                    "transmission_constraints": {
                        "MaxCapacityConstraint": true
                    }
                }
            ]
        }
    ]
}
```

!!! tip "Global Data vs Instance Data"
    When working with JSON input files, the `global_data` field can be used to group data that is common to all instances of the same asset type. This is useful for setting constraints that are common to all instances of the same asset type and avoid repeating the same data for each instance. See the [Examples](@ref "transmissionlink_examples") section below for an example.

The following tables outline the attributes that can be set for a Transmission Link asset.

### Essential Attributes
| Field | Type | Description |
|--------------|---------|------------|
| `type` | String | Asset type identifier: "TransmissionLink" |
| `id` | String | Unique identifier for the Transmission Link instance |
| `commodity` | String | Commodity type being transmitted (e.g., "Electricity") |
| `transmission_origin` | String | Origin node identifier |
| `transmission_dest` | String | Destination node identifier |

### [Constraints configuration](@id transmissionlink_constraints)
Transmission Link assets can have different constraints applied to them, and the user can configure them using the following fields:

| Field | Type | Description |
|--------------|---------|------------|
| `transmission_constraints` | Dict{String,Bool} | List of constraints applied to the transmission edge. |

Users can refer to the [Adding Asset Constraints to a System](@ref) section of the User Guide for a list of all the constraints that can be applied to a Transmission Link asset.

#### Default constraints
To simplify the input file and the asset configuration, the following constraints are applied to the Transmission Link asset by default:

- [Capacity constraint](@ref capacity_constraint_ref) (applied to the transmission edge)

### Investment Parameters
| Field | Type | Description | Units | Default |
|--------------|---------|------------|----------------|----------|
| `can_retire` | Boolean | Whether capacity can be retired | - | false |
| `can_expand` | Boolean | Whether capacity can be expanded | - | true |
| `existing_capacity` | Float64 | Initial installed capacity | MW | 0.0 |
| `capacity_size` | Float64 | Unit size for capacity decisions | - | 1.0 |

#### Additional Investment Parameters

**Maximum and minimum capacity constraints**

If [`MaxCapacityConstraint`](@ref max_capacity_constraint_ref) or [`MinCapacityConstraint`](@ref min_capacity_constraint_ref) are added to the constraints dictionary for the transmission edge, the following parameters are used by Macro:

| Field | Type | Description | Units | Default |
|--------------|---------|------------|----------------|----------|
| `max_capacity` | Float64 | Maximum allowed capacity | MW | Inf |
| `min_capacity` | Float64 | Minimum allowed capacity | MW | 0.0 |

### Economic Parameters
| Field | Type | Description | Units | Default |
|--------------|---------|------------|----------------|----------|
| `investment_cost` | Float64 | CAPEX per unit capacity | \$/MW | 0.0 |
| `annualized_investment_cost` | Union{Nothing,Float64} | Annualized CAPEX | \$/MW/yr | calculated |
| `fixed_om_cost` | Float64 | Fixed O&M costs | \$/MW/yr | 0.0 |
| `variable_om_cost` | Float64 | Variable O&M costs | \$/MWh | 0.0 |
| `wacc` | Float64 | Weighted average cost of capital | fraction | 0.0 |
| `lifetime` | Int | Asset lifetime in years | years | 1 |
| `capital_recovery_period` | Int | Investment recovery period | years | 1 |
| `retirement_period` | Int | Retirement period | years | 0 |

### Operational Parameters
| Field | Type | Description | Units | Default |
|--------------|---------|------------|----------------|----------|
| `distance` | Float64 | Distance between nodes | km | 0.0 |
| `loss_fraction` | Float64 | Fraction of power lost during transmission | fraction | 0.0 |
| `unidirectional` | Boolean | Whether the transmission is unidirectional | - | false |

## [Types - Asset Structure](@id transmissionlink_type_definition)

The `TransmissionLink` asset is defined as follows:

```julia
struct TransmissionLink{T} <: AbstractAsset
    id::AssetId
    transmission_edge::Edge{<:T}
end
```

## [Constructors](@id transmissionlink_constructors)

### Default constructor

```julia
TransmissionLink(id::AssetId, transmission_edge::Edge{<:T})
```

### Factory constructor
```julia
make(asset_type::Type{TransmissionLink}, data::AbstractDict{Symbol,Any}, system::System)
```

| Field | Type | Description |
|--------------|---------|------------|
| `asset_type` | `Type{TransmissionLink}` | Macro type of the asset |
| `data` | `AbstractDict{Symbol,Any}` | Dictionary containing the input data for the asset |
| `system` | `System` | System to which the asset belongs |

## [Examples](@id transmissionlink_examples)
This section contains examples of how to use the Transmission Link asset in a Macro model.

### Multiple Transmission Links between different zones

This example shows two transmission links between the SE and MIDAT regions, and the MIDAT and NE regions. Each transmission link has a maximum capacity constraint applied to it.

**JSON Format:**

Note that the `global_data` field is used to set the fields and constraints that are common to all instances of the same asset type.

```json
{
    "link": [
        {
            "type": "TransmissionLink",
            "global_data": {
                "transmission_constraints": {
                    "MaxCapacityConstraint": true
                }
            },
            "instance_data": [
                {
                    "id": "SE_to_MIDAT",
                    "commodity": "Electricity",
                    "transmission_origin": "elec_SE",
                    "transmission_dest": "elec_MIDAT",
                    "distance": 491.4512001,
                    "existing_capacity": 5552,
                    "max_capacity": 27760,
                    "investment_cost": 40219,
                    "loss_fraction": 0.04914512
                },
                {
                    "id": "MIDAT_to_NE",
                    "commodity": "Electricity",
                    "transmission_origin": "elec_MIDAT",
                    "transmission_dest": "elec_NE",
                    "distance": 473.6625536,
                    "existing_capacity": 1915,
                    "max_capacity": 9575,
                    "investment_cost": 62316,
                    "loss_fraction": 0.047366255
                }
            ]
        }
    ]
}
```

**CSV Format:**

| Type | id | commodity | transmission\_origin | transmission\_dest | distance | existing\_capacity | max\_capacity | investment\_cost | loss\_fraction | transmission\_constraints--MaxCapacityConstraint |
|------|----|-----------|---------------------|-------------------|----------|-------------------|---------------|------------------|----------------|--------------------------------------------------|
| TransmissionLink | SE\_to\_MIDAT | Electricity | elec\_SE | elec\_MIDAT | 491.4512001 | 5552 | 27760 | 40219 | 0.04914512 | true |
| TransmissionLink | MIDAT\_to\_NE | Electricity | elec\_MIDAT | elec\_NE | 473.6625536 | 1915 | 9575 | 62316 | 0.047366255 | true |

## [Best Practices](@id transmissionlink_best_practices)

1. **Use global data for common fields and constraints**: Use the `global_data` field to set the fields and constraints that are common to all instances of the same asset type.
2. **Set realistic transmission losses**: Ensure loss fractions reflect actual transmission line characteristics
3. **Use meaningful IDs**: Choose descriptive identifiers that indicate origin and destination nodes
4. **Consider capacity constraints**: Set appropriate maximum capacity limits based on technology and distance
5. **Use constraints selectively**: Only enable constraints that are necessary for your modeling needs
6. **Validate costs**: Ensure investment and O&M costs are in appropriate units
7. **Test configurations**: Start with simple configurations and gradually add complexity

## [Input File (Advanced Format)](@id transmissionlink_advanced_json_csv_input_format)

Macro provides an advanced format for defining Transmission Link assets, offering users and modelers detailed control over asset specifications. This format builds upon the standard format and is ideal for those who need more comprehensive customization.

To understand the advanced format, consider the [graph representation](@ref transmissionlink_asset_structure) and the [type definition](@ref transmissionlink_type_definition) of a Transmission Link asset. The input file mirrors this hierarchical structure.

A Transmission Link asset in Macro is composed of a single transmission edge, represented by an `Edge` object. The input file for a Transmission Link asset is therefore organized as follows:

```json
{
    "edges": {
        "transmission_edge": {
            // ... transmission_edge-specific attributes ...
        }
    }
}
```
Each top-level key (e.g., "edges") denotes a component type. The second-level keys either specify the attributes of the component (when there is a single instance) or identify the instances of the component (e.g., "transmission_edge") when there are multiple instances. For multiple instances, a third-level key details the attributes for each instance.

Below is an example of an input file for a Transmission Link asset that sets up two transmission lines between different regions.

```json
{
    "link": [
        {
            "type": "TransmissionLink",
            "global_data": {
                "edges": {
                    "transmission_edge": {
                        "commodity": "Electricity",
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
                        "transmission_edge": {
                            "start_vertex": "elec_SE",
                            "end_vertex": "elec_MIDAT",
                            "distance": 491.4512001,
                            "existing_capacity": 5552,
                            "max_capacity": 27760,
                            "investment_cost": 40219,
                            "loss_fraction": 0.04914512
                        }
                    }
                },
                {
                    "id": "MIDAT_to_NE",
                    "edges": {
                        "transmission_edge": {
                            "start_vertex": "elec_MIDAT",
                            "end_vertex": "elec_NE",
                            "distance": 473.6625536,
                            "existing_capacity": 1915,
                            "max_capacity": 9575,
                            "investment_cost": 62316,
                            "loss_fraction": 0.047366255
                        }
                    }
                }
            ]
        }
    ]
}
```

### Key Points

- The `global_data` field is utilized to define attributes and constraints that apply universally to all instances of a particular asset type.
- The `start_vertex` and `end_vertex` fields indicate the nodes to which the transmission edge is connected. These nodes must be defined in the `nodes.json` file.
- For a comprehensive list of attributes that can be configured for the edge component, refer to the [edges](@ref manual-edges-fields) page of the Macro manual.
