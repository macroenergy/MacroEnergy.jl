struct NaturalGasPower <: AbstractAsset
    natgaspower_transform::Transformation
    e_tedge::Union{TEdge{Electricity},TEdgeWithUC{Electricity}}
    ng_tedge::TEdge{NaturalGas}
    co2_tedge::TEdge{CO2}
end

function make_natgaspower(data::Dict{Symbol,Any}, time_data::Dict{Symbol,TimeData}, nodes::Dict{Symbol,Node})
    ## conversion process (node)
    _ngcc_transform = Transformation(;
        id=:NaturalGasPower,
        timedata=time_data[:Electricity],
        stoichiometry_balance_names=get(data, :stoichiometry_balance_names, [:energy, :emissions])
    )
    add_constraints!(_ngcc_transform, data)

    ## tedges
    # step 1: get the edge data
    # step 2: set the id
    # step 3: get the correct node
    # step 4: make the edge

    ## electricity edge
    _e_tedge_data = get_tedge_data(data, :Electricity)
    isnothing(_e_tedge_data) && error("No electricity edge data found for NaturalGasPower")
    _e_tedge_data[:id] = :E
    _e_node_id = Symbol(data[:nodes][:Electricity])
    _e_node = nodes[_e_node_id]
    _e_tedge = make_tedge(_e_tedge_data, time_data, _ngcc_transform, _e_node)

    ## natural gas edge
    _ng_tedge_data = get_tedge_data(data, :NaturalGas)
    isnothing(_ng_tedge_data) && error("No natural gas edge data found for NaturalGasPower")
    _ng_tedge_data[:id] = :NG
    _ng_node_id = Symbol(data[:nodes][:NaturalGas])
    _ng_node = nodes[_ng_node_id]
    _ng_tedge = make_tedge(_ng_tedge_data, time_data, _ngcc_transform, _ng_node)

    ## co2 edge
    _co2_tedge_data = get_tedge_data(data, :CO2)
    isnothing(_co2_tedge_data) && error("No CO2 edge data found for NaturalGasPower")
    _co2_tedge_data[:id] = :CO2
    _co2_node_id = Symbol(data[:nodes][:CO2])
    _co2_node = nodes[_co2_node_id]
    _co2_tedge = make_tedge(_co2_tedge_data, time_data, _ngcc_transform, _co2_node)

    return NaturalGasPower(_ngcc_transform, _e_tedge, _ng_tedge, _co2_tedge)
end

function add_capacity_factor!(ng::NaturalGasPower, capacity_factor::Vector{Float64})
    ng.e_tedge.capacity_factor = capacity_factor
end