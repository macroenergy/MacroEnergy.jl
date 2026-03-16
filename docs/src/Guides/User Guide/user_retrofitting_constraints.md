# Description of the Retrofitting Feature

This feature allows the capacity of one asset to be retrofitted into another, for assets with capacity decisions defined on their edges. You can find the [mathematical formulation of the retrofitting constraint here.](@ref retrofitting_constraint_ref)

# Adding Retrofitting Constraints to a System

Adding retrofitting constraints to a system requires the following steps:

1. Turning on the retrofitting setting in the `system/macro_settings.json` file
2. Making a JSON file for your asset that can be retrofitted.
3. Making a JSON file for the retrofitting asset (only required if your asset can be retrofitted into another type of asset).

## 1. Turning on the retrofitting setting in the `system/macro_settings.json` file

In the `system/macro_settings.json` file, make sure to have the line `"Retrofitting": true`.

```json
{
    // other settings
    "Retrofitting": true
}
```

## 2. Making your JSON file for the asset that can be retrofitted

In the example JSON file below for **traditional cement plants**, there are 3 retrofit options for `traditional_cement_MA`:

1. A traditional cement plant with cheaper O+M costs
2. A traditional plant with a different fuel option
3. An oxyfuel cement plant

For `traditional_cement_CT` and `traditional_cement_ME`, there is only one option to retrofit into an oxyfuel cement plant.

### Setting up edges that can be retrofitted

In the JSON file for the asset that can be retrofitted, `can_retrofit` must be set to `true` for **edges that can be retrofitted**.

For each instance of the asset that can be retrofitted, retrofit options are described in a list of dictionaries called `retrofit_options`.

### Fields in each `retrofit_options` entry

For each dictionary in `retrofit_options`:

1. `template_id` specifies the asset whose parameters are used as the template for the retrofitting option.
2. `id` is the name of the new retrofitting asset.
3. `is_retrofit` must be set to `true` for **retrofitting edges**.
4. `retrofit_efficiency` defines the conversion rate between the original (retrofittable) capacity and the new retrofitting capacity.
    - A value of 0.9 means that every 1 unit of capacity retrofitted results in 0.9 units of capacity on the `is_retrofit` edge
    - If it is not included, it is set to the default value specified in the `asset.jl` file, if one is provided.
5. `investment_cost` is the cost of retrofitting.
6. `can_expand` should normally be set to `true` to avoid issues if the template_id asset itself cannot expand.
7. `existing_capacity` should typically be set to `0` to prevent unintended inheritance of nonzero capacity from the `template_id` asset.

### How new retrofit assets are created

For each entry in `retrofit_options`, Macro automatically creates a new retrofit asset by recursively merging:

1. The option-specific fields provided in that entry, and
2. The parameters of the asset referenced by `template_id`.

Fields defined in the `retrofit_options` dictionary take precedence and overwrite the corresponding fields inherited from the `template_id` asset. All other fields are inherited unchanged.

Thus, each retrofit option only needs to list the parameters that should **be different** from the `template_id` asset; everything else is copied automatically.

```json
{
    "TradCementPlant": [
        {
            "type": "CementPlant",
            "global_data": {
                "fuel_commodity": "NaturalGas",
                "nodes": {},
                "transforms": {
                    "id": "traditional_cement",
                    "timedata": "Cement",
                    "fuel_consumption_rate": 0.9311,
                    "elec_consumption_rate": 0.07,
                    "fuel_emission_rate": 0.296,
                    "process_emission_rate": 0.536,
                    "emission_capture_rate": 0,
                    "constraints": {
                        "BalanceConstraint": true
                    }
                },
                "edges":{
                    "elec_edge":{
                        "type": "Electricity"
                    },
                    "cement_edge":{
                        "type": "Cement",
                        "has_capacity": true,
                        "can_retire": true,
                        "can_expand": true,
                        "capacity_size": 125,
                        "investment_cost": 220939,
                        "fixed_om_cost": 38,
                        "variable_om_cost": 0,
                        "end_vertex": "cement_produced",
                        // "can_retrofit" must be set to be true for retrofittable edges
                        "can_retrofit": true                             
                    },
                    "fuel_edge": {
                        "type": "NaturalGas",
                        "start_vertex": "ng_source"
                    },
                    "co2_emissions_edge": {
                        "type": "CO2",
                        "end_vertex": "cement_co2_sink"
                    },
                    "co2_captured_edge": {
                        "type": "CO2Captured",
                        "end_vertex": "co2_captured_sink"
                    }
                }
            },
            "instance_data": [
                {
                    "id": "traditional_cement_MA",
                    "location": "MA",
                    "edges": {
                        "cement_edge":{
                            "existing_capacity": 100
                        }
                    },
                    // "retrofit_options" is the list of retrofit options
                    "retrofit_options": [                                   
                        {
                            // "template_id" is template asset for the retrofit option
                            "template_id": "traditional_cement_MA",

                            // "id" is the name of the new retrofitting asset     
                            "id": "traditional_cement_MA_retrofitfom",      

                            "edges": {
                                "cement_edge": {
                                    // "is_retrofit" must be true for retrofitting edges
                                    "is_retrofit": true, 

                                    // "retrofit_efficiency" is the retrofitting conversion rate                
                                    "retrofit_efficiency": 0.9,

                                    // "investment_cost" is the cost of retrofitting
                                    "investment_cost": 5000,

                                    // Recommended: ensure retrofit option can expand
                                    "can_expand": true,

                                    // Recommended: make sure there is no existing capacity
                                    "existing_capacity": 0,

                                    // Example of a parameter that is changed from the template
                                    "fixed_om_cost": 10
                                }
                            }
                        },
                        {
                            "template_id": "traditional_cement_MA",
                            "id": "traditional_cement_MA_retrofitfuel",
                            "fuel_commodity": "LiquidFuels",
                            "transforms": {
                                "fuel_consumption_rate": 1.06,
                                "fuel_emission_rate": 0.05
                            },
                            "edges": {
                                "fuel_edge": {
                                    "type": "LiquidFuels",
                                    "start_vertex": "liqfuel_source"
                                },
                                "cement_edge": {
                                    "is_retrofit": true,
                                    "retrofit_efficiency": 1.0,
                                    "investment_cost": 220939,
                                    "can_expand": true,
                                    "existing_capacity": 0,
                                }
                            }
                        },
                        {
                            "template_id": "oxyfuel_cement_MA",
                            "id": "oxyfuel_cement_MA_retrofit",
                            "edges": {
                                "cement_edge": {
                                    "is_retrofit": true,
                                    "retrofit_efficiency": 1,
                                    "investment_cost": 50000,
                                    "can_expand": true,
                                    "existing_capacity": 0,
                                }
                            }
                        }
                    ]
                },
                {
                    "id": "traditional_cement_CT",
                    "location": "CT",
                    "edges": {
                        "cement_edge":{
                            "existing_capacity": 100
                        }
                    },
                    "retrofit_options": [
                        {
                            // This "template_id" asset is from the next example JSON file
                            "template_id": "oxyfuel_cement_CT",
                            "id": "oxyfuel_cement_CT_retrofit",
                            "edges": {
                                "cement_edge": {
                                    "is_retrofit": true,
                                    "retrofit_efficiency": 1,
                                    "investment_cost": 50000,
                                    "can_expand": true,
                                    "existing_capacity": 0,
                                }
                            }
                        }
                    ]
                },
                {
                    "id": "traditional_cement_ME",
                    "location": "ME",
                    "edges": {
                        "cement_edge": {
                            "existing_capacity": 100
                        }
                    },
                    "retrofit_options": [
                        {
                            // This "template_id" asset is also from the next example JSON file
                            "template_id": "oxyfuel_cement_ME",
                            "id": "oxyfuel_cement_ME_retrofit",
                            "edges": {
                                "cement_edge": {
                                    "is_retrofit": true,
                                    "retrofit_efficiency": 1,
                                    "investment_cost": 50000,
                                    "can_expand": true,
                                    "existing_capacity": 0,
                                }
                            }
                        }
                    ]
                }
            ]
        }
    ]
}
```

## 3. Making your JSON file for the retrofitting asset

The example JSON asset file below defines **oxyfuel cement plants**, which were referenced in the previous section as retrofit options for traditional cement plants. The structure of the file is the same as any standard asset input file.

!!! warning "File Naming Requirement"
    The JSON file that describes retrofitting assets must end with the suffix `_retrofit_option`. This naming convention ensures that the retrofitting asset’s input data are loaded **before** other asset files. Loading these files first allows their information to be referenced when constructing new retrofit assets using `template_id`.

### Preventing greenfield construction (optional)

If you want to ensure that this asset is used **only** as a retrofit asset and cannot be built as new (greenfield) capacity, set: `"can_expand": false`. This prevents the asset from being added as new capacity while still allowing it to serve as a template for retrofits.

```json
{
    "OxyFuelCementPlant": [
        {
            "type": "CementPlant",
            "global_data": {
                "fuel_commodity": "NaturalGas",
                "nodes": {},
                "transforms": {
                    "id": "oxyfuel_cement",
                    "timedata": "Cement",
                    "fuel_consumption_rate": 1.06,
                    "elec_consumption_rate": 0.295,
                    "fuel_emission_rate": 0.265,
                    "process_emission_rate": 0.536,
                    "co2_capture_rate": 0.95,
                    "constraints": {
                        "BalanceConstraint": true
                    }
                },
                "edges":{
                    "elec_edge":{
                        "type": "Electricity"
                    },
                    "cement_edge":{
                        "type": "Cement",
                        "unidirectional": true,
                        "has_capacity": true,
                        "can_retire": true,
                        "capacity_size": 125,
                        "investment_cost": 289854,
                        "fixed_om_cost": 58,
                        "variable_om_cost": 0,
                        "end_vertex": "cement_produced"
                    },
                    "fuel_edge": {
                        "commodity": "NaturalGas",
                        "type": "NaturalGas",
                        "start_vertex": "ng_source"
                    },
                    "co2_emissions_edge": {
                        "type": "CO2",
                        "end_vertex": "cement_co2_sink"
                    },
                    "co2_captured_edge": {
                        "type": "CO2Captured",
                        "end_vertex": "co2_captured_sink"
                    }
                }
            },
            "instance_data": [
                {
                    "id": "oxyfuel_cement_MA",
                    "location": "MA",
                    // "can_expand" is set to false to disallow greenfield build
                    "can_expand": false,
                    "existing_capacity": 0
                },
                {
                    // These are the "template_id" assets referenced in the previous file
                    "id": "oxyfuel_cement_CT",
                    "location": "CT",
                    "can_expand": true,
                    "existing_capacity": 0
                },
                {
                    "id": "oxyfuel_cement_ME",
                    "location": "ME",
                    "can_expand": false,
                    "existing_capacity": 0
                }
            ]
        }
    ]
}
```

## Common input mistakes to check for

- Is `"Retrofitting": true` in `settings/macro_settings.json`?
- Is `"can_retrofit": true` and `"is_retrofit": true` set properly?
- Is `"can_expand": true` for entries in `retrofitting_options`?
- Are parameters specified in the right structure in `retrofitting_options` to enable the recursive merge to work properly?
    - For example, is `cement_edge` within the `edges` dictionary?

## Tips

- You can access the retrofitting constraints with `model[:cRetrofitCapacity]` (`model` is the variable holding the JuMP model) to check if the constraint is formulated as expected.
