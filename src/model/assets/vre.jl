struct SolarPV <: AbstractAsset
    energy_transform::Transformation
    tedge::TEdge{Electricity}
end

function make_solarpv(data::Dict{Symbol,Any}, time_data::Dict{Symbol,TimeData}, node_out::Node)
    _energy_transform, _tedge = make_vre(data, time_data, node_out)
    return SolarPV(_energy_transform, _tedge)
end

struct WindTurbine <: AbstractAsset
    energy_transform::Transformation
    tedge::TEdge{Electricity}
end

function make_windturbine(data::Dict{Symbol,Any}, time_data::Dict{Symbol,TimeData}, node_out::Node)
    _energy_transform, _tedge = make_vre(data, time_data, node_out)
    return WindTurbine(_energy_transform, _tedge)
end

const VRE = Union{SolarPV, WindTurbine}

function make_vre(data::Dict{Symbol,Any}, time_data::Dict{Symbol,TimeData}, node_out::Node)
    #============================================================
    This function makes a VRE (SolarPV or WindTurbine) from the 
    data Dict. It is a helper function for load_transformations!.
    ============================================================#

    ## conversion process (node)
    _energy_transform = Transformation(;
        id=:EnergyTransform,
        timedata=time_data[:Electricity],
        # Note that this transformation does not 
        # have a stoichiometry balance because the 
        # sunshine is exogenous
    )
    add_constraints!(_energy_transform, data)

    ## electricity edge
    # get electricity edge data
    _tedge_data = get_tedge_data(data, :Electricity)
    isnothing(_tedge_data) && error("No electricity edge data found for VRE")
    # set the id
    _tedge_data[:id] = :E
    # make the edge
    _tedge = make_tedge(_tedge_data, time_data, _energy_transform, node_out)

    ## add reference to tedges in transformation
    _TEdges = Dict(:E=>_tedge)
    _energy_transform.TEdges = _TEdges

    return _energy_transform, _tedge
end

function add_capacity_factor!(s::VRE, capacity_factor::Vector{Float64})
    s.tedge.capacity_factor = capacity_factor
end