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
abstract type Electricity <: Commodity end
abstract type Hydrogen <: Commodity end
abstract type NaturalGas <: Commodity end
abstract type CO2 <: Commodity end
abstract type CO2Captured <: CO2 end

## Time data types
abstract type AbstractTimeData{T<:Commodity} end

## Structure types
abstract type MacroObject end
abstract type AbstractVertex <: MacroObject end

## Network types
abstract type AbstractEdge{T<:Commodity} <: MacroObject end

## Assets types
abstract type AbstractAsset <: MacroObject end

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
include("model/assets/h2storage.jl")
include("model/assets/natgashydrogen.jl")
include("model/assets/natgaspower.jl")
include("model/assets/powerline.jl")
include("model/assets/vre.jl")

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
    CO2,
    CO2CapConstraint,
    CO2Captured,
    CapacityConstraint,
    Commodity,
    Edge,
    EdgeWithUC,
    Electricity,
    Electrolyzer,
    FuelCell,
    H2Storage,
    Hydrogen,
    MaxCapacityConstraint,
    MaxNonServedDemandConstraint,
    MaxNonServedDemandPerSegmentConstraint,
    MaxStorageLevelConstraint,
    MinCapacityConstraint,
    MinDownTimeConstraint,
    MinFlowConstraint,
    MinStorageLevelConstraint,
    MinUpTimeConstraint,
    NaturalGas,
    NaturalGasHydrogen,
    NaturalGasPower,
    Node,
    OperationConstraint,
    PlanningConstraint,
    PolicyConstraint,
    PowerLine,
    RampingLimitConstraint,
    SolarPV,
    Storage,
    StorageCapacityConstraint,
    StorageMaxDurationConstraint,
    StorageMinDurationConstraint,
    StorageSymmetricCapacityConstraint,
    StorageDischargeLimitConstraint,
    Transformation,
    VRE,
    WindTurbine
end # module Macro
