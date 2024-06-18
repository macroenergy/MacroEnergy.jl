struct SolarPV <: AbstractAsset
    solar_pv_transform::Transformation
    tedge::TEdge{Electricity}
end


function make_solarpv(data::Dict{Symbol,Any}, time_data::Dict{Symbol,TimeData}, node_out::Node)
    #=============================================
    This function makes a SolarPV from the data Dict.
    It is a helper function for load_transformations!.
    =============================================#

    ## conversion process (node)
    _solar_pv_transform = Transformation(;
        id=:SolarPV,
        timedata=time_data[:Electricity],
        # Note that this transformation does not 
        # have a stoichiometry balance because the 
        # sunshine is exogenous
    )
    add_constraints!(_solar_pv_transform, data)

    ## electricity edge
    # get electricity edge data
    _tedge_data = get_tedge_data(data, :Electricity)
    isnothing(_tedge_data) && error("No electricity edge data found for SolarPV")
    # set the id
    _tedge_data[:id] = :E
    # make the edge
    _tedge = make_tedge(_tedge_data, time_data, _solar_pv_transform, node_out)

    return SolarPV(_solar_pv_transform, _tedge)
end

function add_capacity_factor!(s::SolarPV, capacity_factor::Vector{Float64})
    s.tedge.capacity_factor = capacity_factor
end