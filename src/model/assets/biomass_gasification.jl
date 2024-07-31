struct BiomassToH2 <: AbstractAsset
    biomassh2_transform::Transformation
    h2_tedge::TEdge{Hydrogen}
    biomass_tedge::TEdge{Biomass}
    co2_tedge::TEdge{CO2}
end

struct BiomassToPower <: AbstractAsset
    biomass_power_transform::Transformation
    elec_tedge::TEdge{Electricity}
    biomass_tedge::TEdge{Biomass}
    co2_tedge::TEdge{CO2}
end

function make_biomassH2(data::Dict{Symbol,Any}, time_data::Dict{Symbol,TimeData}, nodes::Dict{Symbol,Node})
    ## conversion process (node)
    _biomassh2_transform = Transformation(;
        id=:BiomassToH2,
        timedata=time_data[:Biomass],
        stoichiometry_balance_names=get(data, :stoichiometry_balance_names, [:h2production, :carbon_removal])
    )
    add_constraints!(_biomassh2_transform, data)

    ## tedges
    # step 1: get the edge data
    # step 2: set the id
    # step 3: get the correct node
    # step 4: make the edge

    ## biomass edge
    _biomass_tedge_data = get_tedge_data(data, :Biomass)
    isnothing(_biomass_tedge_data) && error("No biomass edge data found for BiomassToH2")
    _biomass_tedge_data[:id] = :B
    _b_node_id = Symbol(data[:nodes][:Biomass])
    _b_node = nodes[_b_node_id]
    _biomass_tedge = make_tedge(_biomass_tedge_data, time_data, _biomassh2_transform, _b_node)

    ## hydrogen edge
    _h2_tedge_data = get_tedge_data(data, :Hydrogen)
    isnothing(_h2_tedge_data) && error("No hydrogen edge data found for BiomassToH2")
    _h2_tedge_data[:id] = :H2
    _h2_node_id = Symbol(data[:nodes][:Hydrogen])
    _h2_node = nodes[_h2_node_id]
    _h2_tedge = make_tedge(_h2_tedge_data, time_data, _biomassh2_transform, _h2_node)

    ## co2 edge
    _co2_tedge_data = get_tedge_data(data, :CO2)
    isnothing(_co2_tedge_data) && error("No CO2 edge data found for BiomassToH2")
    _co2_tedge_data[:id] = :CO2
    _co2_node_id = Symbol(data[:nodes][:CO2])
    _co2_node = nodes[_co2_node_id]
    _co2_tedge = make_tedge(_co2_tedge_data, time_data, _biomassh2_transform, _co2_node)

    ## add reference to tedges in transformation
    _TEdges = Dict(:H2=>_h2_tedge, :B=>_biomass_tedge, :CO2=>_co2_tedge)
    _biomassh2_transform.TEdges = _TEdges

    return BiomassToH2(_biomassh2_transform, _h2_tedge, _biomass_tedge, _co2_tedge)
end

function add_capacity_factor!(g::BiomassToH2, capacity_factor::Vector{Float64})
    g.biomass_tedge.capacity_factor = capacity_factor
end


function make_biomass_power(data::Dict{Symbol,Any}, time_data::Dict{Symbol,TimeData}, nodes::Dict{Symbol,Node})
    ## conversion process (node)
    _biomass_power_transform = Transformation(;
        id=:BiomassToPower,
        timedata=time_data[:Biomass],
        stoichiometry_balance_names=get(data, :stoichiometry_balance_names, [:elec_production, :carbon_removal])
    )
    add_constraints!(_biomass_power_transform, data)

    ## tedges
    # step 1: get the edge data
    # step 2: set the id
    # step 3: get the correct node
    # step 4: make the edge

    ## biomass edge
    _biomass_tedge_data = get_tedge_data(data, :Biomass)
    isnothing(_biomass_tedge_data) && error("No biomass edge data found for BiomassToPower")
    _biomass_tedge_data[:id] = :B
    _b_node_id = Symbol(data[:nodes][:Biomass])
    _b_node = nodes[_b_node_id]
    _biomass_tedge = make_tedge(_biomass_tedge_data, time_data, _biomass_power_transform, _b_node)

    ## Electricity edge
    _elec_tedge_data = get_tedge_data(data, :Electricity)
    isnothing(_elec_tedge_data) && error("No Electricity edge data found for BiomassToPower")
    _elec_tedge_data[:id] = :E
    _elec_node_id = Symbol(data[:nodes][:Electricity])
    _elec_node = nodes[_elec_node_id]
    _elec_tedge = make_tedge(_elec_tedge_data, time_data, _biomass_power_transform, _elec_node)

    ## co2 edge
    _co2_tedge_data = get_tedge_data(data, :CO2)
    isnothing(_co2_tedge_data) && error("No CO2 edge data found for BiomassToPower")
    _co2_tedge_data[:id] = :CO2
    _co2_node_id = Symbol(data[:nodes][:CO2])
    _co2_node = nodes[_co2_node_id]
    _co2_tedge = make_tedge(_co2_tedge_data, time_data, _biomass_power_transform, _co2_node)

    ## add reference to tedges in transformation
    _TEdges = Dict(:E=>_elec_tedge, :B=>_biomass_tedge, :CO2=>_co2_tedge)
    _biomass_power_transform.TEdges = _TEdges

    return BiomassToPower(_biomass_power_transform, _elec_tedge, _biomass_tedge, _co2_tedge)
end

function add_capacity_factor!(g::BiomassToPower, capacity_factor::Vector{Float64})
    g.biomass_tedge.capacity_factor = capacity_factor
end