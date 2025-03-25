using Pkg
using Revise
Pkg.activate(dirname(dirname(@__DIR__)))
using MacroEnergy
using Gurobi
using Plots
using DataFrames, CSV
using BenchmarkTools
using JLD2, FileIO
using JuMP

system = MacroEnergy.load_system(@__DIR__)
model = MacroEnergy.generate_model(system)
MacroEnergy.set_optimizer(model, Gurobi.Optimizer);
MacroEnergy.set_optimizer_attributes(model, "BarConvTol"=>1e-3,"Crossover" => 0, "Method" => 2)
MacroEnergy.optimize!(model)

MacroEnergy.compute_conflict!(model)