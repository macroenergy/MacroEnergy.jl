Base.@kwdef mutable struct Location <: MacroObject
    name::String
    nodes::Dict{Symbol, Node} = Dict{Symbol, Node}()
    commodities::Set{Symbol} = Set{Symbol}()
    # We could change this to work on commodities, not symbols
    # My feeling is that symbols will be lighter and faster
end

function add_node!(loc::Location, node::Node{T}, replace::Bool=false) where T<:Commodity
    node_commodity = Symbol(commodity_type(node))
    # If a node of the same type exists then throw an error unless replace is true
    if ((node_commodity in loc.commodities) || (node_commodity in keys(loc.nodes))) && !replace
        error("A $node_commodity node already exists in the $(loc.name) location")
    end
    loc.nodes[node_commodity] = node
    push!(loc.commodities, node_commodity)
end

function refresh_commodities_list!(loc::Location)
    loc.commodities = Set{Symbol}(
        Symbol(commodity_type(node)) for node in values(loc.nodes)
    )
end