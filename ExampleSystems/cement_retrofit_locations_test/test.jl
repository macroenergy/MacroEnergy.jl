using Pkg
Pkg.activate(dirname(dirname(@__DIR__)))
using MacroEnergy
using Gurobi
using DataFrames
using MacroEnergy
using Gurobi

system = MacroEnergy.load_system(@__DIR__)

edges = MacroEnergy.get_edges(system)

function get_can_retofit_edges(edges, retrofit_id)
    can_retrofit_edges = []
    for edge in edges
        if (edge.can_retrofit == true) && (edge.retrofit_id == retrofit_id)
            push!(can_retrofit_edges, edge)
        end
    end
    return can_retrofit_edges
end

function get_is_retofit_edges(edges, retrofit_id)
    is_retrofit_edges = []
    for edge in edges
        if (edge.is_retrofit == true) && (edge.retrofit_id == retrofit_id)
            push!(is_retrofit_edges, edge)
        end
    end
    return is_retrofit_edges
end