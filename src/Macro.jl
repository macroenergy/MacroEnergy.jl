module Macro

using YAML
using CSV
using DataFrames
using JuMP
using Revise
using JSON3

# Type parameter for Macro data structures

## Commodity types
abstract type Commodity end
abstract type Electricity <: Commodity end
abstract type Hydrogen <: Commodity end
abstract type Biomass <: Commodity end
abstract type NaturalGas <: Commodity end
abstract type CO2 <: Commodity end
abstract type CO2Captured <: CO2 end

## Time data types
abstract type AbstractTimeData{T<:Commodity} end

## Network types
abstract type AbstractNode{T<:Commodity} end
abstract type AbstractEdge{T<:Commodity} end
abstract type AbstractTransformationEdge{T<:Commodity} end
abstract type AbstractTransformationEdgeWithUC{T} <: AbstractTransformationEdge{T} end

## Transformation types
abstract type AbstractTransform end
abstract type TransformationType end  # Note: this is only used to improved readability
abstract type GasificationH2Transform<: TransformationType end
abstract type NaturalGasPowerTransform <: TransformationType  end
abstract type NaturalGasPowerCCSTransform <: NaturalGasPowerTransform  end
abstract type NaturalGasH2Transform <: TransformationType  end
abstract type NaturalGasH2CCSTransform <: NaturalGasH2Transform  end
abstract type FuelCellTransform <: TransformationType end
abstract type ElectrolyzerTransform <: TransformationType  end
abstract type DacElectricTransform <: TransformationType  end
abstract type SyntheticNGTransform <: TransformationType  end
abstract type Storage <: TransformationType end

## Assets types
abstract type AbstractAsset end

## Constraints types
abstract type AbstractTypeConstraint end
abstract type OperationConstraint <: AbstractTypeConstraint end
abstract type PolicyConstraint <: OperationConstraint end
abstract type PlanningConstraint <: AbstractTypeConstraint end

# global constants
const H2_MWh = 33.33 # MWh per tonne of H2
const NG_MWh = 0.29307107 # MWh per MMBTU of NG 

# const Containers = JuMP.Containers
# const VariableRef = JuMP.VariableRef
const JuMPConstraint = Union{Array,Containers.DenseAxisArray,Containers.SparseAxisArray}

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

# include files

include("time_management.jl")
include_all_in_folder("model/networks")
include_all_in_folder("model/transformations")
include_all_in_folder("model/assets")
include_all_in_folder("model/constraints")
include("model/system.jl")

include("generate_model.jl")
include("benders.jl")
include("input_translation/load_data_from_genx.jl")

include("config/configure_settings.jl")
include("load_inputs/load_dataframe.jl")
include("load_inputs/load_timeseries.jl")
include("load_inputs/load_inputs.jl")
include("load_inputs/load_commodities.jl")
include("load_inputs/load_time_data.jl")
include("load_inputs/load_network.jl")
include("load_inputs/load_assets.jl")
include("load_inputs/load_demand.jl")
include("load_inputs/load_fuel.jl")
include("load_inputs/load_capacity_factor.jl")
# include("load_inputs/load_resources.jl")
# include("load_inputs/load_storage.jl")
# include("load_inputs/load_variability.jl")
include("input_translation/dolphyn_to_macro.jl")
# include("generate_model.jl")
# include("prepare_inputs.jl")
# include("transformations/ElectrolyzerTransform.jl")
# include("transformations/natgaspower.jl")
include_all_in_folder("write_outputs/")
# exports
export Electricity,
    Hydrogen,
    NaturalGas,
    CO2,
    CO2Captured,
    Biomass,
    GasificationH2,
    NaturalGasPower,
    Electrolyzer,
    FuelCell,
    NaturalGasH2,
    H2Storage,
    NaturalGasPowerCCS,
    NaturalGasH2Transform,
    NaturalGasH2CCSTransform,
    FuelCellTransform,
    ElectrolyzerTransformTransform,
    DacElectricTransform,
    SyntheticNGTransform,
    VRE,
    SolarPVTransform,
    Storage,
    TransformationType,
    #Resource,
    #Sink,
    #AbstractStorage,
    #SymmetricStorage,
    #AsymmetricStorage,
    #InputFilesNames,
    Node,
    Edge,
    Transformation,
    TEdge,
    TEdgeWithUC,
    namedtuple,
    AbstractAsset,
    SolarPV,
    WindTurbine,
    Battery,
    ElectrolyzerTransform,
    #CapacityConstraint,
    #configure_settings,
    #add_planning_variables!,
    #add_operation_variables!,
    #add_model_constraint!,
    #add_all_model_constraints!,
    #generate_model,
    #prepare_inputs!,
    #loadresources,
    #makeresource,
    #settings,
    # nodes,
    # networks,
    #resources,
    #storage,
    #dolphyn_to_macro,
    #apply_unit_conversion,
    MaxNonServedDemandPerSegmentConstraint,
    MaxNonServedDemandConstraint,
    PlanningConstraint,
    MinDownTimeConstraint,
    StoichiometryBalanceConstraint,
    CO2CapConstraint,
    PolicyConstraint,
    DemandBalanceConstraint,
    OperationConstraint,
    RampingLimitConstraint,
    StorageCapacityConstraint,
    MinUpTimeConstraint,
    SymmetricCapacityConstraint,
    CapacityConstraint,
    MinFlowConstraint,
    configure_settings,
    load_inputs

end # module Macro

# using Macro 
# q = Macro.get_transformation_types(Macro)
