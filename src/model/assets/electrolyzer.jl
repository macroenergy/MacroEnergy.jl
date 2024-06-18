struct Electrolyzer <: AbstractAsset
    electrolyzer_transform::Transformation
    h2_tedge::TEdge{Hydrogen}
    elec_tedge::TEdge{Electricity}
end

function make_electrolyzer(data::Dict{Symbol,Any}, time_data::Dict{Symbol,TimeData}, nodes::Dict{Symbol,Node})
    ## conversion process (node)
    _electrolyzer_transform = Transformation(;
        id=:Electrolyzer,
        timedata=time_data[:Hydrogen],
        stoichiometry_balance_names=get(data, :stoichiometry_balance_names, [:energy])
    )
    add_constraints!(_electrolyzer_transform, data)

    ## hydrogen edge
    _h2_tedge_data = get_tedge_data(data, :Hydrogen)
    isnothing(_h2_tedge_data) && error("No hydrogen edge data found for Electrolyzer")
    _h2_tedge_data[:id] = :H2
    _h2_node_id = Symbol(data[:nodes][:Hydrogen])
    _h2_node = nodes[_h2_node_id]
    _h2_tedge = make_tedge(_h2_tedge_data, time_data, _electrolyzer_transform, _h2_node)

    ## electricity edge
    _elec_tedge_data = get_tedge_data(data, :Electricity)
    isnothing(_elec_tedge_data) && error("No electricity edge data found for Electrolyzer")
    _elec_tedge_data[:id] = :E
    _elec_node_id = Symbol(data[:nodes][:Electricity])
    _elec_node = nodes[_elec_node_id]
    _elec_tedge = make_tedge(_elec_tedge_data, time_data, _electrolyzer_transform, _elec_node)

    return Electrolyzer(_electrolyzer_transform, _h2_tedge, _elec_tedge)
end
