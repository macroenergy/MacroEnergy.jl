using Pkg
Pkg.activate(dirname(dirname(@__DIR__)))
using MacroEnergy
using Gurobi
using DataFrames

path = @__DIR__
system = MacroEnergy.load_system(path)

edges = MacroEnergy.get_edges(system)
edges_with_ids = MacroEnergy.get_edges(system, return_ids_map=true)

