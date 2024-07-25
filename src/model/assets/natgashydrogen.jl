struct NaturalGasH2 <: AbstractAsset
    natgash2_transform::Transformation
    h2_tedge::Union{TEdge{Hydrogen},TEdgeWithUC{Hydrogen}}
    ng_tedge::TEdge{NaturalGas}
    co2_tedge::TEdge{CO2}
end

function make_natgash2(data::Dict{Symbol,Any}, time_data::Dict{Symbol,TimeData}, nodes::Dict{Symbol,Node})
    ## conversion process (node)
    _smr_transform = Transformation(;
        id=:NaturalGasH2,
        timedata=time_data[:Hydrogen],
        stoichiometry_balance_names=get(data, :stoichiometry_balance_names, [:energy, :emissions])
    )
    add_constraints!(_smr_transform, data)

    ## tedges
    # step 1: get the edge data
    # step 2: set the id
    # step 3: get the correct node
    # step 4: make the edge

    ## electricity edge
    _h2_tedge_data = get_tedge_data(data, :Hydrogen)
    isnothing(_h2_tedge_data) && error("No hydrogen edge data found for NaturalGasH2")
    _h2_tedge_data[:id] = :H2
    _e_node_id = Symbol(data[:nodes][:Hydrogen])
    _e_node = nodes[_e_node_id]
    _h2_tedge = make_tedge(_h2_tedge_data, time_data, _smr_transform, _e_node)

    ## natural gas edge
    _ng_tedge_data = get_tedge_data(data, :NaturalGas)
    isnothing(_ng_tedge_data) && error("No natural gas edge data found for NaturalGasH2")
    _ng_tedge_data[:id] = :NG
    _ng_node_id = Symbol(data[:nodes][:NaturalGas])
    _ng_node = nodes[_ng_node_id]
    _ng_tedge = make_tedge(_ng_tedge_data, time_data, _smr_transform, _ng_node)

    ## co2 edge
    _co2_tedge_data = get_tedge_data(data, :CO2)
    isnothing(_co2_tedge_data) && error("No CO2 edge data found for NaturalGasH2")
    _co2_tedge_data[:id] = :CO2
    _co2_node_id = Symbol(data[:nodes][:CO2])
    _co2_node = nodes[_co2_node_id]
    _co2_tedge = make_tedge(_co2_tedge_data, time_data, _smr_transform, _co2_node)

    ## add reference to tedges in transformation
    _TEdges = Dict(:H2=>_h2_tedge, :NG=>_ng_tedge, :CO2=>_co2_tedge)
    _smr_transform.TEdges = _TEdges

    return NaturalGasH2(_smr_transform, _h2_tedge, _ng_tedge, _co2_tedge)
end

function add_capacity_factor!(ng::NaturalGasH2, capacity_factor::Vector{Float64})
    ng.h2_tedge.capacity_factor = capacity_factor
end