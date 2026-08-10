# Locations

## Contents

[Overview](@ref "manual-locations-overview") | [Fields](@ref "Location Fields") | [Types](@ref "manual-locations-types") | [Constructors](@ref "manual-locations-constructors") | [Methods](@ref "manual-locations-methods") | [Examples](@ref "manual-locations-examples")

## [Overview](@id manual-locations-overview)

`Locations` are compound components in Macro that represent geographic or conceptual places in an energy system. They serve as containers for collections of `Nodes`, where each `Node` has a different `Commodity` or sub-`Commodity` type. Locations are one of the core organizational concepts in Macro, alongside `Assets`.

The primary purpose of Locations is to simplify the construction and management of complex energy system models. Rather than requiring users to manually connect individual `Edges` of `Assets` to specific `Nodes` for each commodity type, the `Asset` as a whole can be connected to a `Location` and Macro will automatically handle the routing and connection of the appropriate `Edges` and `Nodes` within that Location. This abstraction makes model building more intuitive and less error-prone.

### Location Structure and Node Management

Each Location maintains a collection of `Nodes` organized by commodity type, with each `Node` handling flows of a specific `Commodity`. The Location uses a `Set` to track the commodity types of all `Nodes` it contains, ensuring that only one `Node` per commodity type exists within any given Location. This constraint maintains clarity about which `Node` handles each commodity type and how `Edges` should be routed.

When a user attempts to add a `Node` to a Location that already contains a `Node` of the same commodity type, the system will throw an error unless explicitly instructed to replace the existing `Node`. This safeguard helps maintain model consistency and prevents accidental overwrites of important network components. Macro can also be configured to automatically create new `Nodes` for commodity types that do not already exist in the Location, streamlining the process of adding new components to the model.

### Simplified Model Construction

The Location abstraction makes building energy systems much more intuitive because it mirrors how people naturally think about energy infrastructure. Physical equipment like power plants, storage facilities, and transmission lines are typically associated with specific geographic locations. By organizing the model around Locations, users can construct systems that directly correspond to real-world geography and infrastructure layout.

When Assets are connected to Locations rather than individual Nodes, Macro automatically determines the appropriate connections based on the commodity types involved in the Asset's operation. For example, a natural gas power plant Asset connected to a Location will automatically have its gas input connected to the Location's natural gas `Node` and its electricity output connected to the Location's electricity `Node`. This automatic routing eliminates much of the manual wiring that would otherwise be required.

### Physical and Logical Modeling

Locations can represent both physical geographic areas (such as cities, regions, or specific sites) and logical groupings (such as market zones or administrative areas). This flexibility allows users to organize their models at the appropriate level of detail for their analysis needs. A national energy system model might use Locations to represent states or provinces, while a local energy system model might use Locations to represent individual buildings or districts.

The Location concept also supports hierarchical thinking about energy systems, where larger geographic areas contain multiple smaller areas, each with their own local energy infrastructure and commodity flows. While Macro doesn't enforce hierarchical relationships between Locations, users can organize their models to reflect these real-world structures.

### Key Concepts

- **Node Collection**: Locations contain multiple `Nodes`, each handling a specific commodity type at that location
- **Automatic Routing**: Assets connected to Locations automatically route to appropriate `Nodes` based on commodity types
- **Commodity Uniqueness**: Each Location enforces one `Node` per commodity or sub-commodity type using a tracking `Set`
- **Simplified Modeling**: Locations make model construction intuitive by mirroring real-world geographic organization
- **Flexible Abstraction**: Can represent physical locations or logical groupings depending on modeling needs
- **Error Prevention**: Automatic checking prevents duplicate commodity `Nodes` within the same Location

## Location Fields

`Locations` have the following fields. When running a model, the fields are set by the input files or programmatically when building the system.

!!! note "Units in Macro"
    We have assumed that your System is using units of MWh for energy, tonnes for mass, and hour-long time steps. You can use any set of units as long as they are consistent across your operations and investment inputs.

### Identification and System Reference

| Field     | Type             | Description                                      | Default |
|-----------|------------------|--------------------------------------------------|---------|
| `id`      | Symbol           | Unique identifier for the location              | -       |
| `system`  | AbstractSystem   | Reference to the system containing this location | -       |

### Node Management

| Field          | Type                    | Description                                       | Default               |
|----------------|-------------------------|---------------------------------------------------|-----------------------|
| `nodes`        | Dict{Symbol,Node}       | Dictionary mapping commodity symbols to nodes     | Dict{Symbol,Node}()   |
| `commodities`  | Set{Symbol}             | Set of commodity symbols for nodes in this location | Set{Symbol}()       |

## [Types](@id manual-locations-types)

### Type Hierarchy

`Location` is a subtype ofthe abstract `MacroObject` type:

```julia
MacroObject
├── Location
├── AbstractAsset
├── AbstractVertex
└── AbstractEdge
```

### Location

The `Location` type represents a geographic or conceptual place in an energy system that contains multiple nodes for different commodities.

## [Constructors](@id manual-locations-constructors)

### Keyword Constructors

```julia
Location(; id::Symbol, system::AbstractSystem, nodes::Dict{Symbol,Node}=Dict{Symbol,Node}(), 
         commodities::Set{Symbol}=Set{Symbol}())
```

Direct constructor using keyword arguments for all fields.

| Parameter     | Type                   | Description                                      | Required |
|---------------|------------------------|--------------------------------------------------|----------|
| `id`          | Symbol                 | Unique identifier for the location              | Yes      |
| `system`      | AbstractSystem         | Reference to the containing system               | Yes      |
| `nodes`       | Dict{Symbol,Node}      | Dictionary mapping commodity symbols to nodes    | No       |
| `commodities` | Set{Symbol}            | Set of commodity symbols for contained nodes     | No       |

### Factory Constructors

```julia
load_locations!(system::AbstractSystem, rel_or_abs_path::String, data::AbstractString)
load_locations!(system::AbstractSystem, rel_or_abs_path::String, data::Vector{<:AbstractString})
load_locations!(system::AbstractSystem, rel_or_abs_path::String, data::AbstractDict{Symbol, Any})
```

Factory methods for loading locations from input data and adding them to a system.

| Parameter         | Type                    | Description                                      |
|-------------------|-------------------------|--------------------------------------------------|
| `system`          | AbstractSystem          | System to add the locations to                   |
| `rel_or_abs_path` | String                  | Relative or absolute path for data files        |
| `data`            | String/Vector/Dict      | Location data (ID strings, vector, or dictionary) |

## [Methods](@id manual-locations-methods)

### Accessor Methods

Methods for accessing location data and properties.

| Method | Description | Return Type |
|--------|-------------|-------------|
| `id(location)` | Get location identifier | `Symbol` |

### Node Management Methods

Methods for managing nodes within locations.

| Method | Description | Return Type |
|--------|-------------|-------------|
| `add_node!(location, node, replace=false)` | Add a node to the location for its commodity type | `Nothing` |
| `refresh_commodities_list!(location)` | Update the commodities set based on current nodes | `Nothing` |

### System Loading Methods

Methods for loading locations into systems from input data.

| Method | Description | Return Type |
|--------|-------------|-------------|
| `load_locations!(system, path, data::AbstractString)` | Load single location from a Location ID | `Nothing` |
| `load_locations!(system, path, data::Vector{<:AbstractString})` | Load multiple locations from vector of IDs | `Nothing` |
| `load_locations!(system, path, data::AbstractDict{Symbol,Any})` | Load locations from dictionary data | `Nothing` |

### Model Building Methods (Inherited from MacroObject)

Methods used internally during model construction.

| Method | Description | Return Type |
|--------|-------------|-------------|
| `add_linking_variables!(location, model)` | Add linking variables to JuMP model | `Nothing` |
| `define_available_capacity!(location, model)` | Define available capacity constraints | `Nothing` |
| `planning_model!(location, model)` | Add planning model constraints | `Nothing` |
| `operation_model!(location, model)` | Add operational model constraints | `Nothing` |

## [Examples](@id manual-locations-examples)

Currently, `Locations` are configured by creating and configuring `Nodes` and then adding them to a `Location`. The `load_locations!` function is used to load a list of `Location` IDs from a file. These are then populated with `Nodes` as needed. If the `AutoCreateLocations` setting is set to `true`, Macro can also automatically create `Locations` if a Node has a `location` field which does not match an existing `Location` ID. If the `AutoCreateNodes` setting is set to `true`, Macro can also automatically create `Nodes` for commodity types that do not already exist in the Location.

### Location File

The `Location` file is a JSON file that contains a list of `Location` IDs. Its default location is `system/locations.json`. The file can be structured as follows:

```json
{
  "locations": [
    "boston",
    "princeton",
    "new york"
  ]
}
```

This is not a required file, but it is a convenient way to define the `Location` IDs. In the future, we will add more functionality to this file, such as defining the `Nodes` and their commodity types.

### Adding a Node to a Location

`Nodes` are added to a `Location` by including the `location` field in the `Node` input file. For example, to add `Node{Electricity}` to Boston and Princeton, you would define it as follows:

```json
{
    "nodes": [
        {
            "type": "Electricity",
            "global_data": {
                "global_data": {
                    "time_interval": "Electricity",
                    "max_nsd": [1.0],
                    "price_nsd": [5000.0],
                    "constraints": {
                        "BalanceConstraint": true,
                        "MaxNonServedDemandConstraint": true,
                        "MaxNonServedDemandPerSegmentConstraint": true
                    }
                }
            },
            "instance_data": [
                {
                    "id": "boston_electricity",
                    "location": "boston",
                    "demand": {
                        "timeseries": {
                            "path": "system/demand.csv",
                            "header": "Demand_Boston"
                        }
                    }
                },
                {
                    "id": "princeton_electricity",
                    "location": "princeton",
                    "demand": {
                        "timeseries": {
                            "path": "system/demand.csv",
                            "header": "Demand_Princeton"
                        }
                    }
                }
            ]
        }
    ]
}
```

During the `System` generation process, Macro will add these `Nodes` to the `Locations` specified in the `location` field using the `add_node!` method. If both Boston and Princeton already have `Node{Electricity}` defined, Macro will throw an error unless the `replace` parameter of the `add_node!` is set to `true`.

### Automatically Creating Locations and Nodes

Automatic creating of `Locations` and `Nodes` can be enabled by setting the `AutoCreateLocations` and `AutoCreateNodes` flags in the system configuration (`settings/macro_settings` by default).

```json
{
  "AutoCreateNodes":false,
  "AutoCreateLocations":true,
  // ...
}
```

#### AutoCreateLocations

Using the example input from the previous section, if we did not have a `locations.json` input file but `AutoCreateLocations` is set to `true`, then Macro will create the `Location` IDs "boston" and "princeton" automatically when the corresponding `Node` instances are created.

#### AutoCreateNodes

Let's consider a second example where a `ThermalPower{NaturalGas}` Asset has a `location` field set to "boston" and that `Location` exists in the `locations.json` file. Macro will attempt to automatically connect the `UnidirectionalEdge{NaturalGas}` and `UnidirectionalEdge{Electricity}` of the `ThermalPower{NaturalGas}` Asset to the corresponding `Node` instances in the "boston" location. If one or both of these `Node` instances do not exist, and the `AutoCreateNodes` setting is set to `true`, Macro will automatically create the necessary `Node` instances for the missing commodity types.

Note that these `Nodes` will not have any exogeneous demand, supply, constraints or other properties defined. They are simply created to allow the `Asset` to connect to the `Location` without errors.

## See Also

- **[Nodes](@ref)**: Individual commodity balance points that Locations contain and manage
- **[Edges](@ref)**: Transmission and distribution infrastructure that connects nodes across locations
- **[System](@ref)**: The overall system container that holds locations, assets, and other components
- **[Assets](@ref)**: Energy technologies and infrastructure that connect to locations for simplified modeling
