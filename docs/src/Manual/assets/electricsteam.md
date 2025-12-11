# Electric Steam

## Contents

[Overview](@ref electricsteam_overview) | [Asset Structure](@ref electricsteam_asset_structure) | [Flow Equations](@ref electricsteam_flow_equations) | [Input File (Standard Format)](@ref electricsteam_input_file) | [Types - Asset Structure](@ref electricsteam_type_definition) | [Constructors](@ref electricsteam_constructors) | [Examples](@ref electricsteam_examples) | [Best Practices](@ref electricsteam_best_practices) | [Input File (Advanced Format)](@ref electricsteam_advanced_json_csv_input_format)

## [Overview](@id electricsteam_overview)

Electric Steam assets in MacroEnergy.jl represent resistive or steam production–based systems that convert electricity into steam for district or building steam applications.
These assets can represent electric boilers, steam production, or other electrical steam devices supplying district or building steam networks. 
They are defined using either JSON or CSV input files placed in the `assets` directory, typically named with descriptive identifiers like `electric_steam.json`.

## [Asset Structure](@id electricsteam_asset_structure)

An electric steam asset consists of three main components:

1. **Transformation Component**: Balances the electricity and steam flows
2. **Electricity Edge**: Represents the electricity supply to the steam unit
3. **Steam Edge**: Represents the steam production (can have unit commitment operations)

Here is a graphical representation of the electric steam asset:

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'background': '#E2F0FF' }}}%%
flowchart LR
  subgraph ElectricSteam
  direction LR
  A((Electricity)) e1@ --> B{{..}}
  B e2@ --> C((Steam))
  e1@{animate: true}
  e2@{animate: true}
 end
    style A r:55px,fill:#0055A4,stroke:black,color:white,stroke-dasharray: 3,5;
    style B r:55px,fill:black,stroke:black,color:black,stroke-dasharray: 3,5;
    style C font-size:26px,r:55px,fill:#FFA500,stroke:black,color:black,stroke-dasharray: 3,5;

  linkStyle 0 stroke:#0055A4, stroke-width: 2px;
  linkStyle 1 stroke:#FFA500, stroke-width: 2px;

```

## [Flow Equations](@id electricsteam_flow_equations)
The electric steam asset follows these stoichiometric relationships:

```math
\begin{aligned}
\phi_{elec} &= \phi_{steam} \cdot \epsilon_{elec\_consumption} \\
\end{aligned}
```

Where:
- ``\phi`` represents the flow of each commodity
- ``\epsilon`` represents the stoichiometric coefficients defined in the [Conversion Process Parameters](@ref electricsteam_conversion_process_parameters) section.

## [Input File (Standard Format)](@id electricsteam_input_file)

!!! note "Techno-Economic Analysis"
    Techno-economic analysis background is recommended for updating or adding conversion process parameters. For users not familiar with TEA, they can refer to [this guide](@ref tea). 

The easiest way to include a electric steam asset in a model is to create a new file (either JSON or CSV) and place it in the `assets` directory together with the other assets. 

```
your_case/
├── assets/
│   ├── electric_steam.json    # or electric_steam.csv
│   ├── other_assets.json
│   └── ...
├── system/
├── settings/
└── ...
```

This file can either be created manually, or using the `template_asset` function, as shown in the [Adding an Asset to a System](@ref) section of the User Guide. The file will be automatically loaded when you run your Macro model. 

The following is an example of a electric steam asset input file:
```json
{
    "ElectricSteam": [
        {
            "type": "ElectricSteam",
            "instance_data": [
                {
                    "id": "SE_electric_boiler_1",
                    "location": "SE",
                    "timedata": "Electricity",
                    "capacity_size": 50,
                    "elec_consumption": 1.0,
                    "investment_cost": 20000,
                    "fixed_om_cost": 1200,
                    "variable_om_cost": 2.0,
                    "ramp_up_fraction": 0.8,
                    "ramp_down_fraction": 0.8
                }
            ]
        }
    ]
}

```

!!! tip "Global Data vs Instance Data"
    When working with JSON input files, the `global_data` field can be used to group data that is common to all instances of the same asset type. This is useful for setting constraints that are common to all instances of the same asset type and avoid repeating the same data for each instance. See the [Examples](@ref "electricsteam_examples") section below for an example.

The following tables outline the attributes that can be set for a electric steam asset.

### Essential Attributes
| Field | Type | Description |
|--------------|---------|------------|
| `Type` | String | Asset type identifier: `"electricsteam"` |
| `id` | String | Unique identifier for the steam unit instance |
| `location` | String | Geographic location/node identifier |
| `elec_commodity` | String | Electricity commodity identifier |
| `uc` | Boolean | Whether unit commitment is enabled (default: false) |
| `timedata` | String | Time resolution for time series data (default: `"Steam"`) |
| `elec_start_vertex` | String | Electricity start vertex identifier. This is **not required** if the elec commodity is present in the location. |

### [Conversion Process Parameters](@id electricsteam_conversion_process_parameters)
The following set of parameters control the conversion process and stoichiometry of the electric steam asset (see [Flow Equations](@ref electricsteam_flow_equations) for more details).

| Field | Type | Description | Units | Default |
|--------------|---------|------------|----------------|----------|
| `elec_consumption` | Float64 | Electricity consumption rate | $MWh_{electricity}/MWh_{steam}$ | 1.0 |

### [Constraints Configuration](@id "electricsteam_constraints")
Electric Steam assets can have different constraints applied to them, and the user can configure them using the following fields:

| Field | Type | Description |
|--------------|---------|------------|
| `transform_constraints` | Dict{String,Bool} | List of constraints applied to the transformation component. |
| `steam_constraints` | Dict{String,Bool} | List of constraints applied to the steam edge. |
| `elec_constraints` | Dict{String,Bool} | List of constraints applied to the electricity edge. |

For example, if the user wants to apply the [`BalanceConstraint`](@ref balance_constraint_ref) to the transformation component and the [`CapacityConstraint`](@ref capacity_constraint_ref) to the steam edge, the constraints fields should be set as follows:

```json
{
    "transform_constraints": {
        "BalanceConstraint": true
    },
    "steam_constraints": {
        "CapacityConstraint": true
    }
}
```

Users can refer to the [Adding Asset Constraints to a System](@ref) section of the User Guide for a list of all the constraints that can be applied to the different components of a electric steam asset.

#### Default constraints
To simplify the input file and the asset configuration, the following constraints are applied to the electric steam asset by default:

- [Balance constraint](@ref balance_constraint_ref) (applied to the transformation component)
- [Capacity constraint](@ref capacity_constraint_ref) (applied to the steam edge)
- [Ramping limits constraint](@ref ramping_limits_constraint_ref) (applied to the steam edge)

**Unit commitment constraints** (when `uc` is set to `true`):
- [Minimum up and down time constraint](@ref min_up_and_down_time_constraint_ref) (applied to the steam edge)

### Investment Parameters
| Field | Type | Description | Units | Default |
|--------------|---------|------------|----------------|----------|
| `can_retire` | Boolean | Whether capacity can be retired | - | true |
| `can_expand` | Boolean | Whether capacity can be expanded | - | true |
| `existing_capacity` | Float64 | Initial installed capacity | MW | 0.0 |
| `capacity_size` | Float64 | Unit size for capacity decisions | - | 1.0 |

#### Additional Investment Parameters

**Maximum and minimum capacity constraints**

If [`MaxCapacityConstraint`](@ref max_capacity_constraint_ref) or [`MinCapacityConstraint`](@ref min_capacity_constraint_ref) are added to the constraints dictionary for the steam edge, the following parameters are used by Macro:

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
| `startup_cost` | Float64 | Cost per MW of capacity to start a generator | \$/MW per start | 0.0 |
| `wacc` | Float64 | Weighted average cost of capital | fraction | 0.0 |
| `lifetime` | Int | Asset lifetime in years | years | 1 |
| `capital_recovery_period` | Int | Investment recovery period | years | 1 |
| `retirement_period` | Int | Retirement period | years | 0 |

### Operational Parameters
| Field | Type | Description | Units | Default |
|--------------|---------|------------|----------------|----------|
| `availability` | Dict | Availability file path and header | - | Empty |

#### Additional Operational Parameters

**Unit commitment parameters** (when `uc` is set to `true`)

| Field | Type | Description | Units | Default |
|--------------|---------|------------|----------------|----------|
| `startup_elec_consumption` | Float64 | Electricity consumption per unit steam to start the plant | $MWh_{electricity}/MWh_{elec}$ | 0.0 |

**Minimum flow constraint**

If [`MinFlowConstraint`](@ref min_flow_constraint_ref) is added to the constraints dictionary for the steam edge, the following parameter is used:

| Field | Type | Description | Units | Default |
|--------------|---------|------------|----------------|----------|
| `min_flow_fraction` | Float64 | Minimum flow as fraction of capacity | fraction | 0.0 |

**Ramping limit constraint**

If [`RampingLimitConstraint`](@ref ramping_limits_constraint_ref) is added to the constraints dictionary for the steam edge, the following parameters are used:

| Field | Type | Description | Units | Default |
|--------------|---------|------------|----------------|----------|
| `ramp_up_fraction` | Float64 | Maximum increase in flow between timesteps | fraction | 1.0 |
| `ramp_down_fraction` | Float64 | Maximum decrease in flow between timesteps | fraction | 1.0 |

**Minimum up and down time constraints**

If [`MinUpTimeConstraint`](@ref min_up_and_down_time_constraint_ref) or [`MinDownTimeConstraint`](@ref min_up_and_down_time_constraint_ref) are added to the constraints dictionary for the steam edge, the following parameters are used:

| Field | Type | Description | Units | Default |
|--------------|---------|------------|----------------|----------|
| `min_up_time` | Int64 | Minimum time the plant must remain committed | hours | 0 |
| `min_down_time` | Int64 | Minimum time the plant must remain shutdown | hours | 0 |

## [Types - Asset Structure](@id electricsteam_type_definition)

The `electricsteam` asset is defined as follows:

```julia
struct electricsteam{T} <: AbstractAsset
    id::AssetId
    steam_transform::Transformation
    steam_edge::Union{Edge{<:Steam},EdgeWithUC{<:Steam}}
    elec_edge::Edge{<:T}
end
```

## [Constructors](@id electricsteam_constructors)

### Default constructor

```julia
electricsteam(id::AssetId, steam_transform::Transformation, steam_edge::Union{Edge{<:Steam},EdgeWithUC{<:Steam}}, elec_edge::Edge{<:Electricity})
```

### Factory constructor
```julia
make(asset_type::Type{electricsteam}, data::AbstractDict{Symbol,Any}, system::System)
```

| Field | Type | Description |
|--------------|---------|------------|
| `asset_type` | `Type{electricsteam}` | Macro type of the asset |
| `data` | `AbstractDict{Symbol,Any}` | Dictionary containing the input data for the asset |
| `system` | `System` | System to which the asset belongs |

## [Examples](@id electricsteam_examples)
This section contains examples of how to use the electric steam asset in a Macro model.

### Example of electric steam plant

This example shows a electric steam plant. The asset has no capacity and can be expanded. The asset has an availability time series loaded from a CSV file.

**JSON Format:**

Note that the `global_data` field is used to set the fields and constraints that are common to all instances of the same asset type.

```json
{
    "ElectricSteam": [
        {
            "type": "ElectricSteam",
            "instance_data": [
                {
                    "id": "SE_electric_steam_1",
                    "location": "SE",
                    "timedata": "Electricity",
                    "elec_commodity": "Electricity",
                    "elec_start_vertex": "elec_SE",
                    "can_retire": true,
                    "can_expand": true,
                    "existing_capacity": 0,
                    "capacity_size": 50.0,
                    "elec_consumption": 1.2,
                    "fixed_om_cost": 6000,
                    "variable_om_cost": 5.0
                }
            ]
        }
    ]
}

```

**CSV Format:**

| Type | id | location | time\_data | electricity\_commodity | electricity\_start\_vertex | can\_retire | can\_expand | existing\_capacity | capacity\_size | steam\_constraints--MinFlowConstraint | electricity\_consumption | fixed\_om\_cost | variable\_om\_cost |
|------|----|-----------|------------|----------------|---------------------|-------------|-------------|--------------------|----------------|-------------------------------------|------------------|----------------|------------------|
| ElectricSteam | SE\_electric\_steam\_1 | SE | Electricity | Electricity | elec\_source | true | true | 0.0 | 50.0 | true | 1.2 | 6000 | 5.0 |

### Multiple Electric Steam Units in Different Zones

This example shows three electric steam units. Each asset has no capacity and can be expanded. The assets are configured without unit commitment variables.

**JSON Format:**

```json
{
    "ElectricSteam": [
        {
            "type": "ElectricSteam",
            "global_data": {
                "timedata": "Electricity",
                "elec_commodity": "Electricity",
                "steam_constraints": {
                    "MinFlowConstraint": true
                }
            },
            "instance_data": [
                {
                    "id": "MIDAT_electric_steam_1",
                    "location": "MIDAT",
                    "elec_consumption": 1.85,
                    "can_retire": true,
                    "can_expand": true,
                    "existing_capacity": 4,
                    "investment_cost": 0.0,
                    "fixed_om_cost": 8000,
                    "variable_om_cost": 4.5,
                    "capacity_size": 100.0
                },
                {
                    "id": "NE_electric_steam_1",
                    "location": "NE",
                    "elec_consumption": 1.90,
                    "can_retire": true,
                    "can_expand": true,
                    "existing_capacity": 0,
                    "investment_cost": 0.0,
                    "fixed_om_cost": 8200,
                    "variable_om_cost": 4.7,
                    "capacity_size": 120.0
                },
                {
                    "id": "SE_electric_steam_1",
                    "location": "SE",
                    "elec_consumption": 1.75,
                    "can_retire": true,
                    "can_expand": true,
                    "existing_capacity": 0,
                    "investment_cost": 0.0,
                    "fixed_om_cost": 7000,
                    "variable_om_cost": 3.9,
                    "capacity_size": 500.0
                }
            ]
        }
    ]
}
```

**CSV Format:**

| Type | id | location | time\_data | electricity\_commodity | can\_retire | can\_expand | existing\_capacity | capacity\_size | steam\_constraints--MinFlowConstraint | electricity\_consumption | fixed\_om\_cost | variable\_om\_cost |
|------|----|-----------|------------|----------------|-------------|-------------|--------------------|----------------|-------------------------------------|------------------|----------------|------------------|
| ElectricSteam | MIDAT\_electric\_steam\_1 | MIDAT | Electricity | Electricity | true | true | 0 | 100.0 | true | 1.85 | 8000 | 4.5 |
| ElectricSteam | NE\_electric\_steam\_1 | NE | Electricity | Electricity | true | true | 0 | 120.0 | true | 1.90 | 8200 | 4.7 |
| ElectricSteam | SE\_electric\_steam\_1 | SE | Electricity | Electricity | true | true | 0 | 500.0 | true | 1.75 | 7000 | 3.9 |

## [Best Practices](@id electricsteam_best_practices)

1. **Use global data for common parameters**: Use the `global_data` field to set the fields and constraints that are common to all instances of the same asset type.
2. **Set realistic efficiency parameters**: Ensure electricity consumption are accurate for the technology being modeled
3. **Use meaningful IDs**: Choose descriptive identifiers that indicate location and technology type
4. **Consider unit commitment carefully**: Enable unit commitment only when detailed operational modeling is needed
5. **Use constraints selectively**: Only enable constraints that are necessary for your modeling needs
6. **Validate costs**: Ensure investment and O&M costs are in appropriate units and time periods
7. **Test configurations**: Start with simple configurations and gradually add complexity
8. **Set appropriate ramp rates**: Consider the actual operational characteristics of the technology

## [Input File (Advanced Format)](@id electricsteam_advanced_json_csv_input_format)

Macro provides an advanced format for defining electric steam assets, offering users and modelers detailed control over asset specifications. This format builds upon the standard format and is ideal for those who need more comprehensive customization.

To understand the advanced format, consider the [graph representation](@ref electricsteam_asset_structure) and the [type definition](@ref electricsteam_type_definition) of a electric steam asset. The input file mirrors this hierarchical structure.

A electric steam asset in Macro is composed of a transformation component, represented by a `Transformation` object, and multiple edges (electricity, steam), each represented by an `Edge` object. The input file for a electric steam asset is therefore organized as follows:

```json
{
    "transforms":{
        // ... transformation-specific attributes ...
    },
    "edges":{
        "elec_edge": {
            // ... elec_edge-specific attributes ...
        },
        "steam_edge": {
            // ... steam_edge-specific attributes ...
        }
    }
}
```

Each top-level key (e.g., "transforms" or "edges") denotes a component type. The second-level keys either specify the attributes of the component (when there is a single instance) or identify the instances of the component when there are multiple instances.

Below is an example of an input file for a electric steam asset that sets up multiple electric steam plants across different regions:

```json
{
    "ElectricSteam": [
        {
            "type": "electricsteam",
            "global_data": {
                "transforms": {
                    "timedata": "Electricity",
                    "constraints": {
                        "BalanceConstraint": true
                    }
                },
                "edges": {
                    "steam_edge": {
                        "commodity": "Steam",
                        "unidirectional": true,
                        "has_capacity": true,
                        "constraints": {
                            "CapacityConstraint": true,
                            "RampingLimitConstraint": true,
                            "MinFlowConstraint": true
                        }
                    },
                    "elec_edge": {
                        "commodity": "Electricity",
                        "unidirectional": true,
                        "has_capacity": false
                    }
                }
            },
            "instance_data": [
                {
                    "id": "MIDAT_electric_steam_1",
                    "transforms": {
                        "elec_consumption": 1.85,
                    },
                    "edges": {
                        "steam_edge": {
                            "end_vertex": "steam_MIDAT",
                            "can_retire": true,
                            "can_expand": true,
                            "existing_capacity": 0,
                            "investment_cost": 0.0,
                            "fixed_om_cost": 8000,
                            "variable_om_cost": 4.5,
                            "capacity_size": 100.0
                        },
                        "elec_edge": {
                            "start_vertex": "elec_MIDAT"
                        }
                    }
                },
                {
                    "id": "NE_electric_steam_1",
                    "transforms": {
                        "elec_consumption": 1.90,
                    },
                    "edges": {
                        "steam_edge": {
                            "end_vertex": "steam_NE",
                            "can_retire": true,
                            "can_expand": true,
                            "existing_capacity": 0,
                            "investment_cost": 0.0,
                            "fixed_om_cost": 8200,
                            "variable_om_cost": 4.7,
                            "capacity_size": 120.0
                        },
                        "elec_edge": {
                            "start_vertex": "elec_NE"
                        }
                    }
                },
                {
                    "id": "SE_electric_steam_1",
                    "transforms": {
                        "elec_consumption": 1.75,
                    },
                    "edges": {
                        "steam_edge": {
                            "end_vertex": "steam_SE",
                            "can_retire": true,
                            "can_expand": true,
                            "existing_capacity": 0,
                            "investment_cost": 0.0,
                            "fixed_om_cost": 7000,
                            "variable_om_cost": 3.9,
                            "capacity_size": 500.0
                        },
                        "elec_edge": {
                            "start_vertex": "elec_SE"
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
- The `start_vertex` and `end_vertex` fields indicate the nodes to which the edges are connected. These nodes must be defined in the `nodes.json` file.
- By default, only the steam edge is allowed to expand as a modeling decision (*see note below*)
- The steam edge can have unit commitment operations enabled by setting the `uc` attribute to `true`.
- For a comprehensive list of attributes that can be configured for the transformation and edge components, refer to the [transformation](@ref manual-transformation-fields) and [edges](@ref manual-edges-fields) pages of the Macro manual. 

!!! note "The `has_capacity` Edge Attribute"
    The `has_capacity` attribute is a flag that indicates whether a specific edge of an asset has a capacity variable, allowing it to be expanded or retired. Typically, users do not need to manually adjust this flag, as the asset creators in Macro have already configured it correctly for each edge. However, advanced users can use this flag to override the default settings for each edge if needed.

!!! tip "Prefixes"
    Users can apply prefixes to adjust parameters for the components of a electric steam asset, even when using the standard format. For instance, `elec_can_retire` will adjust the `can_retire` parameter for the electricity edge, and `elec_existing_capacity` will adjust the `existing_capacity` parameter for the electricity edge.
    Below are the prefixes available for modifying parameters for the components of a electric steam asset:
    - `transform_` for the transformation component
    - `steam_` for the steam edge
    - `elec_` for the electricity edge