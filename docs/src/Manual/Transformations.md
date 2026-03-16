# Transformations

## Contents

[Overview](@ref "manual-transformations-overview") | [Fields](@ref manual-transformation-fields) | [Types](@ref "manual-transformations-types") | [Constructors](@ref "manual-transformations-constructors") | [Methods](@ref "manual-transformations-methods") | [Examples](@ref "manual-transformations-examples")

## [Overview](@id manual-transformations-overview)

`Transformations` balance flows of several Commodities, handling the conversion of one or more Commodities into one or more others. They are one of the four primary components in Macro, alongside `Nodes`, `Edges`, and `Storage`. They are sub-types of the `Vertex` type.

Unlike `Nodes`, which balance flows of a single Commodity, `Transformations` manage multi-commodity conversion processes. They rely on user-defined stoichiometric balances to govern these multi-flow relationships. They are essential for modeling energy conversion technologies, chemical processes, and other systems that transform one form of energy or material into another.

### Transformations in Assets

`Transformation` components are typically incorporated into Assets, representing the ability of those Assets to convert between different Commodities. This could be used to model:

- **Power Plants**: Converting fuel (natural gas, coal, uranium) into electricity and emissions
- **Chemical Plants**: Converting raw materials and fuel into chemical products
- **Gas Pipelines**: Electricty is required to run compressors and pumps, facilitating the flow of gases. This can be modeled as a `Transformation` that converts `Electricity` and `NaturalGas` into a second flow of `NaturalGas`.

#### Natural Gas Power Plant Asset

A natural gas power plant Asset can be modeled using a `Transformation` component that converts `NaturalGas` into `Electricity`, `CO2`. Other formulations may account for oxidizer and waste heat. The `Transformation` component uses stoichiometric balances to define the conversion ratios, such as the heat rate (fuel consumption per unit electricity) and emission factor (CO2 per unit fuel). The `Edges` connected to the `Transformation` handle the actual flows, including flow / capacity limits, while the `Transformation` enforces the conversion relationships.

#### Multi-Product Refineries

Complex industrial processes like refineries can use multiple `Transformation` components to model different conversion units. Each `Transformation` handles a specific conversion process (e.g., distillation, cracking, reforming) with its own stoichiometric relationships, allowing for detailed modeling of multi-product facilities.

### Transformations Outside of Assets

`Transformation` components can be used outside of Assets, but there is no standard input file format to do so currently. Most Users will be better served by using `Transformation` components within Assets, as this allows for more complex interactions and standardized input formats. However, it is possible to define `Transformations` directly in the Julia script you use to build and solve your model. Please feel free to reach out to the development team via a GitHub issue if you have a use case for this.

### Key Concepts

- **Multi-Commodity Conversion**: Transformations handle conversion between flows of several Commodity using multi-commodity balance constraints
- **Stoichiometric Balances**: User-defined relationships govern the conversion ratios between input and output flows
- **Asset Integration**: Transformations are typically used within Assets to model conversion technologies

## [Transformation Fields](@id manual-transformation-fields)

`Transformations` have the following fields. When running a model, the fields are set by the input files. When creating an Asset, the defaults below can be altered using the `@transform_data` macro. The internal fields are used by Macro and are not intended to be set by users in most circumstances.

Moreso than other components, `Transformations` rely heavily on additional inputs defined as part of the Asset they are a part of. These additional inputs are used to define the stoichiometric balances of the `Transformation`. These are not shown in the following tables as they are not part of the `Transformation` itself, but rather part of the Asset that contains the `Transformation`.

!!! note "Units in Macro"
    We have assumed that your System is using units of MWh for energy, tonnes for mass, and hour-long time steps. You can use any set of units as long as they are consistent across your operations and investment inputs.

### Network Structure

| Field            | Type           | Description                 | Default |
|------------------|----------------|-----------------------------|---------|
| `id`             | Symbol         | Unique identifier           | -       |
| `location`       | Union{Missing,Symbol} | Location where transformation is placed | missing |

### Stoichiometric Balance Data (Internal)

| Field                    | Type                      | Description                           | Units    | Default |
|--------------------------|---------------------------|---------------------------------------|----------|---------|
| `balance_data`           | Dict{Symbol,Dict{Symbol,Float64}} | Stoichiometric equation coefficients | varies | Dict{Symbol,Dict{Symbol,Float64}}() |
| `constraints`            | Vector{AbstractTypeConstraint} | Additional constraints        | -        | Vector{AbstractTypeConstraint}() |
| `operation_expr`         | Dict                      | Operational JuMP expressions          | -        | Dict() |

### Time-Related Data (Internal)

| Field                    | Type                      | Description                           | Units    | Default |
|--------------------------|---------------------------|---------------------------------------|----------|---------|
| `timedata`               | TimeData                  | Time-related modeling data            | -        | -       |

## [Types](@id manual-transformations-types)

### Type Hierarchy

`Transformation` types follow a hierarchical structure rooted in the abstract `AbstractVertex` type:

```julia
AbstractVertex
├── Node{T}
├── AbstractStorage{T}
│   ├── Storage{T}
│   └── LongDurationStorage{T}
└── Transformation
```

### Transformation

The Transformation type represents conversion processes between different commodities. Unlike other vertex types that are parameterized by commodity type, Transformations handle multiple commodities simultaneously through stoichiometric balance equations.

## [Constructors](@id manual-transformations-constructors)

### Keyword Constructors

```julia
Transformation(; id::Symbol, timedata::TimeData, [additional_fields...])
```

Direct constructors using keyword arguments for all fields.

| Parameter   | Type                         | Description                           | Required |
|-------------|------------------------------|---------------------------------------|----------|
| `id`        | Symbol                       | Unique identifier                     | Yes      |
| `timedata`  | TimeData                     | Time-related data structure           | Yes      |
| `location`  | Union{Missing,Symbol}        | Location where transformation is placed | No     |
| `balance_data` | Dict{Symbol,Dict{Symbol,Float64}} | Stoichiometric equation coefficients | No |
| `constraints` | Vector{AbstractTypeConstraint} | Additional constraints             | No       |
| `operation_expr` | Dict                      | Operational JuMP expressions          | No       |

### Primary Constructors

```julia
Transformation(id::Symbol, data::Dict{Symbol,Any}, time_data::TimeData)
```

Creates Transformation components from input data dictionary and time data.

| Parameter    | Type                       | Description                              |
|--------------|----------------------------|------------------------------------------|
| `id`         | Symbol                     | Unique identifier for the transformation |
| `data`       | Dict{Symbol,Any}           | Dictionary of transformation configuration data |
| `time_data`  | TimeData                   | Time-related data structure              |

### Factory Constructors

```julia
make_transformation(id::Symbol, data::Dict{Symbol,Any}, time_data::TimeData)
```

Internal factory methods for creating Transformation components with data processing.

| Parameter     | Type                        | Description                              |
|---------------|-----------------------------|------------------------------------------|
| `id`          | Symbol                      | Unique identifier for the transformation |
| `data`        | Dict{Symbol,Any}            | Configuration data for the transformation |
| `time_data`   | TimeData                    | Time-related data structure              |

## [Methods](@id manual-transformations-methods)

### Accessor Methods

Methods for accessing transformation data and properties.

| Method | Description | Return Type |
|--------|-------------|-------------|
| `id(transformation)` | Get transformation identifier | `Symbol` |
| `balance_ids(transformation)` | Get IDs of all balance equations | `Vector{Symbol}` |
| `balance_data(transformation, i)` | Get input data for balance equation i | `Dict{Symbol,Float64}` |
| `get_balance(transformation, i)` | Get balance equation expression for i | `JuMP.Expression` |
| `get_balance(transformation, i, t)` | Get balance equation expression for i at time t | `JuMP.Expression` |

### Balance and Constraint Methods (Inherited from AbstractVertex)

Methods for managing balance equations and constraints.

| Method | Description | Return Type |
|--------|-------------|-------------|
| `all_constraints(transformation)` | Get all constraints applied to the transformation | `Vector{AbstractTypeConstraint}` |
| `all_constraints_types(transformation)` | Get types of all constraints | `Vector{DataType}` |
| `get_constraint_by_type(transformation, constraint_type)` | Get constraint of specified type | `Union{AbstractTypeConstraint,Vector{AbstractTypeConstraint},Nothing}` |

### Model Building Methods

Methods used internally during model construction.

| Method | Description | Return Type |
|--------|-------------|-------------|
| `add_linking_variables!(transformation, model)` | Add linking variables to JuMP model | `Nothing` |
| `define_available_capacity!(transformation, model)` | Define available capacity constraints | `Nothing` |
| `planning_model!(transformation, model)` | Add planning model constraints | `Nothing` |
| `operation_model!(transformation, model)` | Add operational model constraints | `Nothing` |

### Factory Methods

Methods for creating transformation components.

| Method | Description | Return Type |
|--------|-------------|-------------|
| `make_transformation(id, data, time_data)` | Create transformation component | `Transformation` |

### Utility Methods

Additional utility methods for working with Transformations.

| Method | Description | Return Type |
|--------|-------------|-------------|
| `@transform_data(new_defaults)` | Macro to set new default fields for an Asset | `Dict{Symbol,Any}` |

## [Examples](@id manual-transformations-examples)

### Natural Gas Power Plant Asset

The `ThermalPower` Asset is an example of how to use `Transformation` components to model a natural gas power plant. It converts `NaturalGas` into `Electricity` and `CO2`.

The stochiometric balances of the `Transformation` are defined by the `fuel_consumption` and `emission_rate` fields, which represent the heat rate (fuel consumption per unit electricity) and emission factor (CO2 per unit fuel), respectively.

The following code snippets show how the `Transformation` is defined as part of the `ThermalPower` Asset and how the stochiometric balances are set. Further information about how to create new Assets can be found in the [Assets manual page](@ref "Assets").

The `Transformation` is one of the components which make up the `ThermalPower` Asset.

```julia
struct ThermalPower{T} <: AbstractAsset
    id::AssetId
    thermal_transform::Transformation
    elec_edge::Union{Edge{<:Electricity},EdgeWithUC{<:Electricity}}
    fuel_edge::Edge{<:T}
    co2_edge::Edge{<:CO2}
end
```

The `make()` function of the `ThermalPower` Asset is responsible for creating the `Transformation` and connecting it to the appropriate `Nodes` via `Edges`. The `make()` function processes the input data and sets up the `Transformation` with the necessary stoichiometric balances.

```julia
function make(asset_type::Type{ThermalPower}, data::AbstractDict{Symbol,Any}, system::System)
    # Assign a unique ID and set up the default data
    id = AssetId(data[:id])
    @setup_data(asset_type, data, id)

    # Parse the Transformation data and create the Transformation component
    thermal_key = :transforms
    @process_data(
        transform_data, 
        data[thermal_key], 
        [
            (data[thermal_key], key),
            (data[thermal_key], Symbol("transform_", key)),
            (data, Symbol("transform_", key)),
            (data, key),
        ]
    )
    thermal_transform = Transformation(;
        id = Symbol(id, "_", thermal_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        constraints = get(transform_data, :constraints, [BalanceConstraint()]),
    )

    elec_edge_key = :elec_edge
    # ... Process the electricity edge data
    elec_start_node = thermal_transform
    @end_vertex(
        elec_end_node,
        elec_edge_data,
        Electricity,
        [(elec_edge_data, :end_vertex), (data, :location)],
    )
    # Check if the edge has unit commitment constraints
    has_uc = get(elec_edge_data, :uc, false)
    EdgeType = has_uc ? EdgeWithUC : Edge
    # Create the elec edge with the appropriate type
    elec_edge = EdgeType(
        Symbol(id, "_", elec_edge_key),
        elec_edge_data,
        system.time_data[:Electricity],
        Electricity,
        elec_start_node,
        elec_end_node,
    )
    if has_uc
        uc_constraints = [MinUpTimeConstraint(), MinDownTimeConstraint()]
        for c in uc_constraints
            if !(c in elec_edge.constraints)
                push!(elec_edge.constraints, c)
            end
        end
        elec_edge.startup_fuel_balance_id = :energy
    end
    
    fuel_edge_key = :fuel_edge
    # ... Process the fuel edge data
    fuel_end_node = thermal_transform
    fuel_edge = Edge(
        Symbol(id, "_", fuel_edge_key),
        fuel_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        fuel_start_node,
        fuel_end_node,
    )

    co2_edge_key = :co2_edge
    # ... Process the CO2 edge data
    co2_edge = Edge(
        Symbol(id, "_", co2_edge_key),
        co2_edge_data,
        system.time_data[:CO2],
        CO2,
        co2_start_node,
        co2_end_node,
    )

    # Set the Transformation's stochiometric balance constraints. 
    
    # The first constraint sets the fuel -> electricity conversion ratio, which is the heat rate of the power plant.

    # The second constraint sets the fuel -> CO2 conversion ratio, which is the emission factor of the power plant.
    thermal_transform.balance_data = Dict(
        :energy => Dict(
            elec_edge.id => get(transform_data, :fuel_consumption, 1.0),
            fuel_edge.id => 1.0,
            co2_edge.id => 0.0,
        ),
        :emissions => Dict(
            fuel_edge.id => get(transform_data, :emission_rate, 0.0),
            co2_edge.id => 1.0,
            elec_edge.id => 0.0,
        ),
    )

    # Finally, we create and return the ThermalPower Asset
    return ThermalPower(id, thermal_transform, elec_edge, fuel_edge, co2_edge)
end
```

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

### Gas Storage Asset

`GasStorage` Assets are an interesting example of how `Transformations` can be used to model `Electricity` flows used to energize another flow, instead of converting between Commodities. The [Edges manual page](@ref "Hydrogen Storage") includes an explanation of the `make()` function and inputs of this Asset.

## See Also

- [Edges](@ref) - Components that connect Vertices and carry flows
- [Nodes](@ref) - Network nodes that allow for import and export of commodities
- [Storage](@ref) - Components that store commodities for later use
- [Vertices](@ref) - Network nodes that edges connect
- [Assets](@ref "Assets") - Higher-level components made from edges, nodes, storage, and transformations
- [Commodities](@ref) - Types of resources stored by Commodities
- [Time Data](@ref) - Temporal modeling framework
- [Constraints](@ref) - Additional constraints for Storage and other components
