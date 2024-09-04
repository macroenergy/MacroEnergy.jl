module Macro

using YAML
using CSV
using DataFrames
using JuMP
using Distributed
using DistributedArrays
using Revise
using JSON3
using InteractiveUtils


# Type parameter for Macro data structures

## Commodity types
abstract type Commodity end
abstract type Electricity <: Commodity end
abstract type Hydrogen <: Commodity end
abstract type NaturalGas <: Commodity end
abstract type CO2 <: Commodity end
abstract type Captured_CO2 <: Commodity end

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
const JuMPConstraint = Union{Array,Containers.DenseAxisArray,Containers.SparseAxisArray,ConstraintRef}

function include_all_in_folder(folder)
    base_path = joinpath(@__DIR__, folder)
    for (root, dirs, files) in Base.Filesystem.walkdir(base_path)
        for file in files
            if endswith(file, ".jl")
                include(joinpath(root, file))
            end
        end
    end
end

function all_subtypes(m::Module, type::Symbol)::Dict{Symbol,DataType}
    types = Dict{Symbol,DataType}()
    for subtype in subtypes(getfield(m, type))
        all_subtypes!(types, subtype)
    end
    return types
end

function all_subtypes!(types::Dict{Symbol,DataType}, type::DataType)
    types[Symbol(type)] = type
    if !isempty(subtypes(type))
        for subtype in subtypes(type)
            all_subtypes!(types, subtype)
        end
    end
    return nothing
end

function fieldnames(type::T) where T <: Type{<:AbstractAsset}
    return filter(x -> x != :id, Base.fieldnames(type))
end

# include files

include("time_management.jl")

include("model/networks/vertex.jl")
include("model/networks/node.jl")
include("model/networks/storage.jl")
include("model/networks/transformation.jl")
include("model/networks/location.jl")
include("model/networks/edge.jl")
include("model/system.jl")
include("model/assets/battery.jl")
include("model/assets/natgaspower.jl")
include("model/assets/natgaspowerccs.jl")
include("model/assets/vre.jl")
include("model/assets/powerline.jl")
include("model/assets/natgashydrogen.jl")
include("model/assets/natgashydrogenccs.jl")
include("model/assets/electrolyzer.jl")
include("model/assets/electricdac.jl")
include("model/assets/fuelcell.jl")
include("model/assets/h2storage.jl")
include("model/assets/natgasdac.jl")

include_all_in_folder("model/constraints")

include("generate_model.jl")

include("load_inputs/load_tools/loading_json.jl")
include("config/configure_settings.jl")
include("load_inputs/load_tools/load_dataframe.jl")
include("load_inputs/load_tools/load_timeseries.jl")
include("load_inputs/load_commodities.jl")
include("load_inputs/load_time_data.jl")
include("write_outputs/assets_capacity.jl")
include("write_outputs/get_assets.jl")

include("benders/benders_utility.jl")
include("benders/benders_planning_problem.jl")

export Electricity,
    Hydrogen,
    NaturalGas,
    CO2,
    Captured_CO2,
    Battery,
    H2Storage,
    PowerLine,
    NaturalGasPower,
    NaturalGasPowerCCS,      
    NaturalGasHydrogen,
    NaturalGasHydrogenCCS,
    Electrolyzer,
    ElectricDAC,
    FuelCell,
    DirectAirCaptureNG,
    VRE,
    SolarPV,
    WindTurbine,
    Storage,
    Node,
    Edge,
    Transformation,
    EdgeWithUC,
    namedtuple,
    AbstractAsset,
    AbstractTypeConstraint,
    PlanningConstraint,
    OperationConstraint,
    CapacityConstraint,
    CO2CapConstraint,
    StorageMinDurationConstraint,
    StorageMaxDurationConstraint,
    PolicyConstraint,
    BalanceConstraint,
    MaxNonServedDemandPerSegmentConstraint,
    MaxNonServedDemandConstraint,
    RampingLimitConstraint,
    StorageCapacityConstraint,
    StorageSymmetricCapacityConstraint,
    MinUpTimeConstraint,
    MinDownTimeConstraint,
    MaxCapacityConstraint,
    MinFlowConstraint,
    MinStorageLevelConstraint
end # module Macro
