# [Variable Renewable Energy Resources (VRE)](@id vre)

## Contents

[Overview](@ref vre_overview) | [Asset Structure](@ref vre_asset_structure) | [Input File (Standard Format)](@ref vre_input_file) | [Types - Asset Structure](@ref vre_type_definition) | [Constructors](@ref vre_constructors) | [Examples](@ref vre_examples) | [Best Practices](@ref vre_best_practices) | [Input File (Advanced Format)](@ref vre_advanced_json_csv_input_format)

## [Overview](@id vre_overview)

VRE (Variable Renewable Energy) assets in Macro represent electricity generation technologies with variable output, such as wind turbines and solar photovoltaic systems. These assets are defined using either JSON or CSV input files placed in the `assets` directory, typically named with descriptive identifiers like `vre.json` or `renewables.csv`.

## [Asset Structure](@id vre_asset_structure)

A VRE asset consists of two main components:

1. **Transformation Component**
2. **Electricity Edge**: Represents the electricity production flow to the grid

Here is a graphical representation of the VRE asset:

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'background': '#D1EBDE' }}}%%
flowchart LR
  subgraph VRE
  direction LR
  A((Energy Source)) e1@--> B{{..}}
  B e2@--> C((Electricity))
  e1@{ animate: true }
  e2@{ animate: true }
 end
    style A r:55px,fill:#FFD700,stroke:black,color:black,stroke-dasharray: 3,5;
    style B r:55px,fill:black,stroke:black,color:black,stroke-dasharray: 3,5;
    style C font-size:20px,r:55px,fill:#FFD700,stroke:black,color:black,stroke-dasharray: 3,5;
    linkStyle 0 stroke:#FFD700, stroke-width: 2px;
    linkStyle 1 stroke:#FFD700, stroke-width: 2px;
```

## [Input File (Standard Format)](@id vre_input_file)

The easiest way to include a VRE asset in a model is to create a new file (either JSON or CSV) and place it in the `assets` directory together with the other assets. 

```
your_case/
├── assets/
│   ├── vre.json    # or vre.csv
│   ├── other_assets.json
│   └── ...
├── system/
├── settings/
└── ...
```

This file can either be created manually, or using the `template_asset` function, as shown in the [Adding an Asset to a System](@ref) section of the User Guide. The file will be automatically loaded when you run your Macro model. 

The following is an example of a VRE asset input file:
```json
{
    "existing_vre": [
        {
            "type": "VRE",
            "instance_data": [
                {
                    "id": "existing_solar_MIDAT",
                    "can_expand": false,
                    "can_retire": true,
                    "location": "MIDAT",
                    "fixed_om_cost": 22887,
                    "capacity_size": 10.578,
                    "existing_capacity": 2974.6,
                    "availability": {
                        "timeseries": {
                            "path": "system/availability.csv",
                            "header": "MIDAT_solar_photovoltaic_1"
                        }
                    }
                }
            ]
        }
    ]
}
```

!!! tip "Global Data vs Instance Data"
    When working with JSON input files, the `global_data` field can be used to group data that is common to all instances of the same asset type. This is useful for setting constraints that are common to all instances of the same asset type and avoid repeating the same data for each instance. See the [Examples](@ref "vre_examples") section below for an example.

The following tables outline the attributes that can be set for a VRE asset.

### Essential Attributes
| Field | Type | Description |
|--------------|---------|------------|
| `type` | String | Asset type identifier: "VRE" |
| `id` | String | Unique identifier for the VRE instance |
| `location` | String | Geographic location/node identifier |

### [Constraints configuration](@id vre_constraints)
VRE assets can have different constraints applied to them, and the user can configure them using the following fields:

| Field | Type | Description |
|--------------|---------|------------|
| `transform_constraints` | Dict{String,Bool} | List of constraints applied to the transformation component. |
| `elec_constraints` | Dict{String,Bool} | List of constraints applied to the electricity edge. |

Users can refer to the [Adding Asset Constraints to a System](@ref) section of the User Guide for a list of all the constraints that can be applied to a VRE asset.

#### Default constraints
To simplify the input file and the asset configuration, the following constraints are applied to the VRE asset by default:

- [Balance constraint](@ref balance_constraint_ref) (applied to the transformation component)

### Investment Parameters
| Field | Type | Description | Units | Default |
|--------------|---------|------------|----------------|----------|
| `can_retire` | Boolean | Whether capacity can be retired | - | true |
| `can_expand` | Boolean | Whether capacity can be expanded | - | true |
| `existing_capacity` | Float64 | Initial installed capacity | MW | 0.0 |
| `capacity_size` | Float64 | Unit size for capacity decisions | - | 1.0 |

#### Additional Investment Parameters

**Maximum and minimum capacity constraints**

If [`MaxCapacityConstraint`](@ref max_capacity_constraint_ref) or [`MinCapacityConstraint`](@ref min_capacity_constraint_ref) are added to the constraints dictionary for the electricity edge, the following parameters are used by Macro:

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
| `availability` | Dict | Availability file path and header | - | Empty |

## [Types - Asset Structure](@id vre_type_definition)

The `VRE` asset is defined as follows:

```julia
struct VRE <: AbstractAsset
    id::AssetId
    energy_transform::Transformation
    edge::Edge{<:Electricity}
end
```

## [Constructors](@id vre_constructors)

### Default constructor

```julia
VRE(id::AssetId, energy_transform::Transformation, edge::Edge{<:Electricity})
```

### Factory constructor
```julia
make(asset_type::Type{VRE}, data::AbstractDict{Symbol,Any}, system::System)
```

| Field | Type | Description |
|--------------|---------|------------|
| `asset_type` | `Type{VRE}` | Macro type of the asset |
| `data` | `AbstractDict{Symbol,Any}` | Dictionary containing the input data for the asset |
| `system` | `System` | System to which the asset belongs |

## [Examples](@id vre_examples)
This section contains examples of how to use the VRE asset in a Macro model.

### Multiple VRE assets in different zones (existing and new)

This example shows how to define existing and new VRE assets in different zones. The existing VRE assets have initial capacity that is only allowed to be retired. The new VRE assets do not have an existing capacity but can be expanded. A `MaxCapacityConstraint` constraint is applied to the electricity edge with a maximum capacity determined by the `max_capacity` field.

**JSON Format:**

Note that the `global_data` field is used to set the fields and constraints that are common to all instances of the same asset type.

```json
{
    "existing_vre": [
        {
            "type": "VRE",
            "global_data": {
                "can_expand": false,
                "can_retire": true
            },
            "instance_data": [
                {
                    "id": "existing_solar_MIDAT",
                    "location": "MIDAT",
                    "fixed_om_cost": 22887,
                    "capacity_size": 10.578,
                    "existing_capacity": 2974.6,
                    "availability": {
                        "timeseries": {
                            "path": "system/availability.csv",
                            "header": "existing_solar_MIDAT"
                        }
                    }
                },
                {
                    "id": "existing_solar_SE",
                    "location": "SE",
                    "fixed_om_cost": 22887,
                    "capacity_size": 17.142,
                    "existing_capacity": 8502.2,
                    "availability": {
                        "timeseries": {
                            "path": "system/availability.csv",
                            "header": "existing_solar_SE"
                        }
                    }
                },
                {
                    "id": "existing_solar_NE",
                    "location": "NE",
                    "fixed_om_cost": 22887,
                    "capacity_size": 3.63,
                    "existing_capacity": 1629.6,
                    "availability": {
                        "timeseries": {
                            "path": "system/availability.csv",
                            "header": "existing_solar_NE"
                        }
                    }
                },
                {
                    "id": "existing_wind_NE",
                    "location": "NE",
                    "fixed_om_cost": 43000,
                    "capacity_size": 86.17,
                    "existing_capacity": 3654.5,
                    "availability": {
                        "timeseries": {
                            "path": "system/availability.csv",
                            "header": "existing_wind_NE"
                        }
                    }
                },
                {
                    "id": "existing_wind_MIDAT",
                    "location": "MIDAT",
                    "fixed_om_cost": 43000,
                    "capacity_size": 161.2,
                    "existing_capacity": 3231.6,
                    "availability": {
                        "timeseries": {
                            "path": "system/availability.csv",
                            "header": "existing_wind_MIDAT"
                        }
                    }
                }
            ]
        }
    ],
    "new_vre": [
        {
            "type": "VRE",
            "global_data": {
                "can_expand": true,
                "can_retire": false,
                "constraints": {
                    "MaxCapacityConstraint": true
                }
            },
            "instance_data": [
                {
                    "id": "NE_offshorewind",
                    "location": "NE",
                    "fixed_om_cost": 57294.4,
                    "investment_cost": 173830.4242,
                    "max_capacity": 32928.493,
                    "availability": {
                        "timeseries": {
                            "path": "system/availability.csv",
                            "header": "NE_offshorewind"
                        }
                    }
                },
                {
                    "id": "SE_utilitypv",
                    "location": "SE",
                    "fixed_om_cost": 13510.19684,
                    "investment_cost": 40649.03073,
                    "max_capacity": 1041244,
                    "availability": {
                        "timeseries": {
                            "path": "system/availability.csv",
                            "header": "SE_utilitypv"
                        }
                    }
                },
                {
                    "id": "MIDAT_utilitypv",
                    "location": "MIDAT",
                    "fixed_om_cost": 13510.19684,
                    "investment_cost": 41179.38174,
                    "max_capacity": 26783,
                    "availability": {
                        "timeseries": {
                            "path": "system/availability.csv",
                            "header": "MIDAT_utilitypv"
                        }
                    }
                },
                {
                    "id": "NE_utilitypv",
                    "location": "NE",
                    "fixed_om_cost": 13510.19684,
                    "investment_cost": 43445.847,
                    "max_capacity": 156573,
                    "availability": {
                        "timeseries": {
                            "path": "system/availability.csv",
                            "header": "NE_utilitypv"
                        }
                    }
                },
                {
                    "id": "SE_landbasedwind",
                    "location": "SE",
                    "fixed_om_cost": 26256.10757,
                    "investment_cost": 74858.52871,
                    "max_capacity": 84058,
                    "availability": {
                        "timeseries": {
                            "path": "system/availability.csv",
                            "header": "SE_landbasedwind"
                        }
                    }
                },
                {
                    "id": "MIDAT_landbasedwind",
                    "location": "MIDAT",
                    "fixed_om_cost": 26256.10757,
                    "investment_cost": 78331.91929,
                    "max_capacity": 1384,
                    "availability": {
                        "timeseries": {
                            "path": "system/availability.csv",
                            "header": "MIDAT_landbasedwind"
                        }
                    }
                },
                {
                    "id": "NE_landbasedwind",
                    "location": "NE",
                    "fixed_om_cost": 26256.10757,
                    "investment_cost": 90411.84793,
                    "max_capacity": 6841,
                    "availability": {
                        "timeseries": {
                            "path": "system/availability.csv",
                            "header": "NE_landbasedwind"
                        }
                    }
                }
            ]
        }
    ]
}
```

**CSV Format:**

| Type | id | location | can\_expand | can\_retire | fixed\_om\_cost | capacity\_size | existing\_capacity | availability--timeseries--path | availability--timeseries--header |
|------|----|----------|-------------------|-------------------|-----------------|----------------|-------------------|--------------------------------|----------------------------------|
| VRE | existing\_solar\_MIDAT | MIDAT | false | true | 22887 | 10.578 | 2974.6 | system/availability.csv | existing\_solar\_MIDAT |
| VRE | existing\_solar\_SE | SE | false | true | 22887 | 17.142 | 8502.2 | system/availability.csv | existing\_solar\_SE |
| VRE | existing\_solar\_NE | NE | false | true | 22887 | 3.63 | 1629.6 | system/availability.csv | existing\_solar\_NE |
| VRE | existing\_wind\_NE | NE | false | true | 43000 | 86.17 | 3654.5 | system/availability.csv | existing\_wind\_NE |
| VRE | existing\_wind\_MIDAT | MIDAT | false | true | 43000 | 161.2 | 3231.6 | system/availability.csv | existing\_wind\_MIDAT |

| Type | id | location | can\_expand | can\_retire | constraints--MaxCapacityConstraint | fixed\_om\_cost | investment\_cost | max\_capacity | availability--timeseries--path | availability--timeseries--header |
|------|----|----------|-------------------|-------------------|----------------------------------------|-----------------|------------------|---------------|--------------------------------|----------------------------------|
| VRE | NE\_offshorewind | NE | true | false | true | 57294.4 | 173830.4242 | 32928.493 | system/availability.csv | NE\_offshorewind |
| VRE | SE\_utilitypv | SE | true | false | true | 13510.19684 | 40649.03073 | 1041244 | system/availability.csv | SE\_utilitypv |
| VRE | MIDAT\_utilitypv | MIDAT | true | false | true | 13510.19684 | 41179.38174 | 26783 | system/availability.csv | MIDAT\_utilitypv |
| VRE | NE\_utilitypv | NE | true | false | true | 13510.19684 | 43445.847 | 156573 | system/availability.csv | NE\_utilitypv |
| VRE | SE\_landbasedwind | SE | true | false | true | 26256.10757 | 74858.52871 | 84058 | system/availability.csv | SE\_landbasedwind |
| VRE | MIDAT\_landbasedwind | MIDAT | true | false | true | 26256.10757 | 78331.91929 | 1384 | system/availability.csv | MIDAT\_landbasedwind |
| VRE | NE\_landbasedwind | NE | true | false | true | 26256.10757 | 90411.84793 | 6841 | system/availability.csv | NE\_landbasedwind |

## [Best Practices](@id vre_best_practices)

1. **Use global data for common fields and constraints**: Use the `global_data` field to set the fields and constraints that are common to all instances of the same asset type.
2. **Set realistic availability profiles**: Ensure availability profiles reflect actual resource characteristics and correctly capture the temporal variations of the resource.
3. **Use meaningful IDs**: Choose descriptive identifiers that indicate location and technology type
4. **Consider capacity constraints**: Set appropriate maximum capacity limits based on resource potential
5. **Use constraints selectively**: Only enable constraints that are necessary for your modeling needs
6. **Validate costs**: Ensure investment and O&M costs are in appropriate units
7. **Test configurations**: Start with simple configurations and gradually add complexity.

## [Input File (Advanced Format)](@id vre_advanced_json_csv_input_format)

Macro provides an advanced format for defining VRE assets, offering users and modelers detailed control over asset specifications. This format builds upon the standard format and is ideal for those who need more comprehensive customization.

To understand the advanced format, consider the [graph representation](@ref vre_asset_structure) and the [type definition](@ref vre_type_definition) of a VRE asset. The input file mirrors this hierarchical structure.

A VRE asset in Macro is composed of a transformation component, represented by a `Transformation` object, and an electricity edge, represented by an `Edge` object. The input file for a VRE asset is therefore organized as follows:

```json
{
    "transforms": {
        // ... transformation-specific attributes ...
    },
    "edges": {
        "edge": {
            // ... edge-specific attributes ...
        }
    }
}
```
Each top-level key (e.g., "transforms" or "edges") denotes a component type. The second-level keys either specify the attributes of the component (when there is a single instance) or identify the instances of the component (e.g., "edge") when there are multiple instances. For multiple instances, a third-level key details the attributes for each instance.

Below is an example of an input file for a VRE asset that sets up multiple renewable energy facilities in different regions.

```json
{
    "VRE": {
        "type": "VRE",
        "global_data": {
            "transforms": {
                "timedata": "Electricity"
            },
            "edges": {
                "edge": {
                    "unidirectional": true,
                    "has_capacity": true,
                    "commodity": "Electricity"
                }
            }
        },
        "instance_data": [
            {
                "id": "MA_solar_pv",
                "edges": {
                    "edge": {
                        "can_retire": true,
                        "max_capacity": -1,
                        "can_expand": true,
                        "constraints": {
                            "CapacityConstraint": true
                        },
                        "min_capacity": 0,
                        "commodity": "Electricity",
                        "fixed_om_cost": 18760,
                        "end_vertex": "elec_MA",
                        "investment_cost": 85300,
                        "variable_om_cost": 0,
                        "capacity_size": 1,
                        "availability": {
                            "timeseries": {
                                "header": "MA_solar_pv",
                                "path": "system/vre_availability.csv"
                            }
                        },
                        "existing_capacity": 0
                    }
                }
            },
            {
                "id": "CT_onshore_wind",
                "edges": {
                    "edge": {
                        "can_retire": true,
                        "max_capacity": -1,
                        "can_expand": true,
                        "constraints": {
                            "CapacityConstraint": true
                        },
                        "min_capacity": 0,
                        "commodity": "Electricity",
                        "fixed_om_cost": 43205,
                        "end_vertex": "elec_CT",
                        "investment_cost": 97200,
                        "variable_om_cost": 0.1,
                        "capacity_size": 1,
                        "availability": {
                            "timeseries": {
                                "header": "CT_onshore_wind",
                                "path": "system/vre_availability.csv"
                            }
                        },
                        "existing_capacity": 0
                    }
                }
            },
            {
                "id": "CT_solar_pv",
                "edges": {
                    "edge": {
                        "can_retire": true,
                        "max_capacity": -1,
                        "can_expand": true,
                        "constraints": {
                            "CapacityConstraint": true
                        },
                        "min_capacity": 0,
                        "commodity": "Electricity",
                        "fixed_om_cost": 18760,
                        "end_vertex": "elec_CT",
                        "investment_cost": 85300,
                        "variable_om_cost": 0,
                        "capacity_size": 1,
                        "availability": {
                            "timeseries": {
                                "header": "CT_solar_pv",
                                "path": "system/vre_availability.csv"
                            }
                        },
                        "existing_capacity": 0
                    }
                }
            },
            {
                "id": "ME_onshore_wind",
                "edges": {
                    "edge": {
                        "can_retire": true,
                        "max_capacity": -1,
                        "can_expand": true,
                        "constraints": {
                            "CapacityConstraint": true
                        },
                        "min_capacity": 0,
                        "commodity": "Electricity",
                        "fixed_om_cost": 43205,
                        "end_vertex": "elec_ME",
                        "investment_cost": 97200,
                        "variable_om_cost": 0.1,
                        "capacity_size": 1,
                        "availability": {
                            "timeseries": {
                                "header": "ME_onshore_wind",
                                "path": "system/vre_availability.csv"
                            }
                        },
                        "existing_capacity": 0
                    }
                }
            }
        ]
    }
}
```

### Key Points

- The `global_data` field is utilized to define attributes and constraints that apply universally to all instances of a particular asset type.
- The `end_vertex` field indicates the node to which the electricity edge is connected. This node must be defined in the `nodes.json` file.
- For a comprehensive list of attributes that can be configured for the transformation and edge components, refer to the [transformations](@ref manual-transformation-fields) and [edges](@ref manual-edges-fields) pages of the Macro manual.
