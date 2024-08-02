struct SolarPV <: AbstractAsset
    energy_transform::Transformation
    elec_tedge::TEdge{Electricity}
end

struct WindTurbine <: AbstractAsset
    energy_transform::Transformation
    elec_tedge::TEdge{Electricity}
end

const VRE = Union{SolarPV, WindTurbine}

function make_asset(::Type{SolarPV}, data::Dict{Symbol,Any}, time_data::Dict{Symbol,TimeData}, nodes::Dict{Symbol,Node})
    node_out_id = Symbol(data[:nodes][:Electricity])
    node_out = nodes[node_out_id]
    energy_transform, tedge = make_vre(data, time_data, node_out)
    return SolarPV(energy_transform, tedge)
end

function make_asset(::Type{WindTurbine}, data::Dict{Symbol,Any}, time_data::Dict{Symbol,TimeData}, nodes::Dict{Symbol,Node})
    node_out_id = Symbol(data[:nodes][:Electricity])
    node_out = nodes[node_out_id]
    energy_transform, tedge = make_vre(data, time_data, node_out)
    return WindTurbine(energy_transform, tedge)
    end

make_solarpv(data::Dict{Symbol,Any}, time_data::Dict{Symbol,TimeData}, nodes::Dict{Symbol,Node}) = make_asset(SolarPV, data, time_data, nodes)
make_windturbine(data::Dict{Symbol,Any}, time_data::Dict{Symbol,TimeData}, nodes::Dict{Symbol,Node}) = make_asset(WindTurbine, data, time_data, nodes)

function add_capacity_factor!(s::VRE, capacity_factor::Vector{Float64})
    s.elec_tedge.capacity_factor = capacity_factor
end

function make_vre(data::Dict{Symbol,Any}, time_data::Dict{Symbol,TimeData}, node_out::Node)
    #============================================================
    This function makes a VRE (SolarPV or WindTurbine) from the 
    data Dict. It is a helper function for load_transformations!.
    ============================================================#

    ## conversion process (node)
    _energy_transform = Transformation(;
        id=get(data,:id,Symbol("")),
        timedata=deepcopy(time_data[:Electricity]),
        # Note that this transformation does not 
        # have a stoichiometry balance because the 
        # sunshine is exogenous
    )
    add_constraints!(_energy_transform, data)

    ## electricity edge
    # get electricity edge data
    _tedge_id,_tedge_data = get_tedge_data(data, :elec_tedge)
    isnothing(_tedge_data) && error("No electricity edge data found for VRE")
    # set the id
    _tedge_data[:id] = _tedge_id
    # make the edge
    _tedge = make_tedge(_tedge_data, time_data, _energy_transform, node_out)

    ## add reference to tedges in transformation
    _TEdges = Dict(:E=>_tedge)
    _energy_transform.TEdges = _TEdges

    return _energy_transform, _tedge
end