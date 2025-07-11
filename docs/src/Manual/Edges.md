# Edges

## Contents

[Overview](@ref "manual-edges-overview") | [Fields](@ref "manual-edges-fields") | [Types](@ref "manual-edges-types") | [Constructors](@ref "manual-edges-constructors") | [Methods](@ref "manual-edges-methods") | [Examples](@ref "manual-edges-examples")

## [Overview](@id manual-edges-overview)

`Edges` are connections between components, allowing for one or two-way flows of Commodities. They are one of the four primary components in Macro, alongside `Nodes`, `Storage`, and `Transformations`.

Each `Edge` can only carry one Commodity so they are usually described with reference to that Commodity, e.g. as `Edge{Electricity}`, `Edge{Hydrogen}`, or `Edge{CO2}`. The general description is an `Edge{T}`, where `T` can be any Commodity or sub-Commodity.

### Edges in Assets

Most `Edges{T}` are incorporated into Assets, representing the ability of those Assets to transfer Commodities. This is intuitive in some instances but it must be remembered that `Edges` and other primary components within an Asset do not represent physical components. Instead, they represent the capabilities of the Asset as a whole.

#### Electricity Edges in a transmission line

A simple transmission line Asset has a strong correspondance between the physical component and its representation in Macro. A transmission line Asset can be defined as an `Edge{Electricity}` between two Electricity Nodes (aka. two `Node{Electricty}`). The transmission of electricity is represented by the operational variables of the `Edge{Electricity}`, and those variables are limited by its investment variables. The costs which come with those operations and investments are associated with the `Edge{Electricity}`.

#### Electricity Edges in a natural gas power plant

An `Edge{Electricity}` could also represent the ability of a natural gas power plant (aka. `ThermalPower{NaturalGas}`) to transfer `Electricity` to a grid. The `ThermalPower{NaturalGas}` will be made up of `Edges` carrying `NaturalGas` fuel, `Electricity`, and `CO2` emissions. These `Edges` will all meet at a `Transformation` which regulates the relationship between the three.

It might be intuitive to think of the `Transformation` as the power plant and the three `Edges` as the fuel lines, power lines, and flue-gas stack respectively. However, this is not correct with Macro. The combination of the three `Edges` and `Transform` represent the entire natural gas power plant. This is discussed in more detail in the [Assets documentation](@ref "Assets").

### Edges outside of Assets

It is not currently possible to define `Edges` outside of Assets using the standard input files. We believe most users will be better served using a simple Asset to represent a connection. However, it is possible to define `Edges` directly in the Julia script you use to build and solve your model. Please feel free to reach out to the developemnt team via a GitHub issue if you have a use case for this.

### Key Concepts

- **Flow Direction**: Edges can be unidirectional or bidirectional
- **Commodity Types**: Each Edge carries flows of a single Commodity type
- **Capacity**: Edges can have capacity limits which limit flows along them. Capacity can be fixed or expandable via investment.
- **Investment**: Edges can have investment costs associated with investments and operation
- **Time Dependence**: Support time-varying parameters and constraints

## [Edge Fields](@id manual-edges-fields)

`Edges` have the following fields. When running a model, the fields are set by the input files. When creating an Asset, the defaults below can can be altered using the `@edge_data` macro. The internal fields are used by Macro and are not intended to be set by users in most circumstances.

!!! note "Units in Macro"
    We have assumed that your System is using units of MWh for energy, tonnes for mass, and hour-long time steps. You can use any set of units as long as they are consistent across your operations and investment inputs.

### Network Structure

| Field            | Type           | Description                 | Default |
|------------------|----------------|-----------------------------|---------|
| `id`             | Symbol         | Unique identifier           | -       |
| `start_vertex`   | AbstractVertex | Origin vertex               | -       |
| `end_vertex`     | AbstractVertex | Destination vertex          | -       |
| `commodity`      | Type           | Commodity type              | -       |
| `unidirectional` | Bool           | Flow direction constraint   | true    |

### Investment Parameters

| Field                    | Type                      | Description                           | Units    | Default |
|--------------------------|---------------------------|---------------------------------------|----------|---------|
| `has_capacity`           | Bool                      | Whether edge has capacity limits      | -        | false   |
| `can_expand`             | Bool                      | Whether capacity can be expanded      | -        | false   |
| `can_retire`             | Bool                      | Whether capacity can be retired       | -        | false   |
| `existing_capacity`      | Float64                   | Initial installed capacity            | MWh/hr | 0.0     |
| `max_capacity`           | Float64                   | Maximum total capacity              | MWh/hr | Inf     |
| `min_capacity`           | Float64                   | Minimum total capacity              | MWh/hr | 0.0     |
| `max_new_capacity`       | Float64                   | Maximum new capacity additions        | MWh/hr | Inf     |
| `capacity_size`          | Float64                   | Unit size for capacity decisions      | MWh/hr | 1.0     |
| `integer_decisions`      | Bool                      | Whether to use integer capacity vars  | -        | false   |

### Economic Parameters

| Field                    | Type                      | Description                           | Units    | Default    |
|--------------------------|---------------------------|---------------------------------------|----------|------------|
| `investment_cost`        | Float64                   | CAPEX per unit capacity               | \$/MW     | 0.0        |
| `annualized_investment_cost` | Float64               | Annualized CAPEX                      | \$/MW/yr  | calculated |
| `fixed_om_cost`          | Float64                   | Fixed O&M costs                       | \$/MW/yr  | 0.0        |
| `variable_om_cost`       | Float64                   | Variable O&M costs                    | \$/MWh    | 0.0        |
| `wacc`                   | Float64                   | Weighted average cost of capital      | fraction | 0.0        |
| `lifetime`               | Int                       | Asset lifetime in years               | years    | 1          |
| `capital_recovery_period` | Int                      | Investment recovery period            | years    | 1          |
| `retirement_period`      | Int                       | Retirement period                     | years    | 0          |

### Unit Commitment Economic Parameters (EdgeWithUC only)

| Field                    | Type                      | Description                           | Units    | Default  |
|--------------------------|---------------------------|---------------------------------------|----------|----------|
| `startup_cost`           | Float64                   | Cost per startup                      | \$        | 0.0     |
| `startup_fuel_consumption` | Float64                 | Fuel consumed during startup          | MWh    | 0.0     |
| `min_up_time`            | Float64                   | Minimum up time                       | hours    | 0.0     |
| `min_down_time`          | Float64                   | Minimum down time                     | hours    | 0.0     |

### Operational Parameters

| Field                    | Type                      | Description                           | Units    | Default  |
|--------------------------|---------------------------|---------------------------------------|----------|----------|
| `availability`           | Vector{Float64}           | Time-varying availability factors     | fraction        | 1.0        |
| `loss_fraction`          | Vector{Float64}           | Flow losses                   | fraction | Float64[] |
| `min_flow_fraction`      | Float64                   | Minimum operating level               | fraction | 0.0      |
| `ramp_up_fraction`       | Float64                   | Maximum ramp-up rate                  | fraction/step | 1.0      |
| `ramp_down_fraction`     | Float64                   | Maximum ramp-down rate                | fraction/step | 1.0      |
| `distance`               | Float64                   | Connection distance                   | km       | 0.0      |

### Investment and Operations Tracking (Internal)

| Field                    | Type                      | Description                           | Units    | Default |
|--------------------------|---------------------------|---------------------------------------|----------|---------|
| `flow`                   | Union{JuMPVariable,Vector{Float64}} | Commodity flow through edge | MWh/hr | -        |
| `capacity`               | Union{AffExpr,Float64}    | Total available capacity              | MWh/hr | -       |
| `new_capacity`           | JuMPVariable              | New capacity investments              | MWh/hr | -       |
| `new_capacity_track`     | Dict{Int,Float64}         | Capacity additions by period          | MWh/hr | -       |
| `retired_capacity`       | JuMPVariable              | Capacity retirements                  | MWh/hr | -       |
| `retired_capacity_track` | Dict{Int,Float64}         | Retirements by period                 | MWh/hr | -       |
| `new_units`              | JuMPVariable              | New unit installations                | units    | -       |
| `retired_units`          | JuMPVariable              | Unit retirements                      | units    | -       |
| `constraints`    | Vector{AbstractTypeConstraint} | Additional constraints              | -        | []      |

### Unit Commitment Tracking (EdgeWithUC only, Internal)

| Field                    | Type                      | Description                           | Units    | Default |
|--------------------------|---------------------------|---------------------------------------|----------|---------|
| `ucommit`                | JuMPVariable              | Commitment status variables           | -        | -       |
| `ustart`                 | JuMPVariable              | Startup decision variables            | -        | -       |
| `ushut`                  | JuMPVariable              | Shutdown decision variables           | -        | -       |
| `startup_fuel_balance_id`                  | Symbol              | ID of the balance used to track start-up fuel consumption | -        | -       |

## [Types](@id manual-edges-types)

### Type Hierarchy

```julia
AbstractEdge{T}
├── Edge{T}
└── EdgeWithUC{T}
```

### AbstractEdge{T}

Abstract base type for all edges,parameterized by commodity type `T`.

### Edge{T}

Standard edge implementation, without unit commitment constraints. It is parameterized by commodity type `T`

### EdgeWithUC{T}

Edge with unit commitment constraints for modeling assets with startup/shutdown dynamics. It is parameterized by commodity type `T`

## [Constructors](@id manual-edges-constructors)

### Keyword Constructors

```julia
Edge{T}(; id::Symbol, start_vertex::AbstractVertex, end_vertex::AbstractVertex, 
        time_data::TimeData, commodity::Type{T}, [additional_fields...])

EdgeWithUC{T}(; id::Symbol, start_vertex::AbstractVertex, end_vertex::AbstractVertex, 
              time_data::TimeData, commodity::Type{T}, [additional_fields...])
```

Direct constructors using keyword arguments for all fields, where `T` is the type of commodity flowing through the edge, e.g. `Electricity`, `NaturalGas`, etc.

| Parameter   | Type                         | Description                           | Required |
|-------------|------------------------------|---------------------------------------|----------|
| `id`        | Symbol                       | Unique identifier                     | Yes      |
| `start_vertex` | AbstractVertex            | Origin vertex                         | Yes      |
| `end_vertex` | AbstractVertex              | Destination vertex                    | Yes      |
| `time_data` | TimeData                     | Time-related data structure           | Yes      |
| `commodity` | Type{T}                      | Commodity type flowing through edge   | Yes      |
| `unidirectional` | Bool                    | Flow direction constraint             | No       |
| `has_capacity` | Bool                      | Whether edge has capacity limits      | No       |
| `existing_capacity` | Float64               | Initial installed capacity            | No       |
| `max_capacity` | Float64                   | Maximum total capacity                | No       |
| `investment_cost` | Float64                 | CAPEX per unit capacity               | No       |
| `variable_om_cost` | Float64                | Variable O&M costs                    | No       |
| `...`       | Various                      | Additional edge-specific fields       | No       |

### Primary Constructors

```julia
Edge(id::Symbol, data::AbstractDict{Symbol,Any}, time_data::TimeData, 
     commodity::Type, start_vertex::AbstractVertex, end_vertex::AbstractVertex)

EdgeWithUC(id::Symbol, data::AbstractDict{Symbol,Any}, time_data::TimeData, 
           commodity::Type, start_vertex::AbstractVertex, end_vertex::AbstractVertex)
```

Creates Edge components from input data dictionary, time data, commodity type, and vertices.

| Parameter    | Type                       | Description                           |
|--------------|----------------------------|---------------------------------------|
| `id`         | Symbol                     | Unique identifier of the Edge         |
| `data`       | AbstractDict{Symbol,Any}   | Configuration data                    |
| `time_data`  | TimeData                   | Temporal data on the representative periods being modelled |
| `commodity`  | Type                       | Commodity type flowing through Edge   |
| `start_vertex` | AbstractVertex           | Origin vertex of the Edge             |
| `end_vertex` | AbstractVertex             | Destination vertex of the Edge        |

### Factory Constructors

```julia
make_edge(id::Symbol, data::AbstractDict{Symbol,Any}, time_data::TimeData, 
          commodity::Type, start_vertex::AbstractVertex, end_vertex::AbstractVertex)

make_edge_with_uc(id::Symbol, data::AbstractDict{Symbol,Any}, time_data::TimeData, 
                  commodity::Type, start_vertex::AbstractVertex, end_vertex::AbstractVertex)
```

Internal factory methods for creating Edge components with data processing and validation.

| Parameter     | Type                        | Description                              |
|---------------|-----------------------------|------------------------------------------|
| `id`          | Symbol                      | Unique identifier for the edge           |
| `data`        | AbstractDict{Symbol,Any}    | Configuration data for the edge          |
| `time_data`   | TimeData                    | Time-related data structure              |
| `commodity`   | Type                        | Commodity type for the edge              |
| `start_vertex` | AbstractVertex             | Origin vertex of the edge                |
| `end_vertex`  | AbstractVertex              | Destination vertex of the edge           |

## [Methods](@id manual-edges-methods)

### Accessor Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `id(edge)` | Get edge ID | Symbol |
| `flow(edge)` | Get flow variable/values | Union{JuMPVariable,Vector{Float64}} |
| `flow(edge, t)` | Get flow at timestep t | Float64 |
| `capacity(edge)` | Get total capacity | Union{AffExpr,Float64} |
| `existing_capacity(edge)` | Get existing capacity | Float64 |
| `new_capacity(edge)` | Get new capacity variable | JuMPVariable |
| `availability(edge)` | Get availability profile | Vector{Float64} |
| `availability(edge, t)` | Get availability at timestep t | Float64 |
| `loss_fraction(edge)` | Get loss profile | Vector{Float64} |
| `loss_fraction(edge, t)` | Get loss at timestep t | Float64 |
| `commodity_type(edge)` | Get commodity type | Type |
| `start_vertex(edge)` | Get origin vertex | AbstractVertex |
| `end_vertex(edge)` | Get destination vertex | AbstractVertex |

### Capacity and Investment

| Function | Description | Returns |
|----------|-------------|---------|
| `can_expand(edge)` | Check if expandable | Bool |
| `can_retire(edge)` | Check if retirable | Bool |
| `has_capacity(edge)` | Check if capacity-constrained | Bool |
| `max_capacity(edge)` | Get maximum capacity | Float64 |
| `min_capacity(edge)` | Get minimum capacity | Float64 |
| `investment_cost(edge)` | Get investment cost | Float64 |
| `annualized_investment_cost(edge)` | Get annualized cost | Float64 |

### Unit Commitment Methods (EdgeWithUC only)

| Function | Description | Returns |
|----------|-------------|---------|
| `min_up_time(edge)` | Get minimum up time | Float64 |
| `min_down_time(edge)` | Get minimum down time | Float64 |
| `startup_cost(edge)` | Get startup cost | Float64 |
| `startup_fuel_consumption(edge)` | Get startup fuel consumption | Float64 |

### Asset Creation

| Function | Description | Returns |
|----------|-------------|---------|
| `@edge_data(new_defaults)` | Macro to set new default fields for an Asset | Dict{Symbol,Any} |

### Model Creation

| Function | Description | Returns |
|----------|-------------|---------|
| `operation_model!(edge, model)` | Create operational variables and constraints for the `Edge` and add to model | Nothing |
| `planning_model!(edge, model)` | Create investment variables and constraints for the `Edge` and add to model | Nothing |
| `compute_investment_costs!(edge, model)` | Calculate annualized, discounted investment costs | Nothing |
| `compute_om_fixed_costs!(edge, model)` | Calculate discounted fixed OM costs | Nothing |
| `compute_fixed_costs!(edge, model)` | Calculate annualized, discounted fixed costs | Nothing |
| `add_linking_variables!(edge, model)` | Add linking variables between the planning and operational models | Nothing |
| `define_available_capacity!(edge, model)` | Calculate and fix available capacity | Nothing |

### Constraint Management

| Function | Description | Returns |
|----------|-------------|---------|
| `all_constraints(edge)` | Get all constraints | Vector{AbstractTypeConstraint} |
| `all_constraints_types(edge)` | Get constraint types | Vector{Type} |
| `get_constraint_by_type(edge, type)` | Get specific constraint type | Union{AbstractTypeConstraint,Nothing} |

### Utility Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `edges_with_capacity_variables(edges)` | Filter edges with capacity variables | Vector{AbstractEdge} |
| `target_is_valid(edge, target)` | Validate edge-vertex compatibility | Bool |
| `edge_default_data()` | Get default edge data values | Dict{Symbol,Any} |

## [Examples](@id manual-edges-examples)

### Transmission Line

Transmission lines can be represented as `TransmissionLink{Electricity}` Assets. These are made up of an `Edge{Electricity}` between two `Node{Electricity}` vertices.

#### Transmission Line Inputs

Assets can be defined using the standard or advanced JSON input formats, or a blend of the two. The standard format is simpler and more concise, while the advanced format allows for more flexibility and additional fields.

Macro also supports CSV inputs. These will usually use the standard input format. Please refer to the [CSV Input documentation](@ref "CSV Inputs") for more details on how to use CSV files.

##### Standard JSON Input Format

Using the simplified, standard JSON input format, a transmission line can be defined as shown below.

```json
{
    "type": "TransmissionLink",
    "instance_data": {
        "id": "TransmissionLine_SE_MIDAT",
        "commodity": "Electricity",
        "location": "elec_SE",
        "transmission_destination": "elec_MIDAT",
        "unidirectional": false,
        "distance": 491.4512001,
        "existing_capacity": 5552,
        "max_capacity": 27760,
        "investment_cost": 40219,
        "loss_fraction": 0.04914512,
        "constraints": {
            "MaxCapacityConstraint": true
        }
    }
}
```

##### Advanced JSON Input Format

A transmission line can also be defined using the full, advanced JSON input format. This more closely mirrors the fields of the Assets components. Note that some fields are set to their default values, such as `can_expand`, `can_retire`, and `integer_decisions`. These could be omitted but are often included to make the inputs more explicit or facilitate future changes.

The `commodity` input is not a field of the `Edge{Electricity}`. Here, it is one of the additional inputs required by the `TransmissionLink` Asset. It is used to decide the commodity type of the `Edge` and Asset, in this instance `Electricity`.

Additional inputs like this are set when defining an `Asset` and its `make()` function. They will not be made fields of the Asset's components, but will be used when creating the Asset. Other common examples are the `location` input, which is used to connect an Asset to multiple `Nodes` with the same `location` field, and the `uc` input which is used to specify whether an Asset should use a regular `Edge` or an `EdgeWithUC`.

```json
{
    "type": "TransmissionLink",
    "instance_data": {
        "id": "TransmissionLine_SE_MIDAT",
        "edges": {
            "transmission_edge": {
                "commodity": "Electricity",
                "start_vertex": "elec_SE",
                "end_vertex": "elec_MIDAT",
                "unidirectional": false,
                "has_capacity": true,
                "can_expand": true,
                "can_retire": false,
                "integer_decisions": false,
                "distance": 491.4512001,
                "existing_capacity": 5552,
                "max_capacity": 27760,
                "investment_cost": 40219,
                "loss_fraction": 0.04914512,
                "constraints": {
                    "CapacityConstraint": true,
                    "MaxCapacityConstraint": true
                }
            }
        }
    }
}
```

#### Creating the Transmission Line Asset

A full guide on how to create Assets can be found in the [Creating a New Asset](@ref) section. Further discussion of Assets and the `@edge_data` macro can be found in the [Assets documentation](@ref "Assets").

First, we add an `Edge` to the `TransmissionLink` Asset struct. `TransmissionLinks` are generalized connections meant to represent transmission lines, pipelines without linepack, data connections, etc. Therefore, we parameterized the Asset by the commodity its `Edge` carries, e.g. `TransmissionLink{Electricity}` or `TransmissionLink{NaturalGas}`.

```julia
struct TransmissionLink{T} <: AbstractAsset
    id::AssetId
    transmission_edge::Edge{<:T}
end
```

The next step is to define how the `TransmissionLink` Asset inputs should be parsed into the data required to create the `Edge{Electricity}`. This is done as part of the `TransmissionLink` Assets `make()` function.

We will break down the steps of the `make()` function but the entire function is shown below to put the code snippet in context:

```julia
function make(asset_type::Type{<:TransmissionLink}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id]) 

    @setup_data(asset_type, data, id)

    transmission_edge_key = :transmission_edge
    @process_data(
        transmission_edge_data,
        data[:edges][transmission_edge_key],
        [
            (data[:edges][transmission_edge_key], key),
            (data[:edges][transmission_edge_key], Symbol("transmission_", key)),
            (data, Symbol("transmission_", key)),
            (data, key), 
        ]
    )

    commodity_symbol = Symbol(transmission_edge_data[:commodity])
    commodity = commodity_types()[commodity_symbol]
    
    @start_vertex(
        t_start_node,
        transmission_edge_data,
        commodity,
        [(transmission_edge_data, :start_vertex), (data, :transmission_origin), (data, :location)],
    )
    @end_vertex(
        t_end_node,
        transmission_edge_data,
        commodity,
        [(transmission_edge_data, :end_vertex), (data, :transmission_dest), (data, :location)],
    )

    transmission_edge = Edge(
        Symbol(id, "_", transmission_edge_key),
        transmission_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        t_start_node,
        t_end_node,
    )
    return TransmissionLink(id, transmission_edge)
end
```

##### Assign the Asset ID and setup the defaults

```julia
id = AssetId(data[:id])
@setup_data(asset_type, data, id)
```

The first step is to assign the Asset an ID, using on the `id` field in the input data. The `AssetId` type is currently just an alias for a `Symbol` but may be extended in the future to include additional metadata about the Asset.

The `@setup_data` macro is used to configure the default values for the Asset, based on the generic defaults of each component and the specific defaults for the Asset. The latter are set using the `default_data()` functions, which is described in the [Assets documentation](@ref "Assets").

##### Process the Edge data

```julia
transmission_edge_key = :transmission_edge
@process_data(
    transmission_edge_data,
    data[:edges][transmission_edge_key],
    [
        (data[:edges][transmission_edge_key], key),
        (data[:edges][transmission_edge_key], Symbol("transmission_", key)),
        (data, Symbol("transmission_", key)),
        (data, key), 
    ]
)
```

The next step is to parse the input data for the `Edge` into the format required by the `Edge` constructor. This could be done with a simple dictionary lookup between the input data and the `Edge` fields. However, that would limit the input data to being formatted in a very specific way.

To allow for more flexibility, and simpler input files, we can use the `@process_data` macro to extract the relevant data from multiple possible locations in the input dictionary. This gives the user many options for how to structure their input files, at the cost of making the Asset modellers job a bit more complex.

The core idea of the `@process_data` macro is that it gives Macro a list of locations to look for each piece of data. This is explained in more detail in the [Assets documentation](@ref "Assets"). However, the intuition is that the macro will loop through the `Edges` fields, searching for each field in the options listed in the third argument to the macro.

For example, when searching for the `has_capacity` field, it will look in:

- `data[:edges][transmission_edge_key][:has_capacity]` first. If it is not found, it will look in:
- `data[:edges][transmission_edge_key][:transmission_has_capacity]`, then:
- `data[:transmission_has_capacity]`, and finally:
- `data[:has_capacity]`.

You will note that the search progresses from the most nested / specific location to the least. This makes it easier to mix global and instance input data for Assets.

Ultimately, the `@process_data` macro will extract the relevant data from the input dictionary and store it in the `transmission_edge_data` variable. This variable will then be used to create the `Edge{Electricity}`.

##### Set the commodity type

```julia
commodity_symbol = Symbol(transmission_edge_data[:commodity])
commodity = commodity_types()[commodity_symbol]
```

`TransmissionLink` Assets require a `commodity` field in their inputs. This will be a `String`, which we first convert into a `Symbol` and then look up in the list of available commodity types. This list is accessed using the `commodity_types()` function, which returns a dictionary mapping commodity symbols to their types.

##### Define the start and end vertices

```julia
@start_vertex(
    t_start_node,
    transmission_edge_data,
    commodity,
    [(transmission_edge_data, :start_vertex), (data, :transmission_origin), (data, :location)],
)
@end_vertex(
    t_end_node,
    transmission_edge_data,
    commodity,
    [(transmission_edge_data, :end_vertex), (data, :transmission_dest), (data, :location)],
)
```

The next step is to find the start and end vertices of the `Edge{Electricity}`. In our example these are the `Node{Electricity}`. However, they can be other `Vertices`.

The `@start_vertex` and `@end_vertex` macros are similar to the `@process_data` macro in that they allow for flexibility in how the input data is structured. They will search for the `ids` given in the `start_vertex` and `end_vertex` fields of the input data. They will first look in the most specific location before moving to the more general locations.

If the two Vertices are found, they will be assigned to the `t_start_node` and `t_end_node` variables.

##### Create the Electricity Edge and TransmissionLink Asset

```julia
transmission_edge = Edge(
    Symbol(id, "_", transmission_edge_key),
    transmission_edge_data,
    system.time_data[commodity_symbol],
    commodity,
    t_start_node,
    t_end_node,
)
return TransmissionLink(id, transmission_edge)
```

The final step is to create the `Edge{Electricity}` using the `Edge` constructor. This requires:

- A new ID, derived from the Assets unique ID.
- The `transmission_edge_data` dictionary, which contains the data for the `Edge`.
- The temporal data for the `Edge` based on its Commodity. This data is found in the System-wide `time_data` dictionary.
- The Commodity type, which was looked up earlier.
- The start and end vertices, which were found using the `@start_vertex` and `@end_vertex` macros.

The `make()` function then returns a new `TransmissionLink` Asset, which contains the `Edge{Electricity}` as one of its components.

##### Define TransmissionLink Asset Defaults

Modellers can define Asset-specific default values for the `TransmissionLink` Asset using the `full_default_data()` and `simple_default_data()` functions. These allow Users to provide much shorter and simpler input files than are otherwise required. The two functions are described in the [Assets documentation](@ref "Assets").

### Solar PV Power Plant

#### Solar PV, Standard JSON Input Format

```json
{
    "type": "VRE",
    "global_data": {},
    "instance_data": {
        "id": "example_solar_pv",
        "location": "boston",
        "fixed_om_cost": 13510.19684,
        "investment_cost": 41245.37889,
        "max_capacity": 989513,
        "availability": {
            "timeseries": {
                "path": "system/availability.csv",
                "header": "boston_solar_pv",
            }
        },
        "elec_can_expand": true,
        "elec_can_retire": false,
        "elec_constraints": {
            "MaxCapacityConstraint": true
        }
    }
}
```

#### Solar PV, Advanced JSON Input Format

```json
{
    "type": "VRE",
    "global_data": {},
    "instance_data": {
        "id": "example_solar_pv",
        "transforms": {
            "timedata": "Electricity"
        },
        "edges": {
            "edge": {
                "commodity": "Electricity",
                "unidirectional": true,
                "can_expand": true,
                "can_retire": false,
                "has_capacity": true,
                "constraints": {
                    "CapacityConstraint": true,
                    "MaxCapacityConstraint": true
                },
                "fixed_om_cost": 13510.19684,
                "investment_cost": 41245.37889,
                "max_capacity": 989513,
                "end_vertex": "boston_elec",
                "availability": {
                    "timeseries": {
                        "path": "system/availability.csv",
                        "header": "boston_solar_pv",
                    }
                },
            }
        }
    }
}
```

### Natural Gas Power Plant

#### Nat Gas, Standard JSON Input Format

```json
{
    "type": "ThermalPower",
    "global_data": {},
    "instance_data": {
        "id": "example_natural_gas_power_plant",
        "location": "boston",
        "timedata": "NaturalGas",
        "fuel_commodity": "NaturalGas",
        "co2_sink": "co2_sink",
        "uc": true,
        "elec_constraints": {
            "CapacityConstraint": true,
            "RampingLimitConstraint": true,
            "MinFlowConstraint": true,
            "MinUpTimeConstraint": true,
            "MinDownTimeConstraint": true,
        },
        "emission_rate": 0.181048235160161,
        "fuel_consumption": 2.249613533,
        "can_expand": false,
        "existing_capacity": 4026.4,
        "investment_cost": 0.0,
        "fixed_om_cost": 16001,
        "variable_om_cost": 4.415,
        "capacity_size": 125.825,
        "startup_cost": 89.34,
        "startup_fuel_consumption": 0.58614214,
        "min_up_time": 6,
        "min_down_time": 6,
        "ramp_up_fraction": 0.64,
        "ramp_down_fraction": 0.64,
        "min_flow_fraction": 0.444
    }
}
```

#### Nat Gas, Advanced JSON Input Format

```json
{
    "type": "ThermalPower",
    "global_data": {},
    "instance_data": {
        "id": "example_natural_gas_power_plant",
        "transforms": {
            "emission_rate": 0.181048235160161,
            "fuel_consumption": 2.249613533
        },
        "edges": {
            "elec_edge": {
                "commodity": "Electricity",
                "unidirectional": true,
                "has_capacity": true,
                "uc": true,
                "integer_decisions": false,
                "constraints": {
                    "CapacityConstraint": true,
                    "RampingLimitConstraint": true,
                    "MinFlowConstraint": true,
                    "MinUpTimeConstraint": true,
                    "MinDownTimeConstraint": true
                },
               "end_vertex": "boston_elec",
                "can_retire": true,
                "can_expand": false,
                "existing_capacity": 4026.4,
                "investment_cost": 0.0,
                "fixed_om_cost": 16001,
                "variable_om_cost": 4.415,
                "capacity_size": 125.825,
                "startup_cost": 89.34,
                "startup_fuel_consumption": 0.58614214,
                "min_up_time": 6,
                "min_down_time": 6,
                "ramp_up_fraction": 0.64,
                "ramp_down_fraction": 0.64,
                "min_flow_fraction": 0.444
            },
            "fuel_edge": {
                "commodity": "NaturalGas",
                "unidirectional": true,
                "has_capacity": false,
                "start_vertex": "boston_natgas"
            },
            "co2_edge": {
                "commodity": "CO2",
                "unidirectional": true,
                "has_capacity": false,
                "end_vertex": "co2_sink"
            }
        }
    }
}
```

## See Also

- [Nodes](@ref) - Network nodes that edges connect to
- [Transformations](@ref) - Processes that transform flows between edges
- [Storage](@ref) - Energy storage components that can be connected to edges
- [Vertices](@ref) - Network nodes that edges connect
- [Assets](@ref "Assets") - Higher-level components made from edges, nodes,
- [Commodities](@ref) - Types of resources flowing through edges  
- [Time Data](@ref) - Temporal modeling framework
- [Constraints](@ref) - Additional constraints for edges
