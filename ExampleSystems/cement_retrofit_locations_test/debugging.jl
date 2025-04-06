using Pkg
Pkg.activate(dirname(dirname(@__DIR__)))
using Revise
using MacroEnergy
using Gurobi
using DataFrames

path = @__DIR__
system = MacroEnergy.empty_system(dirname(path))
system_data = MacroEnergy.load_system_data(joinpath(path, "system_data.json"))

data = MacroEnergy.load_json_inputs(joinpath(path, "assets/electrochemcementplant.json"))

MacroEnergy.load!(system, data)

MacroEnergy.load!(system, joinpath(path, "assets/electrochemcementplant.json"))