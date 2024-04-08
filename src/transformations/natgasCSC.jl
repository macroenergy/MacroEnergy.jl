### function for NaturalGasCSC
### Define a natural gas plant with CSC
function make_natgasCSC(data::Dict{Symbol,Any}, macro_settings::NamedTuple)::Transformation{NaturalGasCSC}
    ngcc_CSC = Transformation{NaturalGasCSC}(;
        id = data[:id],
        time_interval = macro_settings[:TimeIntervals][data[:time_interval]],
        stoichiometry_balance_names = [:energy, :emissions],
        constraints = [StoichiometryBalanceConstraint()]
        )
    
    elec_edge_id = :E
    ngcc_CSC.TEdges[elec_edge_id] = TEdge{data[:edge_commodities][elec_edge_id]}(;
    ### To be confirme
    id = :test,
    node = data[:nodes][elec_edge_id],
    transformation = ngcc_CSC,
    direction = :output,
    has_planning_variables = true,
    can_expand = data[:can_expand],
    can_retire = data[:can_retire],
    capacity_size = data[:capacity_size],
    time_interval = macro_settings[:TimeIntervals][data[:edge_commodities][elec_edge_id]],
    subperiods = macro_settings[:SubPeriods][data[:edge_commodities][elec_edge_id]],
    st_coeff = Dict(:energy=>data[:Heat_Rate_MMBTU_per_MWh],:emissions=>0.0),
    min_capacity = data[:min_capacity],
    max_capacity = data[:max_capacity],
    existing_capacity = data[:existing_capacity],
    investment_cost = data[:investment_cost],
    fixed_om_cost = data[:fixed_om_cost],
    variable_om_cost = data[:variable_om_cost],
    ##### Ignore UC for now
    ######start_cost = dfGen.Start_Cost_per_MW[i],
    ######ucommit = false,
    ramp_up_percentage = data[:ramp_up_percentage],
    ramp_down_percentage = data[:ramp_down_percentage],
    up_time = data[:up_time],
    down_time = data[:down_time],
    min_flow = data[:min_flow],
    constraints = [CapacityConstraint()]
    )

    ng_edge_id = :NG
    ngcc_CSC.TEdges[ng_edge_id] = TEdge{data[:edge_commodities][ng_edge_id]}(;
    id = Symbol(string(data[:id], "_", ng_edge_id)),
    node = data[:nodes][ng_edge_id],
    transformation = ngcc_CSC,
    direction = :input,
    has_planning_variables = false,
    time_interval = macro_settings[:TimeIntervals][data[:edge_commodities][ng_edge_id]],
    subperiods = macro_settings[:SubPeriods][data[:edge_commodities][ng_edge_id]],
    st_coeff = Dict(:energy=>1.0, :emissions=>data[:fuel_co2])
    )
    
    co2_edge_id = :CO2
    ngcc_CSC.TEdges[co2_edge_id] = TEdge{CO2}(;
    id = Symbol(string(data[:id], "_", co2_edge_id)),
    node = data[:nodes][co2_edge_id],
    transformation = ngcc_CSC,
    direction = :output,
    has_planning_variables = false,
    time_interval = macro_settings[:TimeIntervals][data[:edge_commodities][co2_edge_id]],
    subperiods = macro_settings[:SubPeriods][data[:edge_commodities][co2_edge_id]],
    st_coeff = Dict(:energy=>0.0,:emissions=>1.0)
    )


    co2_Capture_edge_id = :CO2
    ngcc_CSC.TEdges[co2_Capture_edge_id] = TEdge{CO2}(;
    id = Symbol(string(data[:id], "_", co2_Capture_edge_id)),
    node = data[:nodes][co2_Capture_edge_id],
    transformation = ngcc_CSC,
    direction = :output,
    has_planning_variables = false,
    time_interval = macro_settings[:TimeIntervals][data[:edge_commodities][co2_Capture_edge_id]],
    subperiods = macro_settings[:SubPeriods][data[:edge_commodities][co2_Capture_edge_id]],
    st_coeff = Dict(:energy=>0.0,:emissions=>1.0,:captured_emissions=>1.0)
    )
end

Transformation{NaturalGasCSC}(
    data::Dict{Symbol,Any}, 
    macro_settings::NamedTuple
) = make_natgasCSC(data, macro_settings)