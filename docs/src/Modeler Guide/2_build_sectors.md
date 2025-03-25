# Modeler Guide

## How to build new sectors in Macro

This section provides an overview of the steps to build new sectors in Macro, including:
1. Adding new commodities to the model.
2. Creating new assets and transformation processes.
3. Adding modeling details to the assets (e.g., constraints, data, etc.).

### 1. Adding a new sector to Macro
In Macro, each sector is defined by a `Commodity` type. More specifically, a commodity type is defined as a subtype of the `Commodity` type, as can be seen at the top of the `MacroEnergy.jl` file:

`MacroEnergy.jl`
```julia
## Commodity types
abstract type Commodity end
abstract type Electricity <: Commodity end ## MWh
abstract type Hydrogen <: Commodity end ## MWh
```

the operator `<:` means *is-a-subtype-of*, that is `Electricity` and `Hydrogen` are **subtypes** of `Commodity`. 

Therefore, to add a new sector to Macro, the modeler needs to add a new line in the `MacroEnergy.jl` file, as follows:

`MacroEnergy.jl`
```julia
# ... existing code ...
abstract type MyNewSector <: Commodity end
# ... existing code ...
```

### 2. Create new assets
Once the new commodity type is added to Macro, the modeler can create new assets that use this commodity type. For instance, a modeler may want to create a new asset that converts a commodity `MyNewSector` into two other commodities, `Electricity` and `CO2`. 

!!! tip "Tip"
    Before creating a new asset, we recommend the modeler to have a look at the existing assets in the `src/assets` folder. All the asset files follow a same structure to streamline the creation of new assets.

As for the case of the commodity type, each asset in Macro is defined as a **subtype** of the `AbstractAsset` type (the user can find some examples by checking the `struct` definition in the `.jl` files in the `src/assets` folder):

`src/assets/electrolyzer.jl`
```julia
struct Electrolyzer <: AbstractAsset
    id::AssetId
    electrolyzer_transform::Transformation
    h2_edge::Edge{Hydrogen}
    elec_edge::Edge{Electricity}
end
```

The steps to create a new asset `MyNewAsset` are:
1. Design the new asset in terms of transformations, edges, and storage units for each commodity type used in the asset.
2. Create a new Julia file in the `src/assets` folder called `mynewasset.jl`.
3. At the top of the file, define the asset type as a subtype of `AbstractAsset`.

```julia
struct MyNewAsset <: AbstractAsset
    # ... asset structure will go here ...
end
```

4. Define the fields of the asset type as transformations, edges, and storage units with the appropriate commodity types.

```julia
struct MyNewAsset <: AbstractAsset
    transform::Transformation
    edge1::Edge{CommodityType1}
    edge2::Edge{CommodityType2}
    # ... rest of the asset structure will go here ...
end
```

5. Define a `make` function in the same file with the steps to create an instance of the asset. The function should have the following signature:
```julia
function make(::Type{MyNewAsset}, data::AbstractDict{Symbol,Any}, system::System)
    # ... make function will go here ...
    return MyNewAsset(transform, edge1, edge2, # ... rest of the asset structure will go here ...)
end
```

!!! note "Make function"
    The `make` function should include the steps to create the asset structure, including:
    1. **Creation of each component of the asset**: transformations, edges, and storage units.
    2. **Default constraints** for each component.
    3. **Stoichiometric equations/coefficients** for the transformation processes.

6. (Optional) Create a new JSON data file to test the new assets.

!!! warning "Include the new files in the MacroEnergy.jl file"
    Remember to include the new files in the `MacroEnergy.jl` file, so that they are available when the package is loaded.

The following section provides an example of how to create a new sector and assets in Macro.

### Example
For example, let's create a new sector called `MyNewSector` with two assets: `MyAsset1`, and `MyAsset2`. 

The first asset will be a technology that converts a commodity `MyNewSector`, into two other commodities, `Electricity` and `CO2`, while the second asset will be a technology with a `storage unit` that stores the commodity `MyNewSector`.

As seen in the previous section, the steps to create a new sector and assets are as follows:
- Add the following line to the MacroEnergy.jl file:
```julia
abstract type MyNewSector <: Commodity end
```
(try to add this line right after the definition of the `Commodity` type). 

- Create a new file called `MyAsset1.jl` in the `src/assets` folder with the following content:

```julia
# Structure of the asset
struct MyAsset1 <: AbstractAsset
    id::AssetId
    myasset1_transform::Transformation
    mynewsector_edge::Edge{MyNewSector}
    e_edge::Edge{Electricity}
    co2_edge::Edge{CO2}
end

# Make function to create an instance of the asset
# The function takes as input the data and the system, and returns an instance of the asset
# The data is a dictionary with the asset data, and the system is the system object containing the locations, time data, and other relevant information
function make(::Type{MyAsset1}, data::AbstractDict{Symbol,Any}, system::System)

    # asset id
    id = AssetId(data[:id])

    # transformation
    transform_data = process_data(data[:transforms])
    myasset1_transform_default_constraints = [BalanceConstraint()]
    myasset1_transform = Transformation(;
        id = Symbol(transform_data[:id]),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        constraints = get(transform_data, :constraints, myasset1_transform_default_constraints),
    )

    # edges
    mynewsector_edge_data = process_data(data[:edges][:mynewsector_edge])
    mynewsector_edge_default_constraints = Vector{AbstractTypeConstraint}()
    mynewsector_start_node = find_node(system.locations, Symbol(mynewsector_edge_data[:start_vertex]))
    mynewsector_end_node = myasset1_transform
    mynewsector_edge = Edge(
        Symbol(String(id) * "_" * mynewsector_edge_data[:id]),
        mynewsector_edge_data,
        system.time_data[:MyNewSector],
        MyNewSector,
        mynewsector_start_node,
        mynewsector_end_node,
    )
    mynewsector_edge.constraints = get(mynewsector_edge_data, :constraints, mynewsector_edge_default_constraints)
    mynewsector_edge.unidirectional = get(mynewsector_edge_data, :unidirectional, true)

    elec_edge_data = process_data(data[:edges][:e_edge])
    elec_start_node = myasset1_transform
    elec_end_node = find_node(system.locations, Symbol(elec_edge_data[:end_vertex]))
    elec_edge = EdgeWithUC(
        Symbol(String(id) * "_" * elec_edge_data[:id]),
        elec_edge_data,
        system.time_data[:Electricity],
        Electricity,
        elec_start_node,
        elec_end_node,
    )
    elec_edge.constraints = get(
        elec_edge_data,
        :constraints,
        [
            CapacityConstraint(),
            RampingLimitConstraint(),
            MinUpTimeConstraint(),
            MinDownTimeConstraint(),
        ],
    )
    elec_edge.unidirectional = get(elec_edge_data, :unidirectional, true)
    elec_edge.startup_fuel_balance_id = :energy

    co2_edge_data = process_data(data[:edges][:co2_edge])
    co2_start_node = myasset1_transform
    co2_end_node = find_node(system.locations, Symbol(co2_edge_data[:end_vertex]))
    co2_edge = Edge(
        Symbol(String(id) * "_" * co2_edge_data[:id]),
        co2_edge_data,
        system.time_data[:CO2],
        CO2,
        co2_start_node,
        co2_end_node,
    )
    co2_edge.constraints =
        get(co2_edge_data, :constraints, Vector{AbstractTypeConstraint}())
    co2_edge.unidirectional = get(co2_edge_data, :unidirectional, true)

    myasset1_transform.balance_data = Dict(
        # Edit this part to include the stoichiometric equations for the transformation process 
        ),
    )

    return MyAsset1(id, myasset1_transform, mynewsector_edge, elec_edge, co2_edge)
end
```

From the code above, you can see that the modeler needs to provide the asset structure as a Julia `struct`, along with the default constraints for transformations and edges (`myasset1_transform_default_constraints`, `mynewsector_edge_default_constraints`), and the stoichiometric coefficients for the transformation process being modeled (`myasset1_transform.balance_data`).

!!! tip "Tip"
    Checking out other asset files in the `src/assets` folder is a good place to start adding new assets. 

The creation of the second asset, `MyAsset2`, follows very similar steps to the creation of `MyAsset1`. The main difference is that `MyAsset2` has a storage unit:
    
```julia
struct MyAsset2 <: AbstractAsset
    id::AssetId
    myasset2_storage::AbstractStorage{MyNewSector}  # <--- Storage unit
    discharge_edge::Edge{MyNewSector}
    charge_edge::Edge{MyNewSector}
end

function make(::Type{MyAsset2}, data::AbstractDict{Symbol,Any}, system::System)

    # asset id
    id = AssetId(data[:id])

    # storage
    storage_data = process_data(data[:storage])
    myasset2_storage_default_constraints = [
            BalanceConstraint(),
            StorageCapacityConstraint(),
            StorageMaxDurationConstraint(),
            StorageMinDurationConstraint(),
            StorageSymmetricCapacityConstraint(),
        ]
    myasset2_storage = Storage(id, 
        storage_data, 
        system.time_data[Symbol(storage_data[:commodity])], 
        MyNewSector, 
        myasset2_storage_default_constraints
    )

    # edges
    discharge_edge_data = process_data(data[:edges][:discharge_edge])
    discharge_edge_default_constraints = [CapacityConstraint()]
    discharge_start_node = myasset2_storage
    discharge_end_node = find_node(system.locations, Symbol(discharge_edge_data[:end_vertex]))
    discharge_edge = Edge(
        Symbol(String(id) * "_" * discharge_edge_data[:id]),
        discharge_edge_data,
        system.time_data[:MyNewSector],
        MyNewSector,
        discharge_start_node,
        discharge_end_node,
    )
    discharge_edge.constraints = get(discharge_edge_data, :constraints, discharge_edge_default_constraints)
    discharge_edge.unidirectional = get(discharge_edge_data, :unidirectional, true)

    charge_edge_data = process_data(data[:edges][:charge_edge])
    charge_start_node = find_node(system.locations, Symbol(charge_edge_data[:start_vertex]))
    charge_end_node = myasset2_storage
    charge_edge = Edge(
        Symbol(String(id) * "_" * charge_edge_data[:id]),
        charge_edge_data,
        system.time_data[:MyNewSector],
        MyNewSector,
        charge_start_node,
        charge_end_node,
    )
    charge_edge.constraints = get(charge_edge_data, :constraints, Vector{AbstractTypeConstraint}())
    charge_edge.unidirectional = get(charge_edge_data, :unidirectional, true)

    myasset2_storage.discharge_edge = discharge_edge
    myasset2_storage.charge_edge = charge_edge

    myasset2_storage.balance_data = Dict(
        # Edit this part to include the energy efficiency of the storage unit or any other stoichiometric equations
        ),
    )

    return MyAsset2(id, myasset2_storage, discharge_edge, charge_edge)
end
```
