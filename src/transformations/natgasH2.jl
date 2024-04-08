
### function for NaturalGasHydrogen
### Define a natural gas hydrogen plant or SMR similar to a natural gas power plant

function make_natgasH2(data::Dict{Symbol,Any}, macro_settings::NamedTuple)::Transformation{NaturalGasH2}
    smr = Transformation{NaturalGasH2}(;
        id = data[:id],
        time_interval = macro_settings[:TimeIntervals][data[:time_interval]],
        stoichiometry_balance_names = [:energy, :emissions],
        constraints = [StoichiometryBalanceConstraint()]
        )
    
    H2_edge_id = :H2
    smr.TEdges[H2_edge_id] = TEdge{data[:edge_commodities][H2_edge_id]}(;
    ### To be confirmed
    id = :test,
    node = data[:nodes][H2_edge_id],
    transformation = smr,
    direction = :output,
    has_planning_variables = true,
    can_expand = data[:can_expand],
    can_retire = data[:can_retire],
    capacity_size = data[:capacity_size],
    time_interval = macro_settings[:TimeIntervals][data[:edge_commodities][H2_edge_id]],
    subperiods = macro_settings[:SubPeriods][data[:edge_commodities][H2_edge_id]],
    ### smr_heatrate, smr_inv_cost, smr_fom_cost, smr_vom_cost,
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

    ### To be confirmed
    ramp_up_percentage = data[:ramp_up_percentage],
    ramp_down_percentage = data[:ramp_down_percentage],
    up_time = data[:up_time],
    down_time = data[:down_time],
    min_flow = data[:min_flow],
    constraints = [CapacityConstraint()]
    )

    ng_edge_id = :NG
    smr.TEdges[ng_edge_id] = TEdge{data[:edge_commodities][ng_edge_id]}(;
    id = Symbol(string(data[:id], "_", ng_edge_id)),
    node = data[:nodes][ng_edge_id],
    transformation = smr,
    direction = :input,
    has_planning_variables = false,
    time_interval = macro_settings[:TimeIntervals][data[:edge_commodities][ng_edge_id]],
    subperiods = macro_settings[:SubPeriods][data[:edge_commodities][ng_edge_id]],
    st_coeff = Dict(:energy=>1.0, :emissions=>data[:fuel_co2])
    )
    
    co2_edge_id = :CO2
    smr.TEdges[co2_edge_id] = TEdge{CO2}(;
    id = Symbol(string(data[:id], "_", co2_edge_id)),
    node = data[:nodes][co2_edge_id],
    transformation = smr,
    direction = :output,
    has_planning_variables = false,
    time_interval = macro_settings[:TimeIntervals][data[:edge_commodities][co2_edge_id]],
    subperiods = macro_settings[:SubPeriods][data[:edge_commodities][co2_edge_id]],
    st_coeff = Dict(:energy=>0.0,:emissions=>1.0)
    )

end

Transformation{NaturalGasH2}(
    data::Dict{Symbol,Any}, 
    macro_settings::NamedTuple
) = make_natgasH2(data, macro_settings)