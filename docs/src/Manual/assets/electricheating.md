# Electric Heating

## Contents

[Overview](@ref electricheating_overview) | [Asset Structure](@ref electricheating_asset_structure) | [Flow Equations](@ref electricheating_flow_equations) | [Input File (Standard Format)](@ref electricheating_input_file) | [Types - Asset Structure](@ref electricheating_type_definition) | [Constructors](@ref electricheating_constructors) | [Examples](@ref electricheating_examples) | [Best Practices](@ref electricheating_best_practices) | [Input File (Advanced Format)](@ref electricheating_advanced_json_csv_input_format)

## [Overview](@id electricheating_overview)

Electric Heating assets in MacroEnergy.jl represent resistive or heat pump–based systems that convert electricity into heat for district or building heating applications.
These assets can represent electric boilers, heat pumps, or other electrical heating devices supplying district or building heating networks. 
They are defined using either JSON or CSV input files placed in the `assets` directory, typically named with descriptive identifiers like `electric_heating.json`.

## [Asset Structure](@id electricheating_asset_structure)

An electric heating asset consists of three main components:

1. **Transformation Component**: Balances the electricity and heat flows
2. **Electricity Edge**: Represents the electricity supply to the heating unit
3. **Heat Edge**: Represents the heat production (can have unit commitment operations)

Here is a graphical representation of the electric heating asset:

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'background': '#E2F0FF' }}}%%
flowchart LR
  subgraph ElectricHeating
  direction LR
  A((Electricity)) e1@ --> B{{..}}
  B e2@ --> C((Heat))
  e1@{animate: true}
  e2@{animate: true}
 end
    style A r:55px,fill:#0055A4,stroke:black,color:white,stroke-dasharray: 3,5;
    style B r:55px,fill:black,stroke:black,color:black,stroke-dasharray: 3,5;
    style C font-size:26px,r:55px,fill:#FFA500,stroke:black,color:black,stroke-dasharray: 3,5;

  linkStyle 0 stroke:#0055A4, stroke-width: 2px;
  linkStyle 1 stroke:#FFA500, stroke-width: 2px;

```

## [Flow Equations](@id electricheating_flow_equations)
The electric heating asset follows these stoichiometric relationships:

```math
\begin{aligned}
\phi_{elec} &= \phi_{heat} \cdot \epsilon_{elec\_consumption} \\
\end{aligned}
```

Where:
- ``\phi`` represents the flow of each commodity
- ``\epsilon`` represents the stoichiometric coefficients defined in the [Conversion Process Parameters](@ref electricheating_conversion_process_parameters) section.

## [Input File (Standard Format)](@id electricheating_input_file)

!!! note "Techno-Economic Analysis"
    Techno-economic analysis background is recommended for updating or adding conversion process parameters. For users not familiar with TEA, they can refer to [this guide](@ref tea). 

The easiest way to include a electric heating asset in a model is to create a new file (either JSON or CSV) and place it in the `assets` directory together with the other assets. 

```
your_case/
├── assets/
│   ├── electric_heating.json    # or electric_heating.csv
│   ├── other_assets.json
│   └── ...
├── system/
├── settings/
└── ...
```

This file can either be created manually, or using the `template_asset` function, as shown in the [Adding an Asset to a System](@ref) section of the User Guide. The file will be automatically loaded when you run your Macro model. 

The following is an example of a electric heating asset input file:
```json
{
    "ElectricHeating": [
        {
            "type": "ElectricHeating",
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
    When working with JSON input files, the `global_data` field can be used to group data that is common to all instances of the same asset type. This is useful for setting constraints that are common to all instances of the same asset type and avoid repeating the same data for each instance. See the [Examples](@ref "electricheating_examples") section below for an example.

The following tables outline the attributes that can be set for a electric heating asset.

### Essential Attributes
| Field | Type | Description |
|--------------|---------|------------|
| `type` | String | Asset type identifier: `"electricheating"` |
| `id` | String | Unique identifier for the heating unit instance |
| `location` | String | Geographic location/node identifier |
| `elec_commodity` | String | Electricity commodity identifier |
| `uc` | Boolean | Whether unit commitment is enabled (default: false) |
| `timedata` | String | Time resolution for time series data (default: `"Heat"`) |
| `elec_start_vertex` | String | Electricity start vertex identifier. This is **not required** if the elec commodity is present in the location. |

### [Conversion Process Parameters](@id electricheating_conversion_process_parameters)
The following set of parameters control the conversion process and stoichiometry of the electric heating asset (see [Flow Equations](@ref electricheating_flow_equations) for more details).

| Field | Type | Description | Units | Default |
|--------------|---------|------------|----------------|----------|
| `elec_consumption` | Float64 | Electricity consumption rate | $MWh_{electricity}/MWh_{heat}$ | 1.0 |

### [Constraints Configuration](@id "electricheating_constraints")
Electric Heating assets can have different constraints applied to them, and the user can configure them using the following fields:

| Field | Type | Description |
|--------------|---------|------------|
| `transform_constraints` | Dict{String,Bool} | List of constraints applied to the transformation component. |
| `heat_constraints` | Dict{String,Bool} | List of constraints applied to the heat edge. |
| `elec_constraints` | Dict{String,Bool} | List of constraints applied to the electricity edge. |

For example, if the user wants to apply the [`BalanceConstraint`](@ref balance_constraint_ref) to the transformation component and the [`CapacityConstraint`](@ref capacity_constraint_ref) to the heat edge, the constraints fields should be set as follows:

```json
{
    "transform_constraints": {
        "BalanceConstraint": true
    },
    "heat_constraints": {
        "CapacityConstraint": true
    }
}
```

Users can refer to the [Adding Asset Constraints to a System](@ref) section of the User Guide for a list of all the constraints that can be applied to the different components of a electric heating asset.

#### Default constraints
To simplify the input file and the asset configuration, the following constraints are applied to the electric heating asset by default:

- [Balance constraint](@ref balance_constraint_ref) (applied to the transformation component)
- [Capacity constraint](@ref capacity_constraint_ref) (applied to the heat edge)
- [Ramping limits constraint](@ref ramping_limits_constraint_ref) (applied to the heat edge)

**Unit commitment constraints** (when `uc` is set to `true`):
- [Minimum up and down time constraint](@ref min_up_and_down_time_constraint_ref) (applied to the heat edge)

### Investment Parameters
| Field | Type | Description | Units | Default |
|--------------|---------|------------|----------------|----------|
| `can_retire` | Boolean | Whether capacity can be retired | - | true |
| `can_expand` | Boolean | Whether capacity can be expanded | - | true |
| `existing_capacity` | Float64 | Initial installed capacity | MW | 0.0 |
| `capacity_size` | Float64 | Unit size for capacity decisions | - | 1.0 |

#### Additional Investment Parameters

**Maximum and minimum capacity constraints**

If [`MaxCapacityConstraint`](@ref max_capacity_constraint_ref) or [`MinCapacityConstraint`](@ref min_capacity_constraint_ref) are added to the constraints dictionary for the heat edge, the following parameters are used by Macro:

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
| `startup_elec_consumption` | Float64 | Electricity consumption per unit heat to start the plant | $MWh_{electricity}/MWh_{elec}$ | 0.0 |

**Minimum flow constraint**

If [`MinFlowConstraint`](@ref min_flow_constraint_ref) is added to the constraints dictionary for the heat edge, the following parameter is used:

| Field | Type | Description | Units | Default |
|--------------|---------|------------|----------------|----------|
| `min_flow_fraction` | Float64 | Minimum flow as fraction of capacity | fraction | 0.0 |

**Ramping limit constraint**

If [`RampingLimitConstraint`](@ref ramping_limits_constraint_ref) is added to the constraints dictionary for the heat edge, the following parameters are used:

| Field | Type | Description | Units | Default |
|--------------|---------|------------|----------------|----------|
| `ramp_up_fraction` | Float64 | Maximum increase in flow between timesteps | fraction | 1.0 |
| `ramp_down_fraction` | Float64 | Maximum decrease in flow between timesteps | fraction | 1.0 |

**Minimum up and down time constraints**

If [`MinUpTimeConstraint`](@ref min_up_and_down_time_constraint_ref) or [`MinDownTimeConstraint`](@ref min_up_and_down_time_constraint_ref) are added to the constraints dictionary for the heat edge, the following parameters are used:

| Field | Type | Description | Units | Default |
|--------------|---------|------------|----------------|----------|
| `min_up_time` | Int64 | Minimum time the plant must remain committed | hours | 0 |
| `min_down_time` | Int64 | Minimum time the plant must remain shutdown | hours | 0 |

## [Types - Asset Structure](@id electricheating_type_definition)

The `electricheating` asset is defined as follows:

```julia
struct electricheating{T} <: AbstractAsset
    id::AssetId
    heating_transform::Transformation
    heat_edge::Union{Edge{<:Heat},EdgeWithUC{<:Heat}}
    elec_edge::Edge{<:T}
end
```

## [Constructors](@id electricheating_constructors)

### Default constructor

```julia
electricheating(id::AssetId, heating_transform::Transformation, heat_edge::Union{Edge{<:Heat},EdgeWithUC{<:Heat}}, elec_edge::Edge{<:Electricity})
```

### Factory constructor
```julia
make(asset_type::Type{electricheating}, data::AbstractDict{Symbol,Any}, system::System)
```

| Field | Type | Description |
|--------------|---------|------------|
| `asset_type` | `Type{electricheating}` | Macro type of the asset |
| `data` | `AbstractDict{Symbol,Any}` | Dictionary containing the input data for the asset |
| `system` | `System` | System to which the asset belongs |

## [Examples](@id electricheating_examples)
This section contains examples of how to use the electric heating asset in a Macro model.

### Example of electric heat pump

This example shows an electric heat pump. The asset has no capacity and can be expanded. The asset has an availability time series loaded from a CSV file.


**JSON Format:**

Note that the `global_data` field is used to set the fields and constraints that are common to all instances of the same asset type.

```json
{
    "ElectricHeatPump": [
        {
            "type": "ElectricHeating",
            "instance_data": [
                {
                    "id": "SE_electric_heating_1",
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

| Type | id | location | time\_data | electricity\_commodity | electricity\_start\_vertex | can\_retire | can\_expand | existing\_capacity | capacity\_size | heat\_constraints--MinFlowConstraint | electricity\_consumption | fixed\_om\_cost | variable\_om\_cost |
|------|----|-----------|------------|----------------|---------------------|-------------|-------------|--------------------|----------------|-------------------------------------|------------------|----------------|------------------|
| ElectricHeating | SE\_electric\_heating\_1 | SE | Electricity | Electricity | elec\_source | true | true | 0.0 | 50.0 | true | 1.2 | 6000 | 5.0 |

### Multiple Electric Heating Units in Different Zones

This example shows three electric heating units. Each asset has no capacity and can be expanded. The assets are configured without unit commitment variables.

**JSON Format:**

```json
{
    "ElectricHeating": [
        {
            "type": "ElectricHeating",
            "global_data": {
                "timedata": "Electricity",
                "elec_commodity": "Electricity",
                "heat_constraints": {
                    "MinFlowConstraint": true
                }
            },
            "instance_data": [
                {
                    "id": "MIDAT_electric_heating_1",
                    "location": "MIDAT",
                    "elec_consumption": 1.85,
                    "can_retire": true,
                    "can_expand": true,
                    "existing_capacity": 0,
                    "investment_cost": 0.0,
                    "fixed_om_cost": 8000,
                    "variable_om_cost": 4.5,
                    "capacity_size": 100.0
                },
                {
                    "id": "NE_electric_heating_1",
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
                    "id": "SE_electric_heating_1",
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

| Type | id | location | time\_data | electricity\_commodity | can\_retire | can\_expand | existing\_capacity | capacity\_size | heat\_constraints--MinFlowConstraint | electricity\_consumption | fixed\_om\_cost | variable\_om\_cost |
|------|----|-----------|------------|----------------|-------------|-------------|--------------------|----------------|-------------------------------------|------------------|----------------|------------------|
| ElectricHeating | MIDAT\_electric\_heating\_1 | MIDAT | Electricity | Electricity | true | true | 0.0 | 100.0 | true | 1.85 | 8000 | 4.5 |
| ElectricHeating | NE\_electric\_heating\_1 | NE | Electricity | Electricity | true | true | 0.0 | 120.0 | true | 1.90 | 8200 | 4.7 |
| ElectricHeating | SE\_electric\_heating\_1 | SE | Electricity | Electricity | true | true | 0.0 | 500.0 | true | 1.75 | 7000 | 3.9 |

## [Best Practices](@id electricheating_best_practices)

1. **Use global data for common parameters**: Use the `global_data` field to set the fields and constraints that are common to all instances of the same asset type.
2. **Set realistic efficiency parameters**: Ensure electricity consumption are accurate for the technology being modeled
3. **Use meaningful IDs**: Choose descriptive identifiers that indicate location and technology type
4. **Consider unit commitment carefully**: Enable unit commitment only when detailed operational modeling is needed
5. **Use constraints selectively**: Only enable constraints that are necessary for your modeling needs
6. **Validate costs**: Ensure investment and O&M costs are in appropriate units and time periods
7. **Test configurations**: Start with simple configurations and gradually add complexity
8. **Set appropriate ramp rates**: Consider the actual operational characteristics of the technology

## [Input File (Advanced Format)](@id electricheating_advanced_json_csv_input_format)

Macro provides an advanced format for defining electric heating assets, offering users and modelers detailed control over asset specifications. This format builds upon the standard format and is ideal for those who need more comprehensive customization.

To understand the advanced format, consider the [graph representation](@ref electricheating_asset_structure) and the [type definition](@ref electricheating_type_definition) of a electric heating asset. The input file mirrors this hierarchical structure.

A electric heating asset in Macro is composed of a transformation component, represented by a `Transformation` object, and multiple edges (electricity, heat), each represented by an `Edge` object. The input file for a electric heating asset is therefore organized as follows:

```json
{
    "transforms":{
        // ... transformation-specific attributes ...
    },
    "edges":{
        "elec_edge": {
            // ... elec_edge-specific attributes ...
        },
        "heat_edge": {
            // ... heat_edge-specific attributes ...
        }
    }
}
```

Each top-level key (e.g., "transforms" or "edges") denotes a component type. The second-level keys either specify the attributes of the component (when there is a single instance) or identify the instances of the component when there are multiple instances.

Below is an example of an input file for a electric heating asset that sets up multiple electric heating plants across different regions:

```json
{
    "ElectricHeating": [
        {
            "type": "electricheating",
            "global_data": {
                "transforms": {
                    "timedata": "Electricity",
                    "constraints": {
                        "BalanceConstraint": true
                    }
                },
                "edges": {
                    "heat_edge": {
                        "commodity": "Heat",
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
                    "id": "MIDAT_electric_heating_1",
                    "transforms": {
                        "elec_consumption": 1.85,
                     },
                    "edges": {
                        "heat_edge": {
                            "end_vertex": "heat_MIDAT",
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
                    "id": "NE_electric_heating_1",
                    "transforms": {
                        "elec_consumption": 1.90,
                    },
                    "edges": {
                        "heat_edge": {
                            "end_vertex": "heat_NE",
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
                    "id": "SE_electric_heating_1",
                    "transforms": {
                        "elec_consumption": 1.75,
                    },
                    "edges": {
                        "heat_edge": {
                            "end_vertex": "heat_SE",
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
- By default, only the heat edge is allowed to expand as a modeling decision (*see note below*)
- The heat edge can have unit commitment operations enabled by setting the `uc` attribute to `true`.
- For a comprehensive list of attributes that can be configured for the transformation and edge components, refer to the [transformation](@ref manual-transformation-fields) and [edges](@ref manual-edges-fields) pages of the Macro manual. 

!!! note "The `has_capacity` Edge Attribute"
    The `has_capacity` attribute is a flag that indicates whether a specific edge of an asset has a capacity variable, allowing it to be expanded or retired. Typically, users do not need to manually adjust this flag, as the asset creators in Macro have already configured it correctly for each edge. However, advanced users can use this flag to override the default settings for each edge if needed.

!!! tip "Prefixes"
    Users can apply prefixes to adjust parameters for the components of a electric heating asset, even when using the standard format. For instance, `elec_can_retire` will adjust the `can_retire` parameter for the electricity edge, and `elec_existing_capacity` will adjust the `existing_capacity` parameter for the electricity edge.
    Below are the prefixes available for modifying parameters for the components of a electric heating asset:
    - `transform_` for the transformation component
    - `heat_` for the heat edge
    - `elec_` for the electricity edge