# Modeler Guide

## How to build new sectors in Macro

### Overview
The steps to build a sector in Macro are as follows:

1. Create new sectors/commodity types by defining new subtypes of `Commodity` in the `MacroEnergy.jl` file.

2. Create new assets. Each asset type should be a subtype of `AbstractAsset` and be defined in a Julia (`.jl`) file located in the `src/assets` folder. A `make` function should be defined for each asset type to create an instance of the asset.

!!! note "Note"
    Remember to include the new files in the `MacroEnergy.jl` file, so that they are available when the package is loaded.

During the creation of the assets, you will need to provide (check the following sections for an example):
1. **Asset structure**: list of fields that define the asset in the form of transformations, edges, and storage units.
2. **Default constraints** for the transformations, edges, and storage units.
3. **Stoichiometric equations/coefficients** for the transformation processes.

```@raw html
<ol start="4">
    <li>(Optional) Create a new JSON data file to test the new assets.</li>
</ol>
```
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
struct MyAsset1 <: AbstractAsset
    id::AssetId
    myasset1_transform::Transformation
    mynewsector_edge::Edge{MyNewSector}
    e_edge::Edge{Electricity}
    co2_edge::Edge{CO2}
end

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
        # Edit this part to include the energy efficiency of the storage unit or any other stoiometric equations
        ),
    )

    return MyAsset2(id, myasset2_storage, discharge_edge, charge_edge)
end
```
