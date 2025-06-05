# Adding an Asset to a System

Adding a new Asset to your System requires five steps:

1. Create a new Asset file in your Assets folder
2. Duplicate the instance data for each version of the Asset you would like
3. Assign each Asset a unique ID
4. Add instance data to the Assets
5. Consolidate some instance data into global data

## Create a new Asset file

### Adding a single Asset

The best way to create a new Asset file is to use the template functions. If you wanted to add a `ThermalPower` Asset to your system, you could add it using the `template_asset` function, called with your System's asset folder:

```julia
julia> template_asset("ExampleSystems/template_example/assets", ThermalPower; style="simple", format="json")
```

Alternatively, you can call `template_asset` with your system object [that you have already created](@ref "Creating a new System"):

```julia
julia> system = template_system("ExampleSystems/template_example")
julia> template_asset(system, ThermalPower; style="simple", format="json")
```

#### Asset file name

Each call of the function will create a new `ThermalPower` Asset file. Successive calls will be numbered, i.e. `ThermalPower.json`, `ThermalPower_001.json`, `ThermalPower_002.json`, etc. The file name can be changed using the `asset_name` keyword argument. The following example will produce an Asset file called `thermalpower_example.json`:

```julia
julia> template_asset(system, ThermalPower; style="simple", format="json", asset_name="thermalpower_example")
```

#### Asset file format

The `format` keyword argument determines whether your new Asset file will be a CSV or JSON file. The default is a JSON file. Most of this guide will use JSON examples. [This section](@ref "Working with CSV Asset files") details how to work with CSV files.

#### Asset file style

The `style` keyword argument determines how much detail Macro will include in your new Asset file. The two options are`full` and `simple`. The `simple` option will return a Asset file which contains the minimum data fields necessary to define the Asset. Most simple description do not have nested dictionaries of inputs so are easy to read, particularly with CSV input files. The `full` option will return an Asset file with full descriptions of all the components and Constraints. This will include several nested dictionaries of all the options and inputs.

As an example, the `simple` version of our new `ThermalPower` Asset is:

```json
{
    "ThermalPower": {
        "type": "ThermalPower",
        "instance_data": [
            {
                "id": "ThermalPower",
                "location": null,
                "can_expand": true,
                "can_retire": true,
                "existing_capacity": 0,
                "capacity_size": 1,
                "timedata": "NaturalGas",
                "fuel_commodity": "NaturalGas",
                "co2_sink": null,
                "uc": false,
                "investment_cost": 0,
                "fixed_om_cost": 0,
                "variable_om_cost": 0,
                "fuel_consumption": 0,
                "electricity_consumption": 0,
                "emission_rate": 1,
                "startup_cost": 0,
                "startup_fuel_consumption": 0,
                "min_up_time": 0,
                "min_down_time": 0,
                "ramp_up_fraction": 0,
                "ramp_down_fraction": 0
            }
        ]
    }
}
```

While the full version is:

```json
{
    "ThermalPower": {
        "type": "ThermalPower",
        "instance_data": [
            {
                "id": "ThermalPower",
                "transforms": {
                    "constraints": {
                        "BalanceConstraint": true
                    },
                    "location": null,
                    "fuel_consumption": 1,
                    "emission_rate": 0,
                    "id": null,
                    "timedata": "Electricity",
                    "startup_fuel_consumption": 0
                },
                "edges": {
                    "elec_edge": {
                        "integer_decisions": false,
                        "location": null,
                        "can_retire": true,
                        "timedata": null,
                        "can_expand": true,
                        "min_down_time": 0,
                        "has_capacity": true,
                        "max_capacity": Infinity,
                        "efficiency": 1,
                        "startup_fuel_balance_id": "none",
                        "fixed_om_cost": 0,
                        "startup_fuel": 0,
                        "availability": null,
                        "existing_capacity": 0,
                        "commodity": "Electricity",
                        "min_up_time": 0,
                        "capacity_size": 1,
                        "ramp_down_fraction": 1,
                        "end_vertex": null,
                        "variable_om_cost": 0,
                        "investment_cost": 0,
                        "unidirectional": true,
                        "start_vertex": null,
                        "constraints": {
                            "CapacityConstraint": true,
                            "RampingLimitConstraint": true
                        },
                        "min_capacity": 0,
                        "loss_fraction": 0,
                        "id": null,
                        "startup_fuel_consumption": 0,
                        "ramp_up_fraction": 1,
                        "min_flow_fraction": 0,
                        "distance": 0,
                        "uc": false,
                        "startup_cost": 0
                    },
                    "fuel_edge": {
                        "integer_decisions": false,
                        "location": null,
                        "can_retire": false,
                        "timedata": null,
                        "can_expand": false,
                        "min_down_time": 0,
                        "has_capacity": false,
                        "max_capacity": Infinity,
                        "efficiency": 1,
                        "startup_fuel_balance_id": "none",
                        "fixed_om_cost": 0,
                        "startup_fuel": 0,
                        "availability": null,
                        "existing_capacity": 0,
                        "commodity": null,
                        "min_up_time": 0,
                        "capacity_size": 1,
                        "ramp_down_fraction": 1,
                        "end_vertex": null,
                        "variable_om_cost": 0,
                        "investment_cost": 0,
                        "unidirectional": true,
                        "start_vertex": null,
                        "constraints": {
                        },
                        "min_capacity": 0,
                        "loss_fraction": 0,
                        "id": null,
                        "startup_fuel_consumption": 0,
                        "ramp_up_fraction": 1,
                        "min_flow_fraction": 0,
                        "distance": 0,
                        "uc": false,
                        "startup_cost": 0
                    },
                    "co2_edge": {
                        "integer_decisions": false,
                        "location": null,
                        "can_retire": false,
                        "timedata": null,
                        "can_expand": false,
                        "min_down_time": 0,
                        "has_capacity": false,
                        "max_capacity": Infinity,
                        "efficiency": 1,
                        "startup_fuel_balance_id": "none",
                        "fixed_om_cost": 0,
                        "startup_fuel": 0,
                        "availability": null,
                        "existing_capacity": 0,
                        "commodity": "CO2",
                        "min_up_time": 0,
                        "capacity_size": 1,
                        "ramp_down_fraction": 1,
                        "end_vertex": null,
                        "co2_sink": null,
                        "variable_om_cost": 0,
                        "investment_cost": 0,
                        "unidirectional": true,
                        "start_vertex": null,
                        "constraints": {
                        },
                        "min_capacity": 0,
                        "loss_fraction": 0,
                        "id": null,
                        "startup_fuel_consumption": 0,
                        "ramp_up_fraction": 1,
                        "min_flow_fraction": 0,
                        "distance": 0,
                        "uc": false,
                        "startup_cost": 0
                    }
                }
            }
        ]
    }
}
```

### Adding a parametric Asset

Certain Assets can be parameterized by a Commodity. For example, `ThermalPower` Assets are parameterized by their fuel, e.g. `ThermalPower{NaturalGas}` or `ThermalPower{Hydrogen}`. These can be created directly using the `template_asset` function:

```julia
julia> template_asset(system, ThermalPower{NaturalGas}; style="simple", format="json")
```

This creates a file called `ThermalPower{NaturalGas}.json`, with the contents shown below. The Asset `type` is still ThermalPower, but the `fuel_commodity` is set automatically. This will ensure Macro creates a `ThermalPower{NaturalGas}.json` Asset at runtime.

```json
{
    "ThermalPower{NaturalGas}": {
        "type": "ThermalPower",
        "instance_data": [
            {
                "id": "ThermalPower{NaturalGas}",
                "location": null,
                "can_expand": true,
                "can_retire": true,
                "existing_capacity": 0,
                "capacity_size": 1,
                "timedata": "NaturalGas",
                "fuel_commodity": "NaturalGas",
                "co2_sink": null,
                "uc": false,
                "investment_cost": 0,
                "fixed_om_cost": 0,
                "variable_om_cost": 0,
                "fuel_consumption": 0,
                "electricity_consumption": 0,
                "emission_rate": 1,
                "startup_cost": 0,
                "startup_fuel_consumption": 0,
                "min_up_time": 0,
                "min_down_time": 0,
                "ramp_up_fraction": 0,
                "ramp_down_fraction": 0
            }
        ]
    }
}
```

### Adding multiple Assets

Multiple Assets can be added at once by providing an array of Asset names. The following argument will create three new Asset files:

```julia
julia> template_asset(system, [ThermalPower, VRE, ThermalPower{NaturalGas}]; style="simple", format="json")
```

#### Keyword arguments when adding multiple Assets

When adding multiple Assets at once, you should provide an array of `asset_names` if you want to specify any of them. Alternatively, allow the files to be created with the default names and then change them manually.

```julia
julia> template_asset(system, [ThermalPower, VRE, ThermalPower{NaturalGas}]; asset_names=["thermalpower_example", "vre_example", "natgas_thermalpower_example"] style="simple", format="json")
```

Only one option can be chosen for each of the `format` and `style` keywork arguments.

## Creating Instance Data for Each Asset

You have three options for how to create multiple versions of an Asset, to represent differences in cost, location, or other features:

### Create an Asset file for each version by calling

This is done be calling `template_asset` for each one. This keeps each file simple but will quickly make your asset folder hard to manage, so we do not recommend this approach.

### Create additional instances in one Asset file

This is the recommended appraoch. Each entry in the `instance_data` field corresponds to a version of the Asset. The `type` field determines the Asset which will be created. Assets described in this manner can also share `global_data`, which is [discussed in a subsequent section](@ref "Creating Global Data").

To create additional versions of an Asset in this manner, copy-paste additional entries into the `instance_data` field of your Asset file.

```json
{
    "ThermalPower": {
        "type": "ThermalPower",
        "instance_data": [
            {
                "id": "ThermalPower_1",
                ... other fields ...
            },
            {
                "id": "ThermalPower_2",
                ... other fields ...
            }
        ]
    }
}
```

### Create multiple Assets in one Asset file

You can include several Assets in one file by listing them in an array or dictionary.

To do so with an array, turn the top-level dictionary into an array and copy-paste the Asset description:

```json
{
    "ThermalPower": [
        {
            "type": "ThermalPower",
            "instance_data": [
                {
                    "id": "ThermalPower_1",
                    ... other fields ...
                }
            ]
        },
        {
            "type": "ThermalPower",
            "instance_data": [
                {
                    "id": "ThermalPower_2",
                    ... other fields ...
                }
            ]
        }
    ]
}
```

To create a copy using a dictionary, add additional entries to the top-level dictionary:

```json
{
    "ThermalPower_1": {
        "type": "ThermalPower",
        "instance_data": [
            {
                "id": "ThermalPower_1",
                ... other fields ...
            }
        ]
    },
    "ThermalPower_2": {
        "type": "ThermalPower",
        "instance_data": [
            {
                "id": "ThermalPower_2",
                ... other fields ...
            }
        ]
    }
}
```

You can also use either approach to include Assets of different types. This is especially useful if you are using a computer cluster, which typically prefer to transfer a few large files rather than multiple small ones.

```json
{
    "ThermalPower": {
        "type": "ThermalPower",
        "instance_data": [
            {
                "id": "ThermalPower",
                ... other fields ...
            }
        ]
    },
    "VRE": {
        "type": "VRE",
        "instance_data": [
            {
                "id": "VRE",
                ... other fields ...
            }
        ]
    }
}
```

The two approaches can also be blended:

```json
{
    "existing_resource": [
        {
            "type": "ThermalPower",
            "instance_data": [
                {
                    "id": "existing_natgas_1",
                ... other fields ...
                }
            ]
        },
        {
            "type": "VRE",
            "instance_data": [
                {
                    "id": "existing_vre_1",
                ... other fields ...
                }
            ]
        }
    ],
    "new_resources": [
        {
            "type": "ThermalPower",
            "instance_data": [
                {
                    "id": "new_natgas_1",
                ... other fields ...
                }
            ]
        },
        {
            "type": "VRE",
            "instance_data": [
                {
                    "id": "new_vre_1",
                ... other fields ...
                }
            ]
        }
    ]
}
```

## Assign Asset IDs

Every Asset must have a unique ID as they are how Macro identifies and manages Assets.

The `template_asset` function will search your asset folder (either based on the provided filepath or the `system_data.json` file of your `system` object) and create a unique, numbered ID based on the Asset type or user-provided Asset name.

You can change the Asset IDs of your Assets by editing the `id` field in the `instance_data` of your Asset files. 

### Listing existing Asset IDs

You can call the `asset_ids` function to list the existing Asset IDs of your system. If you have attempted to build and run your model, you can use the `source` keyword argument to have `asset_ids` check the IDs of the Assets you have already built. This is the default behaviour of `asset_ids`.

```julia
julia> asset_ids(system)
julia> asset_ids(system; source="assets")
```

If you have not built your system yet, you can specify the input files as the `source`:

```julia
julia> asset_ids(system; source="inputs")
```

Alternatively, you can use the `asset_ids_from_dir` function to target the input files directly:

```julia
julia> asset_ids_from_dir("ExampleSystems/template_example/assets")
```

## Add Instance Data

The `simple` and `full` versions of the `template_asset` functions will create Assets with Macro's default input data. This data does not represent realistic assumptions, so you must add your own data to the fields. You may delete any fields you do not want to change.

If you are using the `simple` version of an Asset file you must define a Location for each Asset, by editing the `location` field of each Assets `instance_data`.

Certain Assets have other fields which you must change for them to be correctly included in the model. Please refer to the description of the Asset in the [Asset Library](@ref "Macro Asset Library").

## Creating Global Data

In populating the `instance_data` for your Assets, you may find that multiple instances share the same data. To help reduce repetition, Macro allows you to create a `global_data` field for each Asset, which will be applied to each Asset. All fields in the `instance_data` will override the same fields in your `global_data`.

As an example, consider a case where you wish to create three `ThermalPower` Assets in three Locations.

The Assets share the same:

- Initial capacity
- Unit capacity size
- co2_sink (used to track emissions)
- Do not use integer unit commitment
- Have the same investment, fixed and variable costs

The Assets have different:

- Fuel consumption rates
- Emission rates
- Two of the Asset are fueled with natural gas, while the third is fueled with hydrogen.

To represent this, we have moved all the shared properties to the `global_data` field, leaving the fuel consumption and emission rates in the `instance_data`. We have moved the `fuel_commodity` to the `global_data` too, but override it in the third example by also including that field in its `instance_data`.

```json
{
    "ThermalPower": {
        "type": "ThermalPower",
        "global_data": {
            "can_expand": true,
                "can_retire": true,
                "existing_capacity": 0,
                "capacity_size": 100,
                "timedata": "NaturalGas",
                "fuel_commodity": "NaturalGas",
                "co2_sink": "co2_node_1",
                "uc": false,
                "investment_cost": 300000,
                "fixed_om_cost": 10000,
                "variable_om_cost": 4,
        }
        "instance_data": [
            {
                "id": "ThermalPower_1",
                "location": "Boston",
                "fuel_consumption": 2.25,
                "emission_rate": 0.18
            },
            {
                "id": "ThermalPower_2",
                "location": "Princeton",
                "fuel_consumption": 2.5,
                "emission_rate": 0.2
            },
            {
                "id": "ThermalPower_Hydrogen_1",
                "location": "New York",
                "fuel_commodity": "Hydrogen",
                "fuel_consumption": 3.0,
                "emission_rate": 0.0
            }
        ]
    }
}
```

## Working with CSV Asset files

All of the steps described above also work for CSV-based input files, with the exception of creating `global_data`. The CSV-based inputs only have `type` and `instance_data`.

It is also more challenging to include multiple Asset types in the same file, as it will require many empty columns. Therefore, we recommend using separate Asset files for each type.

For Assets of the same type, each field in the JSON file is replaced with a column. Nested JSON fields have nested CSV headers, with each name separated by a `--` character. This makes it much more prefereable to use the `simple` format for your CSV input files.

A `simple` CSV input file will look like:

```csv
Type,id,location,can_expand,can_retire,existing_capacity,capacity_size,timedata,fuel_commodity,co2_sink,uc,investment_cost,fixed_om_cost,variable_om_cost,fuel_consumption,electricity_consumption,emission_rate,startup_cost,startup_fuel_consumption,min_up_time,min_down_time,ramp_up_fraction,ramp_down_fraction
ThermalPower,ThermalPower,,true,true,0.0,1.0,NaturalGas,NaturalGas,,false,0.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0,0,0.0,0.0
```

To add more versions of the Assets, simply add more rows with their own instance data.
