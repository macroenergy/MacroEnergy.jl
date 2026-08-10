# Upstream Emissions

## Contents

[Overview](@ref upstreamemissions_overview) | [Asset Structure](@ref upstreamemissions_asset_structure) | [Flow Equations](@ref upstreamemissions_flow_equations) | [Input File (Standard Format)](@ref upstreamemissions_input_file) | [Types - Asset Structure](@ref upstreamemissions_type_definition) | [Constructors](@ref upstreamemissions_constructors) | [Examples](@ref upstreamemissions_examples) | [Best Practices](@ref upstreamemissions_best_practices) | [Input File (Advanced Format)](@ref upstreamemissions_advanced_json_csv_input_format)

## [Overview](@id upstreamemissions_overview)

Upstream emissions assets in Macro represent upstream commodity supply processes where emissions are explicitly tracked. They take in a source commodity, pass that commodity into the modeled system, and route associated CO2 emissions to a sink according to an `emission_rate`. These assets are defined using either JSON or CSV input files placed in the `assets` directory, typically named with descriptive identifiers like `upstreamemissions.json` or `upstreamemissions.csv`.

The current implementation is generic over commodity type, so the same asset can represent upstream emissions for liquid fuels, natural gas, or other commodities supported by the model.

For backward compatibility, `FossilFuelsUpstream` remains available as an alias of `UpstreamEmissions`.

## [Asset Structure](@id upstreamemissions_asset_structure)

An upstream emissions asset consists of four main components:

1. **Transformation Component**: Balances commodity throughput and emissions
2. **Source Commodity Edge**: Represents the incoming upstream commodity flow
3. **Delivered Commodity Edge**: Represents the outgoing commodity flow into the modeled system
4. **CO2 Edge**: Represents emitted CO2 sent to a sink or location

Here is a graphical representation of the upstream emissions asset:

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'background': '#D1EBDE' }}}%%
flowchart LR
  subgraph "UpstreamEmissions"
  direction TB
    A{{..}}
    E((Commodity))
    F((Commodity))
    G((CO2))
    E a@--fossil_fuel_edge--> A
    A b@--fuel_edge--> F
    A c@--co2_edge--> G
  end
    style A fill:black,stroke:black,color:black;
    style E font-size:21px,r:55px,fill:#d3b683,stroke:black,color:black,stroke-dasharray: 3,5;
    style F font-size:21px,r:55px,fill:#d3b683,stroke:black,color:black,stroke-dasharray: 3,5;
    style G font-size:21px,r:55px,fill:#A9A9A9,stroke:black,color:black,stroke-dasharray: 3,5;
    linkStyle 0 stroke:#d3b683,stroke-width: 2px;
    a@{ animate: true };
    linkStyle 1 stroke:#d3b683,stroke-width: 2px;
    b@{ animate: true };
    linkStyle 2 stroke:#A9A9A9,stroke-width: 2px;
    c@{ animate: true };
```

## [Flow Equations](@id upstreamemissions_flow_equations)

The upstream emissions asset follows these relationships:

```math
\begin{aligned}
\text{flow}_{fuel} &= \text{flow}_{source} \\
\text{flow}_{co2} &= \text{flow}_{source} \cdot \epsilon_{emission\_rate}
\end{aligned}
```

Where:
- `flow` represents the flow of each commodity
- ``\epsilon`` represents the emission coefficient defined in the [Conversion Process Parameters](@ref upstreamemissions_conversion_process_parameters) section

## [Input File (Standard Format)](@id upstreamemissions_input_file)

The easiest way to include an upstream emissions asset in a model is to create a new file (either JSON or CSV) and place it in the `assets` directory together with the other assets.

```
your_case/
├── assets/
│   ├── upstreamemissions.json    # or upstreamemissions.csv
│   ├── other_assets.json
│   └── ...
├── system/
├── settings/
└── ...
```

This file can either be created manually, or using the `template_asset` function, as shown in the [Adding an Asset to a System](@ref) section of the User Guide. The file will be automatically loaded when you run your Macro model.

The following is an example of an upstream emissions asset input file:

```json
{
    "upstream_emissions": [
        {
            "type": "UpstreamEmissions",
            "instance_data": [
                {
                    "id": "liquid_fuels_supply_SE",
                    "location": "SE",
                    "fuel_commodity": "LiquidFuels",
                    "fossil_fuel_commodity": "LiquidFuels",
                    "emission_rate": 0.25,
                    "fuel_investment_cost": 2500,
                    "fuel_fixed_om_cost": 100,
                    "fuel_variable_om_cost": 2.0,
                    "co2_sink": "co2_atm_SE"
                }
            ]
        }
    ]
}
```

!!! tip "Global Data vs Instance Data"
    When working with JSON input files, the `global_data` field can be used to group data that is common to all instances of the same asset type. This is useful for setting constraints that are common to all instances of the same asset type and avoid repeating the same data for each instance. See the [Examples](@ref "upstreamemissions_examples") section below for an example.

The following tables outline the attributes that can be set for an upstream emissions asset.

### Essential Attributes
| Field | Type | Description |
|--------------|---------|------------|
| `type` | String | Asset type identifier: "UpstreamEmissions" |
| `id` | String | Unique identifier for the upstream emissions instance |
| `location` | String | Geographic location/node identifier |

### [Conversion Process Parameters](@id upstreamemissions_conversion_process_parameters)
| Field | Type | Description | Units | Default |
|--------------|---------|------------|----------------|----------|
| `emission_rate` | Float64 | CO2 emissions per unit of source commodity throughput | commodity-dependent | 0.0 |
| `fuel_commodity` | String | Commodity delivered by the `fuel_edge` | - | missing |
| `fossil_fuel_commodity` | String | Commodity consumed by the `fossil_fuel_edge` | - | missing |
| `co2_sink` | String | End vertex for emitted CO2 | - | missing |

Simple-format edge attributes use edge-specific prefixes. For example, delivered commodity edge fields are written as `fuel_investment_cost`, `fuel_existing_capacity`, and `fuel_constraints`; source commodity edge fields use the `fossil_fuel_` prefix; and CO2 edge fields use the `co2_` prefix.

### [Constraints Configuration](@id "upstreamemissions_constraints")
Upstream emissions assets can have different constraints applied to them, and the user can configure them using the following fields:

| Field | Type | Description |
|--------------|---------|------------|
| `transform_constraints` | Dict{String,Bool} | List of constraints applied to the transformation component. |
| `fuel_constraints` | Dict{String,Bool} | List of constraints applied to the delivered commodity edge. |
| `fossil_fuel_constraints` | Dict{String,Bool} | List of constraints applied to the source commodity edge. |
| `co2_constraints` | Dict{String,Bool} | List of constraints applied to the CO2 edge. |

Users can refer to the [Adding Asset Constraints to a System](@ref) section of the User Guide for a list of all the constraints that can be applied to an upstream emissions asset.

#### Default constraints
To simplify the input file and the asset configuration, the following constraints are applied to the upstream emissions asset by default:

- [Balance constraint](@ref balance_constraint_ref) (applied to the transformation component)

### Investment Parameters
| Field | Type | Description | Units | Default |
|--------------|---------|------------|----------------|----------|
| `fuel_can_retire` | Boolean | Whether delivered commodity capacity can be retired | - | edge default |
| `fuel_can_expand` | Boolean | Whether delivered commodity capacity can be expanded | - | edge default |
| `fuel_existing_capacity` | Float64 | Initial installed delivered commodity capacity | MW or commodity flow per timestep | edge default |
| `fuel_capacity_size` | Float64 | Unit size for capacity decisions | - | edge default |

#### Additional Investment Parameters

**Maximum and minimum capacity constraints**

If [`MaxCapacityConstraint`](@ref max_capacity_constraint_ref) or [`MinCapacityConstraint`](@ref min_capacity_constraint_ref) are added to the constraints dictionary for the delivered commodity edge, the following parameters are used by Macro:

| Field | Type | Description | Units | Default |
|--------------|---------|------------|----------------|----------|
| `fuel_max_capacity` | Float64 | Maximum allowed delivered commodity capacity | MW or commodity flow per timestep | Inf |
| `fuel_min_capacity` | Float64 | Minimum allowed delivered commodity capacity | MW or commodity flow per timestep | 0.0 |

### Economic Parameters
| Field | Type | Description | Units | Default |
|--------------|---------|------------|----------------|----------|
| `fuel_investment_cost` | Float64 | CAPEX per unit delivered commodity capacity | \$/MW or \$/commodity-flow | edge default |
| `fuel_annualized_investment_cost` | Union{Nothing,Float64} | Annualized CAPEX | \$/MW/yr or \$/commodity-flow/yr | calculated |
| `fuel_fixed_om_cost` | Float64 | Fixed O&M costs for the delivered commodity edge | \$/MW/yr | edge default |
| `fuel_variable_om_cost` | Float64 | Variable O&M costs for the delivered commodity edge | \$/MWh or \$/commodity unit | edge default |
| `fuel_wacc` | Float64 | Weighted average cost of capital | fraction | edge default |
| `fuel_lifetime` | Int | Asset lifetime in years | years | edge default |
| `fuel_capital_recovery_period` | Int | Investment recovery period | years | edge default |
| `fuel_retirement_period` | Int | Retirement period | years | edge default |

### Operational Parameters
| Field | Type | Description | Units | Default |
|--------------|---------|------------|----------------|----------|
| `fuel_availability` | Dict | Availability file path and header for the delivered commodity edge | - | Empty |

#### Additional Operational Parameters

**Minimum flow constraint**

If [`MinFlowConstraint`](@ref min_flow_constraint_ref) is added to the constraints dictionary for the delivered commodity edge, the following parameter is used:

| Field | Type | Description | Units | Default |
|--------------|---------|------------|----------------|----------|
| `fuel_min_flow_fraction` | Float64 | Minimum delivered flow as fraction of capacity | fraction | 0.0 |

**Ramping limit constraint**

If [`RampingLimitConstraint`](@ref ramping_limits_constraint_ref) is added to the constraints dictionary for the delivered commodity edge, the following parameters are used:

| Field | Type | Description | Units | Default |
|--------------|---------|------------|----------------|----------|
| `fuel_ramp_up_fraction` | Float64 | Maximum increase in delivered flow between timesteps | fraction | 1.0 |
| `fuel_ramp_down_fraction` | Float64 | Maximum decrease in delivered flow between timesteps | fraction | 1.0 |

## [Types - Asset Structure](@id upstreamemissions_type_definition)

The `UpstreamEmissions` asset is defined as follows:

```julia
struct UpstreamEmissions{T} <: AbstractAsset
    id::AssetId
    fossilfuelsupstream_transform::Transformation
    fossil_fuel_edge::Edge{<:T}
    fuel_edge::Edge{<:T}
    co2_edge::Edge{<:CO2}
end

const FossilFuelsUpstream = UpstreamEmissions
```

## [Constructors](@id upstreamemissions_constructors)

### Default constructors

```julia
UpstreamEmissions(
    id::AssetId,
    fossilfuelsupstream_transform::Transformation,
    fossil_fuel_edge::Edge{<:T},
    fuel_edge::Edge{<:T},
    co2_edge::Edge{<:CO2}
) where {T<:LiquidFuels}

UpstreamEmissions(
    id::AssetId,
    fossilfuelsupstream_transform::Transformation,
    fossil_fuel_edge::Edge{<:T},
    fuel_edge::Edge{T},
    co2_edge::Edge{<:CO2}
) where {T<:Commodity}
```

### Factory constructor
```julia
make(asset_type::Type{UpstreamEmissions}, data::AbstractDict{Symbol,Any}, system::System)
```

| Field | Type | Description |
|--------------|---------|------------|
| `asset_type` | `Type{UpstreamEmissions}` | Macro type of the asset |
| `data` | `AbstractDict{Symbol,Any}` | Dictionary containing the input data for the asset |
| `system` | `System` | System to which the asset belongs |

## [Examples](@id upstreamemissions_examples)

This section contains examples of how to use the upstream emissions asset in a Macro model.

### Multiple upstream emissions assets with shared defaults

This example shows how to create two upstream emissions assets in different zones with shared global data and zone-specific `emission_rate` and cost assumptions.

**JSON Format:**

```json
{
    "upstream_emissions": [
        {
            "type": "UpstreamEmissions",
            "global_data": {
                "fuel_commodity": "NaturalGas",
                "fossil_fuel_commodity": "NaturalGas",
                "fuel_variable_om_cost": 1.0,
                "co2_sink": "co2_atm"
            },
            "instance_data": [
                {
                    "id": "natgas_supply_SE",
                    "location": "SE",
                    "emission_rate": 0.18,
                    "fuel_investment_cost": 1200,
                    "fuel_fixed_om_cost": 80
                },
                {
                    "id": "natgas_supply_NE",
                    "location": "NE",
                    "emission_rate": 0.16,
                    "fuel_investment_cost": 1500,
                    "fuel_fixed_om_cost": 95
                }
            ]
        }
    ]
}
```

**CSV Format:**

| Type | id | location | fuel_commodity | fossil_fuel_commodity | emission_rate | fuel_investment_cost | fuel_fixed_om_cost | fuel_variable_om_cost | co2_sink |
|------|----|----------|----------------|-----------------------|---------------|-----------------|---------------|------------------|----------|
| UpstreamEmissions | natgas_supply_SE | SE | NaturalGas | NaturalGas | 0.18 | 1200 | 80 | 1.0 | co2_atm |
| UpstreamEmissions | natgas_supply_NE | NE | NaturalGas | NaturalGas | 0.16 | 1500 | 95 | 1.0 | co2_atm |

## [Best Practices](@id upstreamemissions_best_practices)

1. Use explicit commodity names for both `fuel_commodity` and `fossil_fuel_commodity`, even when they are the same.
2. Set `co2_sink` explicitly when emissions should be routed to a dedicated CO2 node rather than the asset location.
3. Keep `emission_rate` units consistent with the commodity flow units used in the rest of the model.
4. Use `global_data` for shared cost and commodity settings when creating many upstream emissions assets.
5. If this asset represents a physical import interface, apply capacity and ramping constraints on the delivered commodity edge rather than the transformation.

## [Input File (Advanced Format)](@id upstreamemissions_advanced_json_csv_input_format)

Macro provides an advanced format for defining upstream emissions assets, offering users and modelers detailed control over transformation and edge specifications.

To understand the advanced format, consider the [graph representation](@ref upstreamemissions_asset_structure) and the [type definition](@ref upstreamemissions_type_definition) of an upstream emissions asset. The input file mirrors this hierarchical structure.

An upstream emissions asset in Macro is composed of a `Transformation` object and three `Edge` objects. The input file for an upstream emissions asset is therefore organized as follows:

```json
{
    "transforms": {
        // ... transformation-specific attributes ...
    },
    "edges": {
        "fossil_fuel_edge": {
            // ... source commodity edge-specific attributes ...
        },
        "fuel_edge": {
            // ... delivered commodity edge-specific attributes ...
        },
        "co2_edge": {
            // ... CO2 edge-specific attributes ...
        }
    }
}
```

Below is an example of an advanced input file for an upstream emissions asset:

```json
{
    "upstream_emissions": [
        {
            "type": "UpstreamEmissions",
            "instance_data": [
                {
                    "id": "liquid_fuels_supply_SE",
                    "location": "SE",
                    "transforms": {
                        "timedata": "LiquidFuels",
                        "emission_rate": 0.25,
                        "constraints": {
                            "BalanceConstraint": true
                        }
                    },
                    "edges": {
                        "fossil_fuel_edge": {
                            "commodity": "LiquidFuels",
                            "start_vertex": "liquid_fuels_source_SE"
                        },
                        "fuel_edge": {
                            "commodity": "LiquidFuels",
                            "end_vertex": "liquid_fuels_SE",
                            "investment_cost": 2500,
                            "fixed_om_cost": 100,
                            "variable_om_cost": 2.0
                        },
                        "co2_edge": {
                            "commodity": "CO2",
                            "end_vertex": "co2_atm_SE"
                        }
                    }
                }
            ]
        }
    ]
}
```

### Key Points

- The `transforms` block configures the internal transformation object, including `timedata`, `constraints`, and `emission_rate`.
- The `fossil_fuel_edge` and `fuel_edge` can be assigned any supported commodity type, allowing the asset to model upstream emissions for multiple sectors.