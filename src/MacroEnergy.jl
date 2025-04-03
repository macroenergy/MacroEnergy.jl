module MacroEnergy

using CSV, JSON3, GZip, Parquet2
using Dates
using DuckDB
using DataFrames
using OrderedCollections
using JuMP
using HiGHS
using Revise
using InteractiveUtils
using Printf: @printf
using MacroEnergyScaling
import MacroEnergyScaling: scale_constraints!
import JuMP: set_optimizer, set_optimizer_attributes

import Base: /, push!, merge!

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
abstract type LiquidFuels <: Commodity end ## MWh

## Time data types
abstract type AbstractTimeData{T<:Commodity} end

##
abstract type AbstractSystem end

## Structure types
abstract type MacroObject end
abstract type AbstractVertex <: MacroObject end
abstract type AbstractStorage{T<:Commodity} <: AbstractVertex end

## Network types
abstract type AbstractEdge{T<:Commodity} <: MacroObject end

## Assets types
abstract type AbstractAsset <: MacroObject end

## Constraints types
abstract type AbstractTypeConstraint end
abstract type OperationConstraint <: AbstractTypeConstraint end
abstract type PolicyConstraint <: OperationConstraint end
abstract type PlanningConstraint <: AbstractTypeConstraint end

# Solution algorithms
abstract type AbstractSolutionAlgorithm end
struct Myopic <: AbstractSolutionAlgorithm end
struct PerfectForesight <: AbstractSolutionAlgorithm end
struct SingleStage <: AbstractSolutionAlgorithm end
struct Benders <: AbstractSolutionAlgorithm end
algorithm_type(::AbstractSolutionAlgorithm) = SingleStage() # default to single stage
algorithm_type(::SingleStage) = SingleStage()
algorithm_type(::Myopic) = Myopic()
algorithm_type(::PerfectForesight) = PerfectForesight()
algorithm_type(::Benders) = Myopic()

# global constants
const ME_DEPOT_PATH = joinpath(homedir(), ".macroenergy")
const H2_MWh = 33.33 # MWh per tonne of H2
const NG_MWh = 0.29307107 # MWh per MMBTU of NG 
const AssetId = Symbol
const JuMPConstraint =
    Union{Array,Containers.DenseAxisArray,Containers.SparseAxisArray,ConstraintRef}
const JuMPVariable =
    Union{Array,Containers.DenseAxisArray,Containers.SparseAxisArray,VariableRef}

# Load subcommodities from file when MacroEnergy is loaded
function __init__()
    isdir(ME_DEPOT_PATH) && load_subcommodities_from_file(ME_DEPOT_PATH)
end

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


# include files
include("utilities/default_data.jl")
include("utilities/utilities.jl")

include("model/units.jl")
include("model/time_management.jl")
include("model/networks/vertex.jl")
include("model/networks/node.jl")
include("model/networks/storage.jl")
include("model/networks/transformation.jl")
include("model/networks/location.jl")
include("model/networks/edge.jl")
include("model/networks/asset.jl")
include("model/system.jl")
include("model/stages.jl")
include("model/networks/macroobject.jl")

include("model/assets/battery.jl")
include("model/assets/electrolyzer.jl")
include("model/assets/fuelcell.jl")
include("model/assets/gasstorage.jl")
include("model/assets/thermalhydrogen.jl")
include("model/assets/thermalpower.jl")
include("model/assets/powerline.jl")
include("model/assets/vre.jl")

include("model/assets/thermalhydrogenccs.jl")
include("model/assets/thermalpowerccs.jl")

include("model/assets/natgasdac.jl")
include("model/assets/electricdac.jl")
include("model/assets/beccselectricity.jl")
include("model/assets/beccshydrogen.jl")
include("model/assets/beccsgasoline.jl")
include("model/assets/beccsliquidfuels.jl")
include("model/assets/beccsnaturalgas.jl")
include("model/assets/hydrores.jl")
include("model/assets/mustrun.jl")

include("model/assets/fossilfuelsupstream.jl")
include("model/assets/fuelsenduse.jl")

include("model/assets/syntheticnaturalgas.jl")
include("model/assets/syntheticliquidfuels.jl")

include("model/assets/co2injection.jl")

include_all_in_folder("model/constraints")

include("config/configure_settings.jl")
include("config/stage_settings.jl")
include_all_in_folder("load_inputs")

include("model/generate_model.jl")
include("model/multistage.jl")
include("model/optimizer.jl")
include("model/scaling.jl")
include("model/solver.jl")

include("utilities/benchmarking.jl")
include("utilities/benders.jl")
include("utilities/comparisons.jl")
include("utilities/run_tools.jl")

include("write_outputs/capacity.jl")
include("write_outputs/flow.jl")
include("write_outputs/write_output_utilities.jl")
include("write_outputs/costs.jl")
include("write_outputs/write_system_data.jl")

export AbstractAsset,
    AbstractTypeConstraint,
    AgeBasedRetirementConstraint,
    BalanceConstraint,
    Battery,
    Biomass,
    Coal,
    BECCSElectricity,
    BECCSHydrogen,
    BECCSGasoline,
    BECCSLiquidFuels,
    BECCSNaturalGas,
    CO2,
    CO2CapConstraint,
    CO2Captured,
    CO2Injection,
    CO2StorageConstraint,
    CapacityConstraint,
    collect_results,
    Commodity,
    Edge,
    EdgeWithUC,
    Electricity,
    Electrolyzer,
    ElectricDAC,
    FossilFuelsUpstream,
    FuelCell,
    FuelsEndUse,
    GasStorage,
    get_optimal_capacity, 
    get_optimal_costs,
    get_optimal_flow,
    get_optimal_new_capacity,
    get_optimal_retired_capacity,
    HydroRes,
    Hydrogen,
    LongDurationStorage,
    LongDurationStorageImplicitMinMaxConstraint,
    LiquidFuels,
    load_subcommodities_from_file,
    MaxCapacityConstraint,
    MaxNewCapacityConstraint,
    MaxNonServedDemandConstraint,
    MaxNonServedDemandPerSegmentConstraint,
    MaxStorageLevelConstraint,
    MinCapacityConstraint,
    MinDownTimeConstraint,
    MinFlowConstraint,
    MinStorageOutflowConstraint,
    MinStorageLevelConstraint,
    MinUpTimeConstraint,
    MustRun,
    MustRunConstraint,
    NaturalGas,
    NaturalGasDAC,
    NaturalGasFossilUpstream,
    Node,
    OperationConstraint,
    PlanningConstraint,
    PolicyConstraint,
    PowerLine,
    RampingLimitConstraint,
    run_case,
    run_multistage_case,
    Storage,
    StorageCapacityConstraint,
    StorageChargeDischargeRatioConstraint,
    StorageMaxDurationConstraint,
    StorageMinDurationConstraint,
    StorageSymmetricCapacityConstraint,
    StorageDischargeLimitConstraint,
    SyntheticNaturalGas,
    SyntheticLiquidFuels,
    ThermalHydrogen,
    ThermalPower,
    ThermalHydrogenCCS,
    ThermalPowerCCS,
    Transformation,
    Uranium,
    VRE,
    write_capacity,
    write_costs,
    write_dataframe,
    write_flow,
    write_results
    
end # module MacroEnergy
