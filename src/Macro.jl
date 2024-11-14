module Macro

using CSV, JSON3, GZip
using DuckDB
using DataFrames
using JuMP
using Revise
using InteractiveUtils
using Printf: @printf

import Base: /

# Type parameter for Macro data structures

## Commodity types
abstract type Commodity end
abstract type Electricity <: Commodity end ## MWh
abstract type Hydrogen <: Commodity end ## MWh
abstract type NaturalGas <: Commodity end ## MWh
abstract type CO2 <: Commodity end ## tonnes
abstract type CO2Captured <: CO2 end ## tonnes
abstract type Coal <: Commodity end ## MWh
abstract type Biomass <: Commodity end ## tonnes
abstract type Uranium <: Commodity end ## MWh

## Time data types
abstract type AbstractTimeData{T<:Commodity} end

## Structure types
abstract type MacroObject end
abstract type AbstractVertex <: MacroObject end

## Network types
abstract type AbstractEdge{T<:Commodity} <: MacroObject end

## Assets types
abstract type AbstractAsset <: MacroObject end
abstract type AbstractStorage{T<:Commodity} <: AbstractVertex end
## Constraints types
abstract type AbstractTypeConstraint end
abstract type OperationConstraint <: AbstractTypeConstraint end
abstract type PolicyConstraint <: OperationConstraint end
abstract type PlanningConstraint <: AbstractTypeConstraint end

# global constants
const H2_MWh = 33.33 # MWh per tonne of H2
const NG_MWh = 0.29307107 # MWh per MMBTU of NG 
const AssetId = Symbol
const JuMPConstraint =
    Union{Array,Containers.DenseAxisArray,Containers.SparseAxisArray,ConstraintRef}
const JuMPVariable =
    Union{Array,Containers.DenseAxisArray,Containers.SparseAxisArray,VariableRef}

function include_all_in_folder(folder::AbstractString, root_path::AbstractString=@__DIR__)
    base_path = joinpath(root_path, folder)
    for (root, dirs, files) in Base.Filesystem.walkdir(base_path)
        for file in files
            if endswith(file, ".jl")
                include(joinpath(root, file))
            end
        end
    end
    return nothing
end

include_all_in_folder("utilities")

# include files
include("model/time_management.jl")
include("model/networks/vertex.jl")
include("model/networks/node.jl")
include("model/networks/storage.jl")
include("model/networks/transformation.jl")
include("model/networks/location.jl")
include("model/networks/edge.jl")
include("model/networks/asset.jl")

include("model/system.jl")

include("model/assets/battery.jl")
include("model/assets/electrolyzer.jl")
include("model/assets/fuelcell.jl")
include("model/assets/gasstorage.jl")
include("model/assets/thermalhydrogen.jl")
include("model/assets/thermalpower.jl")
include("model/assets/powerline.jl")
include("model/assets/vre.jl")

include("model/assets/hydrogenline.jl")
include("model/assets/thermalhydrogenccs.jl")
include("model/assets/thermalpowerccs.jl")

include("model/assets/natgasdac.jl")
include("model/assets/electricdac.jl")
include("model/assets/beccselectricity.jl")
include("model/assets/beccshydrogen.jl")
include("model/assets/hydrores.jl")
include("model/assets/mustrun.jl")


include_all_in_folder("model/constraints")

include("config/configure_settings.jl")

include_all_in_folder("load_inputs")

include("generate_model.jl")

include("benders_utilities.jl")

include("model/scaling.jl")

include("write_outputs/assets_capacity.jl")
include("write_outputs/utilities.jl")
include("write_outputs/write_system_data.jl")

export AbstractAsset,
    AbstractTypeConstraint,
    BalanceConstraint,
    Battery,
    Biomass,
    Coal,
    BECCSElectricity,
    BECCSHydrogen,
    CO2,
    CO2CapConstraint,
    CO2Captured,
    CapacityConstraint,
    Commodity,
    Edge,
    EdgeWithUC,
    Electricity,
    Electrolyzer,
    ElectricDAC,
    FuelCell,
    GasStorage,
    HydroRes,
    Hydrogen,
    HydrogenLine,
    HydroMinFlowConstraint,
    LongDurationStorage,
    MaxCapacityConstraint,
    MaxNonServedDemandConstraint,
    MaxNonServedDemandPerSegmentConstraint,
    MaxStorageLevelConstraint,
    MinCapacityConstraint,
    MinDownTimeConstraint,
    MinFlowConstraint,
    MinStorageLevelConstraint,
    MinUpTimeConstraint,
    MustRun,
    MustRunConstraint,
    NaturalGas,
    NaturalGasDAC,
    Node,
    OperationConstraint,
    PlanningConstraint,
    PolicyConstraint,
    PowerLine,
    RampingLimitConstraint,
    SameChargeDischargeCapacityConstraint,
    Storage,
    StorageCapacityConstraint,
    StorageMaxDurationConstraint,
    StorageMinDurationConstraint,
    StorageSymmetricCapacityConstraint,
    StorageDischargeLimitConstraint,
    ThermalHydrogen,
    ThermalPower,
    ThermalHydrogenCCS,
    ThermalPowerCCS,
    Transformation,
    Uranium,
    VRE
end # module Macro
