# System

## Contents

[Overview](@ref "manual-system-overview") | [Fields](@ref "System Fields") | [Types](@ref "manual-system-types") | [Constructors](@ref "manual-system-constructors") | [Methods](@ref "manual-system-methods") | [Examples](@ref "manual-system-examples")

## [Overview](@id manual-system-overview)

The `System` type is a compound component in Macro which represents the complete description of an energy system for a single operating period. It serves as a container that aggregates all the essential elements needed to define and analyze an energy system, including settings, commodities, time data, and the network of locations and nodes.

### Key Distinction: System vs Model

It's important to understand the distinction between a `System` and the optimization model:

- **System**: Describes the physical and economic characteristics of the energy system (infrastructure, parameters, time series data, etc.)
- **Model**: The mathematical optimization formulation built from one or more Systems

A `System` contains the data and structure that defines *what* the energy system looks like, while the optimization model defines *how* to solve for optimal operations, investments, or planning decisions.

### Role and Purpose

The `System` type plays several critical roles:

1. **Data Aggregation**: Consolidates all necessary data components (settings, commodities, time data, nodes, edges, storage, transformations) into a single coherent structure

2. **Single Period Representation**: Represents the energy system for one specific operating period, with all associated time series data, operational parameters, and network configuration

3. **Multi-System Integration**: Multiple `System` objects can be combined into a [`Case`](@ref Case) to represent multi-period planning problems, stochastic scenarios, or different operating conditions

4. **Model Input**: Serves as the primary input for building optimization models, providing all the data needed for constraint generation and variable definition

5. **Validation and Consistency**: Ensures that all components of the energy system are compatible and properly configured before model building

### System Components

A `System` aggregates the following key components:

- **Settings**: Configuration parameters that control model behavior and solution approaches
- **Commodities**: Definitions of all energy carriers, materials, and services in the system
- **Time Data**: Temporal information including time steps, periods, and associated time series data
- **Network Elements**: All physical and logical components of the energy system
  - **Nodes**: Geographic or conceptual locations where commodities are balanced
  - **Edges**: Transmission and distribution infrastructure connecting nodes
  - **Storage**: Energy storage technologies and facilities
  - **Transformations**: Technologies that convert between different commodities

### Multi-Period and Scenario Modeling

While a single `System` represents one operating period, MacroEnergy.jl supports complex modeling scenarios through:

- **Multi-Period Cases**: Multiple `System` objects representing different time periods (e.g., years in a planning horizon)
- **Stochastic Modeling**: Multiple `System` objects representing different uncertainty scenarios
- **Operational vs Planning**: Different `System` configurations for operational dispatch vs long-term capacity planning

This design provides flexibility for modeling everything from single-year operational problems to multi-decade capacity expansion planning under uncertainty.

### Key Concepts

- **System vs Model**: A `System` describes the physical energy infrastructure and data, while the optimization model defines the mathematical problem to be solved
- **Single Period**: Each `System` represents one operating period with its own time series, parameters, and network configuration
- **Data Container**: Systems aggregate all essential components (settings, commodities, time data, locations, assets) into a coherent structure
- **Multi-System Cases**: Multiple `System` objects can be combined to model multi-period planning, stochastic scenarios, or sensitivity analyses
- **Network Integration**: Systems contain all network elements (nodes, edges, storage, transformations) that define the energy system topology
- **System Data**: Systems are defined using the system_data.json input file

## System Fields

`Systems` have the following fields. When creating a model, these fields are populated through input files or programmatically constructed. The fields represent all the essential data needed to define a complete energy system for optimization.

!!! note "Units in Macro"
    We have assumed that your System is using units of MWh for energy, tonnes for mass, and hour-long time steps. You can use any set of units as long as they are consistent across your operations and investment inputs.

### Data Management

| Field               | Type                               | Description                                      | Default |
|---------------------|------------------------------------|-------------------------------------------------|---------|
| `data_dirpath`      | String                             | Path to directory containing system input files | -       |

### Configuration and Settings

| Field               | Type                               | Description                                      | Default |
|---------------------|------------------------------------|-------------------------------------------------|---------|
| `settings`          | NamedTuple                         | Configuration parameters for model behavior     | NamedTuple() |
| `commodities`       | Dict{Symbol,DataType}              | Map of commodity symbols to their types         | Dict{Symbol,DataType}() |

### Temporal Data

| Field               | Type                               | Description                                      | Default |
|---------------------|------------------------------------|-------------------------------------------------|---------|
| `time_data`         | Dict{Symbol,TimeData}              | Time series data for each commodity             | Dict{Symbol,TimeData}() |

### Network Components

| Field               | Type                               | Description                                      | Default |
|---------------------|------------------------------------|-------------------------------------------------|---------|
| `assets`            | Vector{AbstractAsset}              | All assets (technologies) in the system        | AbstractAsset[] |
| `locations`         | Vector{Union{Node, Location}}      | All nodes and locations in the system          | Union{Node, Location}[] |

## [Types](@id manual-system-types)

### Type Hierarchy

`System` types follow a simple hierarchical structure:

```julia
AbstractSystem
└── System
```

### System Type

The `System` type represents a complete energy system description for a single operating period. It serves as the primary container for all system data, aggregating settings, commodities, time data, and network components.

Key characteristics:

- **Single Period Representation**: Each System represents one operating period with consistent temporal data
- **Data Aggregation**: Consolidates all necessary components (settings, commodities, time data, assets, locations)
- **Input File Integration**: Designed to be populated from standardized input file formats
- **Model Building**: Serves as the primary input for optimization model construction
- **Multi-System Compatibility**: Can be combined with other Systems in Case objects for multi-period modeling

## [Constructors](@id manual-system-constructors)

### Direct Constructors

```julia
System(data_dirpath::String, settings::NamedTuple, commodities::Dict{Symbol,DataType}, 
       time_data::Dict{Symbol,TimeData}, assets::Vector{AbstractAsset}, 
       locations::Vector{Union{Node, Location}})
```

Direct constructor using all fields explicitly.

| Parameter      | Type                               | Description                                      | Required |
|----------------|------------------------------------|-------------------------------------------------|----------|
| `data_dirpath` | String                             | Path to directory containing system input files | Yes      |
| `settings`     | NamedTuple                         | Configuration parameters for model behavior     | Yes      |
| `commodities`  | Dict{Symbol,DataType}              | Map of commodity symbols to their types         | Yes      |
| `time_data`    | Dict{Symbol,TimeData}              | Time series data for each commodity             | Yes      |
| `assets`       | Vector{AbstractAsset}              | All assets in the system                        | Yes      |
| `locations`    | Vector{Union{Node, Location}}      | All nodes and locations in the system          | Yes      |

### Factory Constructors

```julia
empty_system(data_dirpath::String)
```

Creates an empty System with minimal initialization, suitable for programmatic population.

| Parameter      | Type   | Description                              |
|----------------|--------|------------------------------------------|
| `data_dirpath` | String | Path to directory for system input files |

```julia
load_system(path::AbstractString; lazy_load::Bool=true)
```

Loads a complete System from input files in the specified directory or file path.

| Parameter   | Type           | Description                                          |
|-------------|----------------|------------------------------------------------------|
| `path`      | AbstractString | Path to system directory or `system_data.json` file   |
| `lazy_load` | Bool           | Whether to load data lazily (default: true)         |

## [Methods](@id manual-system-methods)

### Accessor Methods

Methods for accessing system data, components, and properties.

| Method | Description | Return Type |
|--------|-------------|-------------|
| `asset_ids(system; source="assets")` | Get asset IDs from system or input files | `Set{AssetId}` |
| `location_ids(system)` | Get IDs of all locations in the system | `Vector{Symbol}` |
| `get_asset_types(system)` | Get types of all assets in the system | `Vector{DataType}` |
| `get_asset_by_id(system, id)` | Find asset by its ID | `Union{AbstractAsset,Nothing}` |
| `find_locations(system, id)` | Find location by its ID | `Union{Node,Location,Nothing}` |
| `get_assets_sametype(system, asset_type)` | Get all assets of specific type | `Vector{<:AbstractAsset}` |
| `get_nodes(system)` | Get all nodes and locations | `Vector{Union{Node,Location}}` |
| `get_edges(system; return_ids_map=false)` | Get all edges from assets | `Vector{AbstractEdge}` or `Tuple` |
| `get_storages(system; return_ids_map=false)` | Get all storage components from assets | `Vector{AbstractStorage}` or `Tuple` |
| `get_transformations(system; return_ids_map=false)` | Get all transformation components from assets | `Vector{Transformation}` or `Tuple` |
| `edges_with_capacity_variables(system; return_ids_map=false)` | Get edges with capacity variables | `Vector{AbstractEdge}` or `Tuple` |
| `find_node(nodes_list, id, commodity=missing)` | Search for node with specified ID and commodity | `Union{Node,Nothing}` |

### System Modification Methods

Methods for modifying system contents.

| Method | Description | Return Type |
|--------|-------------|-------------|
| `set_data_dirpath!(system, data_dirpath)` | Set the data directory path | `Nothing` |
| `add!(system, asset)` | Add an asset to the system | `Nothing` |
| `add!(system, location)` | Add a location/node to the system | `Nothing` |

### Factory Methods

Methods for creating system instances.

| Method | Description | Return Type |
|--------|-------------|-------------|
| `empty_system(data_dirpath)` | Create empty system with specified data path | `System` |
| `load_system(path; lazy_load=true)` | Load complete system from input files | `System` |
| `generate_system(system, system_data)` | Generate system from system data dictionary | `Nothing` |
| `load_system_data(file_path, system)` | Load system data from input file at `file_path`, with relative paths based on `system.data_dirpath` | `Dict{Symbol,Any}` |
| `load!(system, file_path)` | Load system data from input file at `file_path` into `system` | `Nothing` |
| `load!(system, system_data::AbstractDict{Symbol,Any})` | Load system data into existing `system` | `Nothing` |
| `load!(system, data::AbstractVector{<:AbstractDict{Symbol,Any}}))` | Load system data from a vector of dictionaries into `system` | `Nothing` |
| `load!(system, data::Any)` | Throws an error for badly formatted input data | `Nothing` |

## [Examples](@id manual-system-examples)

Most Users and Modellers will not need to create a System directly as they will be automatically created when the system data input file is loaded. The following examples show some of how Macro does these tasks. These steps could be used to create a System programmatically.

### Loading and creating a System

If we have a system data file called `system_data.json` in the current directory, we can load it into a System object as follows:

```julia
using MacroEnergy

file_path = joinpath(pwd(), "system_data.json")  # Path to your system data file
system_data = load_system_data(file_path)  # Load system data from file
system = empty_system(dirname(file_path))  # Create an empty System with the data directory path
generate_system!(system, system_data)  # Populate the System with data
```

Alternatively, we can use the `load_system` function to create a System directly from the input file:

```julia
using MacroEnergy

file_path = joinpath(pwd(), "system_data.json")  # Path to your system data file
system = load_system(file_path)  # Load system directly from file
```

### System Data File Structure

`Systems` and `Cases` are typically defined in the `system_data.json` file, which contains all the necessary data to define the energy system. Full details on the structure of this file can be found in the [Inputs](@ref) section. Here, we review the structure of the `system_data.json` file:

The following is a `Case` made up of one operating period / stochastic scenario / sensitivity case. The `case` field containts an array of `System` definitions. These definitions could directly include all of the `System` data but in this case we've used Macro's `path` feature to refer to other JSON files. These addresses are relative to the `data_dirpath` of the `System` or the directory containing the `system_data.json` file.

The `settings` field outside of the `case` array contains the `Case` settings.

```json
{
    "case": [
        {
            "commodities": {
                "path": "system/commodities.json"
            },
            "locations": {
                "path": "system/locations.json"
            },
            "settings": {
                "path": "settings/macro_settings.json"
            },
            "assets": {
                "path": "assets"
            },
            "time_data": {
                "path": "system/time_data.json"
            },
            "nodes": {
                "path": "system/nodes.json"
            }
        }
    ],
    "settings": {
        "path": "settings/case_settings.json"
    }
}
```

## See Also

- [Case](@ref Case) - Container for multiple Systems representing different scenarios or periods
- [Edges](@ref) - Components that connect Vertices and carry flows
- [Nodes](@ref) - Network nodes that allow for import and export of commodities
- [Storage](@ref) - Components that store commodities for later use
- [Transformations](@ref) - Components that convert commodities from one type to another
- [Commodities](@ref) - Types of resources stored by Commodities
- [Time Data](@ref) - Temporal modeling framework
- [Settings](@ref "Configuring Settings") - Configuration parameters for model behavior
- [Inputs](@ref) - Input file formats and data structures
