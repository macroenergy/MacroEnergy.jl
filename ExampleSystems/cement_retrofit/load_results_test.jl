using Pkg
using Revise
Pkg.activate(dirname(dirname(@__DIR__)))
using Macro
using Gurobi
using Plots
using DataFrames, CSV
using BenchmarkTools
using JLD2, DataFrames, FileIO
using JuMP

cd("/home/al3792/Macro/ExampleSystems/three_zones_macro_genx_cement")

data = load("dataframes.jld2")

data["results_8760_df"]