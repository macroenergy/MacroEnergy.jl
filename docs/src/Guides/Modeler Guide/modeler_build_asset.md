# [Creating a New Asset](@id modeler_create_asset)

The main design principle of Macro is to allow modelers to easily extend the model with new assets. Indeed, thanks to the [graph-based representation](@ref "Energy System Graph-Based Representation"), assets can be quickly assembled by connecting `Transformation`s, `Edge`s, `Storage`s components and/or other assets. 

!!! tip "Macro Asset Library"
    Before creating a new asset, we recommend reviewing existing assets in the [`src/model/assets` folder](https://github.com/macroenergy/MacroEnergy.jl/tree/main/src/model/assets) and the [Macro Asset Library](@ref). All asset files follow a **consistent structure** to facilitate the creation of new assets.

## Overview

MacroEnergy.jl is designed to be a flexible and modular energy system modeling framework that allows users to easily extend the model with new assets. Assets in Macro are built using a [graph-based representation](@ref "Energy System Graph-Based Representation") consisting of three fundamental components:

1. **Transformations** - Represent conversion processes between commodities
2. **Edges** - Represent commodity flows between components  
3. **Storage** - Represent energy storage capabilities

## Prerequisites

Before creating a new asset, we recommend:
- Reviewing existing assets in the `src/model/assets` folder
- Reading the [Macro Asset Library](@ref Assets) documentation
- Familiarizing yourself with the graph-based representation concept
- Understand the commodity types available in your system

## Quick Start
To create a new asset (e.g. `MyNewAsset`), follow these steps:

1. **Design the asset**: Design the asset by defining its commodity inflows and outflows, conversion processes, and storage components.
    
2. (Recommended) **Draw a diagram of the asset**: Create a diagram of the asset to visualize its components and their connections. Each component will be implemented as a Macro `Transformation` (conversion process), `Edge` (commodity flow), or `Storage` (storage unit).

3. **Determine which components (`Edge`s and `Storage`s) will have capacity variables for expansion and retirement during optimization**: This is important for the optimization process.

4. **Create a new Julia file**: Create a new Julia file named `mynewasset.jl` in the `src/model/assets` folder. This file will contain the asset definition and the `make` function to construct the asset from input data. The following sections will guide you through the file creation process.

5. **Include the new asset file**: Add the following line to the `src/MacroEnergy.jl` file to include your new asset:

    ```
    include("model/assets/mynewasset.jl")
    ```

    similar to how other asset files are included.

The following sections will expand on each of the steps above.

## Step 1: Design the new asset

The first step in creating a new asset is to design its internal components, including transformations, edges, and storage units, and define how they connect to each other.

For this step, it is useful to draw a diagram of the asset to visualize the components and their connections, similar to the ones shown in the [Macro Asset Library](@ref).

!!! note "Macro Components"
    Macro components (`Transformation`, `Edge`, and `Storage`) are abstract representations of the asset's functionality in the graph-based system, as described in the [previous section](@ref "Energy System Graph-Based Representation"), and do not represent real-world components.

**Example**: Below is the diagram of the `Electrolyzer` asset:

```@raw html
<img width="300" src="../../images/electrolyzer.png" />
```

which, as you can see, it's made of the following "primary" components:

- 1 `Transformation`
- 2 `Edge` components:
    - 1 **incoming** `Electricity` `Edge`
    - 1 **outgoing** `Hydrogen` `Edge`

## Step 2: Create the new asset file

!!! note "File Structure"
    Remember to place the new asset file in the `src/model/assets` folder.

The new asset file should include the following:
- A `struct` definition for the asset, inheriting from `AbstractAsset`.
- `default_data`, `full_default_data`, and `simple_default_data` functions to define the default data for the asset.
- A `make` function to construct the asset from input data.

### 2.1 Define the asset type

Defining a new asset type in Macro is straightforward. You simply need to define a new `struct` at the top of the file as a subtype of `AbstractAsset`.

```julia
struct MyNewAsset <: AbstractAsset
    # ... asset structure will go here ...
end
```

Following the diagram of the new asset drawn in the previous step, fill in the fields of the `struct` with the appropriate components:

```julia
struct MyNewAsset <: AbstractAsset
    id::AssetId
    transform::Transformation
    edge1::Edge{CommodityType1}
    edge2::Edge{CommodityType2}
    # ... additional asset structure components ...
end
```

For example, here is the `struct` definition of the `Electrolyzer` asset:

[`src/model/assets/electrolyzer.jl`](https://github.com/macroenergy/MacroEnergy.jl/blob/ec38f804cb823f6eb666d026e18ee69cfd68b4d7/src/model/assets/electrolyzer.jl#L1C1-L6C4)

```julia
struct Electrolyzer <: AbstractAsset
    id::AssetId
    electrolyzer_transform::Transformation
    h2_edge::Edge{Hydrogen}
    elec_edge::Edge{Electricity}
end
```

You can find more examples by examining the `struct` definitions in the `.jl` files within the [`src/model/assets` folder](https://github.com/macroenergy/MacroEnergy.jl/tree/main/src/model/assets).

### 2.2 Define the default data functions

The `default_data`, `full_default_data`, and `simple_default_data` functions are used to define the default data for the new asset. This is particularly important for having the correct data setup when creating the asset. 

1\. **`default_data`**

The `default_data` is a helper function that returns a dictionary (an `OrderedDict` to be precise) with the data in the "full" or "simple" format. When creating a new asset, simply add the following lines to the file (replace `MyNewAsset` with the name of the asset being created):

```julia
function default_data(t::Type{MyNewAsset}, id=missing, style="full")
    if style == "full"
        return full_default_data(t, id)
    else
        return simple_default_data(t, id)
    end
end
```

2\. **`full_default_data`**

Here's a detailed breakdown of how to construct the `full_default_data` function:

- **Function Signature:**

    ```
    function full_default_data(::Type{MyNewAsset}, id=missing)
    ```

  - Takes the asset type as a type parameter
  - Takes an optional `id` parameter that defaults to `missing`

- **Return Structure**
The function returns an `OrderedDict{Symbol,Any}` with the following main sections:

```julia
return OrderedDict{Symbol,Any}(
    :id => id,
    # sections depending on the asset structure
    :transforms => @transform_data(...),    # If asset has transformations
    :edges => Dict{Symbol,Any}(             # If asset has edges
        :edge_name_1 => @edge_data(...),
        :edge_name_2 => @edge_data(...),
        # ... additional edges ...
    ),
    :storage => @storage_data(...)          # If asset has storage
)
```

!!! note "Default Data"
    The `@transform_data`, `@edge_data`, and `@storage_data` macros are used to define the data for the transformation, edge, and storage unit respectively and to merge the data with the default values for each component. For the list of all default data, see the [default data file](https://github.com/macroenergy/MacroEnergy.jl/blob/main/src/utilities/default_data.jl).

Copy and paste the relevant sections of the above code and modify them to fit the asset structure:

- **Transform Section**
The `:transforms` section uses the `@transform_data` macro to define transformation properties:
```julia
    :transforms => @transform_data(
        :timedata => "CommodityType",  # The commodity type to use for time resolution
        :constraints => Dict{Symbol, Bool}(  # Default/required constraints
            :BalanceConstraint => true,
            # Add other constraints as needed
        ),
        # Add transformation-specific parameters
        :parameter_name => default_value,
    )
```

- **Edges Section**
The `:edges` section defines all edges in the asset using the `@edge_data` macro:
```julia
    :edges => Dict{Symbol,Any}(
        :edge_name => @edge_data(
            :commodity => "CommodityType",  # The commodity type flowing through this edge
            :has_capacity => true,    # `edge_name` will have capacity variables by default
            :can_expand => true,      # `edge_name` can expand
            :can_retire => true,      # `edge_name` can retire
            :constraints => Dict{Symbol, Bool}(  # Edge-specific constraints
                :CapacityConstraint => true,
                # Add other constraints as needed
            ),
            # Add edge-specific parameters
            :parameter_name => default_value,
        ),
        # Add more edges as needed
    )
```

- **Storage Section** (if applicable)
If the asset includes storage, add a storage section:
```julia
    :storage => @storage_data(
        :commodity => "CommodityType",
        :constraints => Dict{Symbol, Bool}(
            :StorageCapacityConstraint => true,
            # Add other storage constraints
        ),
        # Add storage-specific parameters
        :parameter_name => default_value,
    )
```

As seen above, some common parameters you might need to include are:
- For transformations:
  - `:timedata` - Time resolution of the time series data. Common choice is "Electricity"
  - `:constraints` - Required constraints
  - **stoichiometric_coefficients** - Stoichiometric coefficients for the transformation (e.g. `:fuel_consumption`, `:emission_rate`, etc.)

- For edges:
  - `:commodity` - The commodity type flowing through the edge
  - `:has_capacity` - To specify that a particular edge has capacity variables
  - `:can_expand` - To specify that a particular edge can expand
  - `:can_retire` - To specify that a particular edge can retire
  - `:constraints` - Edge-specific constraints

**Example Implementation**

Here's an example implementation based on the `Electrolyzer` asset:
```julia
function full_default_data(::Type{Electrolyzer}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :transforms => @transform_data(
            :timedata => "Electricity",
            :constraints => Dict{Symbol, Bool}(
                :BalanceConstraint => true,
            ),
            :efficiency_rate => 0.0
        ),
        :edges => Dict{Symbol,Any}(
            :h2_edge => @edge_data(
                :commodity => "Hydrogen",
                :has_capacity => true,
                :can_retire => true,
                :can_expand => true,
                :can_retire => true,
                :constraints => Dict{Symbol, Bool}(
                    :CapacityConstraint => true,
                ),
            ),
            :elec_edge => @edge_data(
                :commodity => "Electricity",
            ),
        ),
    )
end
```

As can be seen above, the default data for the `Electrolyzer` asset includes:
- A `Transformation` component with the `:timedata` set to `"Electricity"`, `:constraints` set to `:BalanceConstraint` and an `:efficiency_rate` set to `0.0`.
- A `Hydrogen` `Edge` with **capacity variables** and the ability to expand and retire by default.
- An `Electricity` `Edge` with no capacity variables.

3\. **`simple_default_data`**

As mentioned above, the `simple_default_data` function returns a compact version of the default data dictionary. The main difference with the `full_default_data` function is that the dictionary that is returned doesn't include sub-dictionaries for the `:transforms`, `:edges`, and `:storage` sections, and all the **data is included in the top-level dictionary**.

The function signature is the same as the `full_default_data` function, but the **return structure** is different:
```julia
function simple_default_data(::Type{MyNewAsset}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :parameter_name => default_value,
        # ... additional parameters ...
    )
end
```

As an example, here's the `simple_default_data` function for the `Electrolyzer` asset:
```julia
function simple_default_data(::Type{Electrolyzer}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :location => missing,
        :can_expand => true,
        :can_retire => true,
        :existing_capacity => 0.0,
        :capacity_size => 1.0,
        :efficiency_rate => 0.0,
        :investment_cost => 0.0,
        :fixed_om_cost => 0.0,
        :variable_om_cost => 0.0,
    )
end
```

### 2.3 Define the `make` function
The `make` function is used to tell Macro how to create an instance of the new asset.
It is a crucial step for the following tasks:
- **Reading** the relevant sections of the input file and **constructing each component** of the asset (e.g. `Transformation`, `Edge`, `Storage`)
- Incorporating **modeling choices** or default behaviors (e.g. linking edges to the correct nodes)
- Creating the **stoichiometric equations** for the conversion processes happening in the asset (see the `balance_data` attribute of the `Transformation` and `Storage` components described in the [Stoichiometric Coefficients](@ref "2.3.4 Balance Data") section below)

1\. **Function Signature**

Let's start by looking at the **function signature**:
```julia
function make(asset_type::Type{MyNewAsset}, data::AbstractDict{Symbol,Any}, system::System)
    # ... implementation details ...
end
```

The `make` function takes three arguments:
- `asset_type::Type{MyNewAsset}`: The type of the asset to be created (i.e. `MyNewAsset`)
- `data::AbstractDict{Symbol,Any}`: A dictionary containing the input data for the asset.
- `system::System`: The system in which the asset is being added.

2\. **Return Structure**

The function should return an instance of the asset:
```julia
function make(asset_type::Type{MyNewAsset}, data::AbstractDict{Symbol,Any}, system::System)
    # ... implementation details ...
    return MyNewAsset(id, transform, edge1, edge2, # ... additional components ...)
end
```

3\. **Implementation**

The body of the `make` function can be broken down into five main blocks:

1. **ID Setup** – Assigning a unique identifier to the asset
2. **Data Setup** – Loading and organizing default input data
3. **Component Creation** – Building each component (e.g., transformations, edges, etc.)
4. **Stoichiometric Coefficients Setup** – Defining the stoichiometric equations for the asset's balance equations
5. **Asset creation** – Constructing the asset

Let's break down each block separately and see how to implement them.

#### 2.3.1 ID Setup
The first block of the `make` function is the ID setup. It reads the `:id` key from the input data and creates a unique identifier for the asset (of type `AssetId`).

```julia
id = AssetId(data[:id])
```

#### 2.3.2 Data Setup
The second block of the `make` function is the data setup. It prepares the input data for the rest of the function and loads all default data for the asset.

```julia
@setup_data(asset_type, data, id)
```

#### 2.3.3 Component Creation
The third block of the `make` function is the component creation. It builds each component of the asset separately, and prepares the `Edge`s, `Transformation`, and `Storage` to be used in final asset creation.

!!! tip "Modeling Choices"
    In this step, modelers can make modeling choices, setting default values for missing data and constraints, linking edges to the correct nodes, and more. See the asset files in the `src/model/assets` folder for examples.

Each **component creation** is made of the following steps (we will use the `Electrolyzer` asset as an example):

- **Key assignment**

Add a line to assign the key for the component to a new variable of type `Symbol`. This key is used to load the correct portion of the data corresponding to the component being created.

!!! warning "Key Assignment"
    Make sure to match the key used in the both the `full_default_data` function and the JSON input file to group the data for the corresponding component.

For instance, in the `Electrolyzer` asset, the key for the transformation used in the `full_default_data` function and the JSON input file is `:transforms`. So, the following line is added to the `make` function:

```julia
electrolyzer_key = :transforms
```

The keys for the other components of the `Electrolyzer` asset are assigned in a similar way:

```julia
elec_edge_key = :elec_edge
# ...
h2_edge_key = :h2_edge
```

- **Input data loading**
This step invokes the `@process_data` macro to load the input data for each component from the JSON input file. The macro takes three arguments:
- The variable to store the processed data.
- The section of the input data to process (e.g, `data[component_key]`).
- A list of tuples containing the data and the key to search for in the input data.

Here is an example of how the `@process_data` macro works for the `Electrolyzer` asset:
```julia
@process_data(
    transform_data,          # The variable to store the processed data
    data[electrolyzer_key],  # The section of the input data to process
    [
        (data[electrolyzer_key], key),
        (data[electrolyzer_key], Symbol("transform_", key)),
        (data, Symbol("transform_", key)),
        (data, key),
    ]
)
```
In particular, for each key in the default data, the macro will look for a match in the input data in the following order:

1. Check if the `transforms` section of the JSON input file (i.e., `data["transforms"]`) contains the key.
2. Check if the `transforms` section of the JSON input file (i.e., `data["transforms"]`) contains the key with the prefix `transform_` (e.g. `transform_constraints`).
3. Check if the `data` section of the input data (i.e., the top-level of the JSON input file) contains the key with the prefix `transform_` (e.g. `transform_constraints`). **Note**: This is very important for the reduced data format, where all the data is at the top-level.
4. Check if the `data` section of the input data contains the key.

The macro will look for data in each source in sequence, using the first value it finds. This allows for flexible data specification with fallback options.

This is another example of a component creation for the hydrogen **edge** of the `Electrolyzer` asset:
```julia
h2_edge_key = :h2_edge  # The key for the hydrogen edge in the input data
@process_data(
    h2_edge_data, 
    data[:edges][h2_edge_key],  # The section of the input data to process
    [
        (data[:edges][h2_edge_key], key),
        (data[:edges][h2_edge_key], Symbol("h2_", key)),
        (data, Symbol("h2_", key)),
        (data, key),
    ]
)
```

- **Vertex assignment (for edges)**
This step assigns the correct nodes, transformation, or storage unit to each edge (in Macro, these three components are also called `Vertices`, see [Macro Internal Components](@ref) for more details).

When assigning vertices to edges, two cases can happen:
1. The edge is connected to an asset component defined earlier in the `make` function (e.g. a transformation or a storage unit).
2. The edge is connected to an external `Node`, which is defined outside of the asset in the nodes JSON file.

In the first case, simply create a new variable with the name of the component and assign it to the component.

```julia
# The vertex is the transformation itself (look at the diagram above)
elec_end_node = electrolyzer_transform
# ...
h2_start_node = electrolyzer_transform  
```
`elec_end_node` and `h2_start_node` will now contain the transformation that must be connected to the electricity and hydrogen edges respectively.

In the second case, the vertex is an external `Node`. The id of the node must be listed in the edge data of the JSON input file using the `:locations` key or `start_vertex`/`end_vertex` keys. Macro provides two macros, `@start_vertex` and `@end_vertex`, to find the correct node in the system and store it in a variable.

The `@start_vertex` and `@end_vertex` macros take four arguments:
- The variable to store the node.
- The edge data.
- The commodity type of the edge.
- A list of tuples containing the edge data and the key to search for in the JSON input file.

Here is an example for the electricity edge of the `Electrolyzer` asset:
```julia
@start_vertex(
    elec_start_node,
    elec_edge_data,
    Electricity,
    [(elec_edge_data, :start_vertex), (data, :location)],
)
```
The `elec_start_node` variable will now contain the node that must be connected to the electricity edge.

This is the example for the hydrogen edge of the `Electrolyzer` asset:
```julia
@end_vertex(
    h2_end_node,
    h2_edge_data,
    Hydrogen,
    [(h2_edge_data, :end_vertex), (data, :location)],
)
```
The `h2_end_node` variable will now contain the node that must be connected to the hydrogen edge.

- **Instance creation**
The final step creates an instance of the edge, transformation, or storage unit and stores it in a variable. Use the `Edge`, `Transformation`, or `Storage` functions to create the corresponding instance.

For example, here is how to create the transformation component for the `Electrolyzer` asset:
```julia
electrolyzer_transform = Transformation(;
    id = Symbol(id, "_", electrolyzer_key),  # The id of the transformation is the id of the asset plus the key of the transformation
    timedata = system.time_data[Symbol(transform_data[:timedata])],
    constraints = transform_data[:constraints],
)
```
`electrolyzer_transform` is now an instance of the `Transformation` type and can, for example, be used in the `Edge` creation step as `start_node` and `end_node` (see below).

Here is an example for the electricity edge of the `Electrolyzer` asset:
```julia
elec_edge = Edge(
    Symbol(id, "_", elec_edge_key),
    elec_edge_data,
    system.time_data[:Electricity],
    Electricity,
    elec_start_node,
    elec_end_node,
)
```

Note the last two arguments of the `Edge` function:
- `elec_start_node` is a `Node` instance of type `Electricity` created using the `@start_vertex` macro.
- `elec_end_node` is the `Transformation` part of the asset created in the previous step.

Similarly, here is an example for the hydrogen edge of the `Electrolyzer` asset:
```julia
h2_edge = Edge(
    Symbol(id, "_", h2_edge_key),
    h2_edge_data,
    system.time_data[:Hydrogen],
    Hydrogen,
    h2_start_node,
    h2_end_node,
)
```

To summarize, this is the complete component creation step for the `Transformation` and `Edge` components of the `Electrolyzer` asset:

```julia
# Transformation creation
electrolyzer_key = :transforms
@process_data(
    transform_data, 
    data[electrolyzer_key], 
    [
        (data[electrolyzer_key], key),
        (data[electrolyzer_key], Symbol("transform_", key)),
        (data, Symbol("transform_", key)),
        (data, key),
    ]
)
electrolyzer = Transformation(;
    id = Symbol(id, "_", electrolyzer_key),
    timedata = system.time_data[Symbol(transform_data[:timedata])],
    constraints = transform_data[:constraints],
)

# Electricity edge creation
elec_edge_key = :elec_edge
@process_data(
    elec_edge_data, 
    data[:edges][elec_edge_key], 
    [
        (data[:edges][elec_edge_key], key),
        (data[:edges][elec_edge_key], Symbol("elec_", key)),
        (data, Symbol("elec_", key)),
    ]
)
@start_vertex(
    elec_start_node,
    elec_edge_data,
    Electricity,
    [(elec_edge_data, :start_vertex), (data, :location)],
)
elec_end_node = electrolyzer
elec_edge = Edge(
    Symbol(id, "_", elec_edge_key),
    elec_edge_data,
    system.time_data[:Electricity],
    Electricity,
    elec_start_node,
    elec_end_node,
)

# Hydrogen edge creation
h2_edge_key = :h2_edge
@process_data(
    h2_edge_data, 
    data[:edges][h2_edge_key], 
    [
        (data[:edges][h2_edge_key], key),
        (data[:edges][h2_edge_key], Symbol("h2_", key)),
        (data, Symbol("h2_", key)),
        (data, key),
    ]
)
h2_start_node = electrolyzer
@end_vertex(
    h2_end_node,
    h2_edge_data,
    Hydrogen,
    [(h2_edge_data, :end_vertex), (data, :location)],
)
h2_edge = Edge(
    Symbol(id, "_", h2_edge_key),
    h2_edge_data,
    system.time_data[:Hydrogen],
    Hydrogen,
    h2_start_node,
    h2_end_node,
)
```

#### 2.3.4 Balance Data
This step defines the stoichiometric equations for the balance equations of the transformations and defines the efficiency in charge and discharge of the storage units.

- **Transformations**
The stoichiometric equations are defined in the `balance_data` dictionary of the `Transformation` instance.

Here is an example for the `Electrolyzer` asset:
```julia
electrolyzer_transform.balance_data = Dict(
    :energy => Dict(
        h2_edge.id => 1.0,
        elec_edge.id => get(transform_data, :efficiency_rate, 1.0),
    ),
)
```
and the stoichiometric equation is:
 ```math
\begin{aligned}
\phi_{h2} &= \phi_{elec} \cdot \epsilon_{efficiency} \\
\end{aligned}
```
where $\phi_{h2}$ is the flow of hydrogen, $\phi_{elec}$ is the flow of electricity, and $\epsilon_{efficiency}$ is the efficiency rate of the electrolyzer.

!!! warning "Balance Data Keys"
    You can define as many balance equations as needed. The only requirement is that the keys in the `balance_data` dictionaries (e.g. `:energy`, `:emissions`, etc.) must be unique.
    See the [src/model/assets folder](https://github.com/macroenergy/MacroEnergy.jl/tree/main/src/model/assets) for more examples of balance data definitions.

- **Storage units**
The efficiency in charge and discharge of the storage units are defined in the `balance_data` dictionary of the `Storage` instance.

Example taken from the `Battery` asset:
```julia
battery_storage.balance_data = Dict(
    :storage => Dict(
        battery_discharge.id => 1 / discharge_efficiency,
        battery_charge.id => charge_efficiency,
    ),
)
```

#### 2.3.5 Asset creation
This is the final step of the `make` function. It integrates all components to construct and return the final asset. 

```julia
return MyNewAsset(id, transform, edge1, edge2, # ... all components ...)
```

!!! warning "Positional arguments"
    The positional arguments of the asset constructor must match the order of the components in the asset `struct` definition.
    For example, if the asset `struct` is defined as 
    ```julia
    struct ExampleAsset <: AbstractAsset
        id::AssetId
        transform::Transformation
        edge1::Edge
        edge2::Edge
    end
    ```
    then the asset must be created as:
    ```julia
    return ExampleAsset(id, transform, edge1, edge2)
    ```

For example, here is how to create the `Electrolyzer` asset:
```julia
return Electrolyzer(id, electrolyzer_transform, h2_edge, elec_edge)
```

## Key Components and Concepts

### [Transformations](@ref)
- Represent conversion processes between commodities
- Have stoichiometric equations defined in `balance_data`

### [Edges](@ref)
- Represent commodity flows
- Can have capacity variables for optimization
- Connect to nodes, transformations, or storage units
- Can be configured for expansion/retirement

### [Storage](@ref)
- Track energy levels over time
- Can have charge/discharge edges
- Support various storage constraints

### [Constraints](@ref macro_constraint_library)
Common constraints include:
- `BalanceConstraint` - Ensures mass/energy balance
- `CapacityConstraint` - Limits capacity
- `StorageCapacityConstraint` - Limits storage capacity
- `RampingLimitConstraint` - Limits rate of change
- `MinFlowConstraint` - Sets minimum flow requirements

## Best Practices

1. **Follow existing patterns**: Study similar assets in the codebase
2. **Use meaningful names**: Choose descriptive names for components
3. **Document constraints**: Clearly specify which constraints apply
4. **Test thoroughly**: Create example cases to validate your asset
5. **Consider efficiency**: Define appropriate stoichiometric coefficients
6. **Handle edge cases**: Consider what happens with missing data
7. **Use consistent naming**: Follow the naming conventions used in existing assets
8. **Validate input data**: Ensure your asset handles missing or invalid data gracefully

## Complete Example: `MyNewAsset`

Here's a simplified example of a complete asset implementation with two edges and a transformation (Electricity to Hydrogen):

```julia
# mynewasset.jl
struct MyNewAsset <: AbstractAsset
    id::AssetId
    transform::Transformation
    input_edge::Edge{Electricity}
    output_edge::Edge{Hydrogen}
end

function default_data(t::Type{MyNewAsset}, id=missing, style="full")
    if style == "full"
        return full_default_data(t, id)
    else
        return simple_default_data(t, id)
    end
end

function full_default_data(::Type{MyNewAsset}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :transforms => @transform_data(
            :timedata => "Electricity",
            :constraints => Dict{Symbol, Bool}(:BalanceConstraint => true),
            :efficiency => 0.8,
        ),
        :edges => Dict{Symbol,Any}(
            :input_edge => @edge_data(
                :commodity => "Electricity",
            ),
            :output_edge => @edge_data(
                :commodity => "Hydrogen",
                :has_capacity => true,
                :can_expand => true,
                :can_retire => true,
                :constraints => Dict{Symbol, Bool}(:CapacityConstraint => true),
            ),
        ),
    )
end

function simple_default_data(::Type{MyNewAsset}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :location => missing,
        :efficiency => 0.8,
        :investment_cost => 0.0,
        :fixed_om_cost => 0.0,
        :variable_om_cost => 0.0,
    )
end

function make(asset_type::Type{MyNewAsset}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])
    @setup_data(asset_type, data, id)
    
    # Create transformation
    transform_key = :transforms
    @process_data(transform_data, data[transform_key], [
        (data[transform_key], key),
        (data[transform_key], Symbol("transform_", key)),
        (data, Symbol("transform_", key)),
        (data, key),
    ])
    transform = Transformation(;
        id = Symbol(id, "_", transform_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        constraints = transform_data[:constraints],
    )
    
    # Create input edge
    input_key = :input_edge
    @process_data(input_data, data[:edges][input_key], [
        (data[:edges][input_key], key),
        (data[:edges][input_key], Symbol("input_", key)),
        (data, Symbol("input_", key)),
    ])
    @start_vertex(input_start_node, input_data, Electricity, [
        (input_data, :start_vertex), (data, :location)
    ])
    input_end_node = transform
    input_edge = Edge(
        Symbol(id, "_", input_key),
        input_data,
        system.time_data[:Electricity],
        Electricity,
        input_start_node,
        input_end_node,
    )
    
    # Create output edge
    output_key = :output_edge
    @process_data(output_data, data[:edges][output_key], [
        (data[:edges][output_key], key),
        (data[:edges][output_key], Symbol("output_", key)),
        (data, Symbol("output_", key)),
    ])
    output_start_node = transform
    @end_vertex(output_end_node, output_data, Hydrogen, [
        (output_data, :end_vertex), (data, :location)
    ])
    output_edge = Edge(
        Symbol(id, "_", output_key),
        output_data,
        system.time_data[:Hydrogen],
        Hydrogen,
        output_start_node,
        output_end_node,
    )
    
    # Set up stoichiometric equations
    efficiency = get(transform_data, :efficiency, 1.0)
    transform.balance_data = Dict(
        :energy => Dict(
            output_edge.id => 1.0,
            input_edge.id => efficiency,
        ),
    )
    
    return MyNewAsset(id, transform, input_edge, output_edge)
end
```

## Testing Your Asset

1. **Create a test case** based on the existing example cases.
2. **Add realistic parameters** to your input files
3. **Run the model** to ensure it works correctly
4. **Check results** to verify the asset behaves as expected
5. **Add constraints** as needed for realistic operation

## Documentation

Don't forget to:
1. **Document your asset** following the pattern in `docs/src/Manual/assets/`
2. **Include a mermaid diagram** showing the asset structure
3. **List all parameters** and their units
4. **Provide examples** of different configurations
5. **Update the asset library** documentation

All these steps are covered in the [Documenting an Asset](@ref modeler_add_docs_to_asset) guide.

## Next Steps

We recommend reviewing the following sections in the **Modeler Guide** for additional guidance on how to efficiently develop and test new assets:
- [Documenting an Asset](@ref modeler_add_docs_to_asset): A guide to documenting the new asset.
- [Creating a New Example Case](@ref modeler_create_example_case): A step-by-step guide to creating a new example case for testing and validation of the new asset.
- [Suggested Development Workflow](@ref "Suggested Development Workflow"): A recommended workflow for developing new assets.
- [Debugging and Testing Tips](@ref "Debugging and Testing a Macro Model"): Tips and best practices for debugging and testing new assets.
