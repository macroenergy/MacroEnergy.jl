Base.@kwdef mutable struct TEdgeWithUC{T} <: AbstractTransformationEdgeWithUC{T}
    @AbstractTransformationEdgeBaseAttributes()
    min_up_time::Int64 = 0.0
    min_down_time::Int64 = 0.0
    start_cost::Float64 = 0.0
    start_fuel::Float64 = 0.0
    start_fuel_stoichiometry_name::Symbol = :none
end

function make_tedge(::Type{TEdgeWithUC}, data::Dict{Symbol,Any}, time_data::Dict{Symbol,TimeData}, transformation::AbstractTransform, node::AbstractNode)
    commodity = commodity_type(node)
    _t_edge = TEdgeWithUC{commodity}(;
        id = data[:id],
        node = node,
        transformation = transformation,
        timedata = time_data[Symbol(commodity)],
        direction = get(data, :direction, :input),
        has_planning_variables = get(data, :has_planning_vars, false),
        can_retire = get(data, :can_retire, false),
        can_expand = get(data, :can_expand, false),
        capacity_size = get(data, :capacity_size, 1.0),
        capacity_factor = get(data, :capacity_factor, Float64[]),
        st_coeff = get(data, :stoichiometry_coefficients, Dict{Symbol,Float64}()),
        min_capacity = get(data, :min_capacity, 0.0),
        max_capacity = get(data, :max_capacity, Inf),
        existing_capacity = get(data, :existing_capacity, 0.0),
        investment_cost = get(data, :investment_cost, 0.0),
        fixed_om_cost = get(data, :fixed_om_cost, 0.0),
        variable_om_cost = get(data, :variable_om_cost, 0.0),
        price = get(data, :price, Float64[]),
        ramp_up_fraction = get(data, :ramp_up_fraction, 1.0),
        ramp_down_fraction = get(data, :ramp_down_fraction, 1.0),
        min_flow_fraction = get(data, :min_flow_fraction, 0.0),
        min_up_time = get(data, :min_up_time, 0.0),
        min_down_time = get(data, :min_down_time, 0.0),
        start_cost = get(data, :start_cost, 0.0),
        start_fuel = get(data, :start_fuel, 0.0),
        start_fuel_stoichiometry_name = get(data, :fuel_stoichiometry_name, :none),
    )
    add_constraints!(_t_edge, data)
    return _t_edge
end
TEdgeWithUC(data::Dict{Symbol,Any}, time_data::Dict{Symbol,TimeData}, transformation::AbstractTransform, node::AbstractNode) = make_tedge(TEdgeWithUC, data, time_data, transformation, node)

min_up_time(e::AbstractTransformationEdgeWithUC) = e.min_up_time;
min_down_time(e::AbstractTransformationEdgeWithUC) = e.min_down_time;
start_cost(e::AbstractTransformationEdgeWithUC) = e.start_cost;
start_fuel(e::AbstractTransformationEdgeWithUC) = e.start_fuel;
start_fuel_stoichiometry_name(e::AbstractTransformationEdgeWithUC) = e.start_fuel_stoichiometry_name;
ucommit(e::AbstractTransformationEdgeWithUC) = e.operation_vars[:ucommit];
ucommit(e::AbstractTransformationEdgeWithUC,t::Int64) = ucommit(e)[t];

ustart(e::AbstractTransformationEdgeWithUC) = e.operation_vars[:ustart];
ustart(e::AbstractTransformationEdgeWithUC,t::Int64) = ustart(e)[t];

ushut(e::AbstractTransformationEdgeWithUC) = e.operation_vars[:ushut];
ushut(e::AbstractTransformationEdgeWithUC,t::Int64) = ushut(e)[t];


function add_operation_variables!(e::AbstractTransformationEdgeWithUC, model::Model)

    e.operation_vars[:flow] = @variable(
        model,
        [t in timesteps(e)],
        lower_bound = 0.0,
        base_name = "vFLOW_$(get_transformation_id(e))_$(get_id(e))"
    )

    e.operation_vars[:ucommit] = @variable(
        model,
        [t in timesteps(e)],
        lower_bound = 0.0,
        base_name = "vCOMMIT_$(get_transformation_id(e))_$(get_id(e))"
    )

    e.operation_vars[:ustart] = @variable(
        model,
        [t in timesteps(e)],
        lower_bound = 0.0,
        base_name = "vSTART_$(get_transformation_id(e))_$(get_id(e))"
    )

    e.operation_vars[:ushut] = @variable(
        model,
        [t in timesteps(e)],
        lower_bound = 0.0,
        base_name = "vSHUT_$(get_transformation_id(e))_$(get_id(e))"
    )

    dir_coeff =  (direction(e) == :input) ? -1 : (direction(e) == :output) ? 1 : error("Invalid TEdge direction")

    e_st_coeff = st_coeff(e);
    
    e_node = node(e);

    directional_flow = dir_coeff * flow(e);

    add_to_expression!.(net_balance(e_node),directional_flow)

    for t in timesteps(e)

        w = current_subperiod(e,t);

        for i in stoichiometry_balance_names(e)
            add_to_expression!(stoichiometry_balance(e,i,t), e_st_coeff[i], directional_flow[t])
        end

        if variable_om_cost(e)>0
            add_to_expression!(model[:eVariableCost], subperiod_weight(e,w)*variable_om_cost(e), flow(e,t))
        end

        if !isempty(price(e))
            add_to_expression!(model[:eVariableCost], subperiod_weight(e,w)*price(e,t), flow(e,t))
        end

        if start_cost(e)>0
            add_to_expression!(model[:eVariableCost], subperiod_weight(e,w)*start_cost(e)*capacity_size(e), ustart(e,t))
        end

        if start_fuel(e)>0
            add_to_expression!(stoichiometry_balance(e,start_fuel_stoichiometry_name(e),t), start_fuel(e)*capacity_size(e)*dir_coeff,ustart(e,t))
        end

    end

    @constraints(model, begin
    [t in timesteps(e)], ucommit(e,t) <= capacity(e)/capacity_size(e)    
    [t in timesteps(e)], ustart(e,t) <= capacity(e)/capacity_size(e)   
    [t in timesteps(e)], ushut(e,t) <= capacity(e)/capacity_size(e)  
    end)

    @constraint(model,
    [t in timesteps(e)], 
    ucommit(e,t)-ucommit(e,timestepbefore(t,1,subperiods(e))) == ustart(e,t) - ushut(e,t)
    )

    return nothing
end

