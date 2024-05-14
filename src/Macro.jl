module Macro

using YAML
using CSV
using DataFrames
using JuMP

# Type parameter for Macro data structures
abstract type Commodity end

abstract type Electricity <: Commodity end
abstract type Hydrogen <: Commodity end
abstract type NaturalGas <: Commodity end
abstract type CO2 <: Commodity end
abstract type Water <: Commodity end
abstract type CO2Captured <: CO2 end

abstract type AbstractTimeData{T<:Commodity} end

abstract type AbstractNode{T<:Commodity} end
abstract type AbstractTransformationEdge{T<:Commodity} end
abstract type AbstractTransformationEdgeWithUC{T} <: AbstractTransformationEdge{T} end

abstract type AbstractEdge{T<:Commodity} end

abstract type AbstractTypeConstraint end
abstract type OperationConstraint <: AbstractTypeConstraint end
abstract type PolicyConstraint <: OperationConstraint end
abstract type PlanningConstraint <: AbstractTypeConstraint end

abstract type TransformationType end

abstract type AbstractTransformation{T<:TransformationType} end

abstract type NaturalGasPower <: TransformationType  end
abstract type NaturalGasPowerCCS <: NaturalGasPower  end
abstract type NaturalGasHydrogen <: TransformationType  end
abstract type NaturalGasHydrogenCCS <: NaturalGasHydrogen  end
abstract type FuelCell <: TransformationType end
abstract type Electrolyzer <: TransformationType  end
abstract type DACElectric <: TransformationType  end
abstract type SyntheticNG <: TransformationType  end
abstract type VRE <: TransformationType end
abstract type Storage <: TransformationType end
abstract type HydroStor <: Storage end 
# type hierarchy

# globals

# const Containers = JuMP.Containers
# const VariableRef = JuMP.VariableRef
const JuMPConstraint = Union{Array,Containers.DenseAxisArray,Containers.SparseAxisArray}
# const DataFrameRow = DataFrames.DataFrameRow;
# const DataFrame = DataFrames.DataFrame;
function include_all_in_folder
    base_path = joinpath(@__DIR__, folder)
    for (root, dirs, files) in Base.Filesystem.walkdir(base_path)
        for file in files
            if endswith(file, ".jl")
                include(joinpath(root, file))
            end
        end
    end
end

namedtuple(d::Dict) = (; (Symbol(k) => v for (k, v) in d)...)

# include files

include("time_management.jl")
include_all_in_folder("model/networks")
include_all_in_folder("model/transformations")
include_all_in_folder("model/constraints")
include("generate_model.jl")
include("benders.jl")
include("input_translation/load_data_from_genx.jl")

# include("config/configure_settings.jl")
# include("load_inputs/load_dataframe.jl")
# include("load_inputs/load_timeseries.jl")
# include("load_inputs/load_inputs.jl")
# include("load_inputs/load_network.jl")
# include("load_inputs/load_transformations.jl")
# include("load_inputs/load_resources.jl")
# include("load_inputs/load_storage.jl")
# include("load_inputs/load_variability.jl")
# include("input_translation/dolphyn_to_macro.jl")
# include("generate_model.jl")
# include("prepare_inputs.jl")

# exports
export Electricity,
    Hydrogen,
    NaturalGas,
    CO2,
    CO2Captured,
    NaturalGasPower,
    NaturalGasPowerCCS,
    NaturalGasHydrogen,
    NaturalGasHydrogenCCS,
    FuelCell,
    Electrolyzer,
    DACElectric,
    SyntheticNG,
    VRE,
    Storage,
    HydroStor,
    Node,
    Edge,
    Transformation,
    TEdge,
    TEdgeWithUC,
    namedtuple
end # module Macro
