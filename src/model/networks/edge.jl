macro AbstractEdgeBaseAttributes()
    esc(quote
        id::Symbol
        timedata::TimeData{T}
        start_vertex::AbstractVertex
        end_vertex::AbstractVertex

        availability::Vector{Float64} = Float64[]
        can_expand::Bool = false
        can_retire::Bool = false
        capacity::Union{JuMPVariable,Float64} = 0.0
        capacity_size::Float64 = 1.0
        constraints::Vector{AbstractTypeConstraint} = Vector{AbstractTypeConstraint}()
        distance::Float64 = 0.0
        existing_capacity::Float64 = 0.0
        fixed_om_cost::Float64 = 0.0
        flow::Union{JuMPVariable,Vector{Float64}} = Vector{VariableRef}()
        has_planning_variables::Bool = false
        investment_cost::Float64 = 0.0
        max_capacity::Float64 = Inf
        min_capacity::Float64 = 0.0
        min_flow_fraction::Float64 = 0.0
        new_capacity::Union{JuMPVariable,Float64} = 0.0
        price::Vector{Float64} = Float64[]
        ramp_down_fraction::Float64 = 1.0
        ramp_up_fraction::Float64 = 1.0
        ret_capacity::Union{JuMPVariable,Float64} = 0.0
        unidirectional::Bool = false
        variable_om_cost::Float64 = 0.0
    end)
end
Base.@kwdef mutable struct Edge{T} <: AbstractEdge{T}
    @AbstractEdgeBaseAttributes()
end

function make_edge(
    id::Symbol,
    data::AbstractDict{Symbol,Any},
    time_data::TimeData,
    commodity::DataType,
    start_vertex::AbstractVertex,
    end_vertex::AbstractVertex,
)
    _edge = Edge{commodity}(;
        id = id,
        timedata = time_data,
        start_vertex = start_vertex,
        end_vertex = end_vertex,
        availability = get(data, :availability, Float64[]),
        can_expand = get(data, :can_expand, false),
        can_retire = get(data, :can_retire, false),
        capacity_size = get(data, :capacity_size, 1.0),
        distance = get(data, :distance, 0.0),
        existing_capacity = get(data, :existing_capacity, 0.0),
        fixed_om_cost = get(data, :fixed_om_cost, 0.0),
        has_planning_variables = get(data, :has_planning_variables, false),
        investment_cost = get(data, :investment_cost, 0.0),
        max_capacity = get(data, :max_capacity, Inf),
        min_capacity = get(data, :min_capacity, 0.0),
        min_flow_fraction = get(data, :min_flow_fraction, 0.0),
        price = get(data, :price, Float64[]),
        ramp_down_fraction = get(data, :ramp_down_fraction, 1.0),
        ramp_up_fraction = get(data, :ramp_up_fraction, 1.0),
        unidirectional = get(data, :unidirectional, false),
        variable_om_cost = get(data, :variable_om_cost, 0.0),
    )
    return _edge
end
Edge(
    id::Symbol,
    data::Dict{Symbol,Any},
    time_data::TimeData,
    commodity::DataType,
    start_vertex::AbstractVertex,
    end_vertex::AbstractVertex,
) = make_edge(id, data, time_data, commodity, start_vertex, end_vertex)


######### Edge interface #########
all_constraints(e::AbstractEdge) = e.constraints;
availability(e::AbstractEdge) = e.availability;
availability(e::AbstractEdge, t::Int64) =
    (isempty(availability(e)) == true) ? 1.0 : availability(e)[t];
balance_data(e::AbstractEdge, v::AbstractVertex, i::Symbol) =
    isempty(balance_data(v, i)) ? 1.0 : balance_data(v, i)[id(e)];
can_expand(e::AbstractEdge) = e.can_expand;
can_retire(e::AbstractEdge) = e.can_retire;
capacity(e::AbstractEdge) = e.capacity;
capacity_size(e::AbstractEdge) = e.capacity_size;
end_vertex(e::AbstractEdge) = e.end_vertex;
existing_capacity(e::AbstractEdge) = e.existing_capacity;
fixed_om_cost(e::AbstractEdge) = e.fixed_om_cost;
flow(e::AbstractEdge) = e.flow;
flow(e::AbstractEdge, t::Int64) = flow(e)[t];
has_planning_variables(e::AbstractEdge) = e.has_planning_variables;
id(e::AbstractEdge) = e.id;
investment_cost(e::AbstractEdge) = e.investment_cost;
max_capacity(e::AbstractEdge) = e.max_capacity;
min_capacity(e::AbstractEdge) = e.min_capacity;
min_flow_fraction(e::AbstractEdge) = e.min_flow_fraction;
new_capacity(e::AbstractEdge) = e.new_capacity;
ramp_down_fraction(e::AbstractEdge) = e.ramp_down_fraction;
ramp_up_fraction(e::AbstractEdge) = e.ramp_up_fraction;
ret_capacity(e::AbstractEdge) = e.ret_capacity;
price(e::AbstractEdge) = e.price;
price(e::AbstractEdge, t::Int64) = price(e)[t];
start_vertex(e::AbstractEdge) = e.start_vertex;
variable_om_cost(e::AbstractEdge) = e.variable_om_cost;
##### End of Edge interface #####


function add_linking_variables!(e::AbstractEdge, model::Model)

    if has_planning_variables(e)
        e.capacity = @variable(model, lower_bound = 0.0, base_name = "vCAP_$(id(e))")
    end

end

function planning_model!(e::AbstractEdge, model::Model)

    if has_planning_variables(e)

        e.new_capacity = @variable(model, lower_bound = 0.0, base_name = "vNEWCAP_$(id(e))")

        e.ret_capacity = @variable(model, lower_bound = 0.0, base_name = "vRETCAP_$(id(e))")

        if !can_expand(e)
            fix(new_capacity(e), 0.0; force = true)
        else
            add_to_expression!(
                model[:eFixedCost],
                investment_cost(e) * capacity_size(e),
                new_capacity(e),
            )
        end

        if !can_retire(e)
            fix(ret_capacity(e), 0.0; force = true)
        end

        if fixed_om_cost(e) > 0
            add_to_expression!(model[:eFixedCost], fixed_om_cost(e), capacity(e))
        end

    end

    ### DEFAULT CONSTRAINTS ###

    @constraint(
        model,
        capacity(e) ==
        capacity_size(e) * (new_capacity(e) - ret_capacity(e)) + existing_capacity(e)
    )

    return nothing

end

function operation_model!(e::Edge, model::Model)

    if e.unidirectional
        e.flow = @variable(
            model,
            [t in time_interval(e)],
            lower_bound = 0.0,
            base_name = "vFLOW_$(id(e))"
        )
    else
        e.flow = @variable(model, [t in time_interval(e)], base_name = "vFLOW_$(id(e))")
    end

    update_balance!(e, start_vertex(e), -1)

    update_balance!(e, end_vertex(e), 1)

    for t in time_interval(e)

        w = current_subperiod(e, t)

        if variable_om_cost(e) > 0
            add_to_expression!(
                model[:eVariableCost],
                subperiod_weight(e, w) * variable_om_cost(e),
                flow(e, t),
            )
        end

        if !isempty(price(e))
            add_to_expression!(
                model[:eVariableCost],
                subperiod_weight(e, w) * price(e, t),
                flow(e, t),
            )
        end

    end

    ### DEFAULT CONSTRAINTS ###

    if isa(start_vertex(e), Storage)
        @constraint(
            model,
            [t in time_interval(e)],
            balance_data(e, start_vertex(e), :storage) * flow(e, t) <=
            storage_level(start_vertex(e), timestepbefore(t, 1, subperiods(e)))
        )
    end

    return nothing
end

Base.@kwdef mutable struct EdgeWithUC{T} <: AbstractEdge{T}
    @AbstractEdgeBaseAttributes()
    min_down_time::Int64 = 0.0
    min_up_time::Int64 = 0.0
    startup_cost::Float64 = 0.0
    startup_fuel::Float64 = 0.0
    startup_fuel_balance_id::Symbol = :none
    ucommit::Union{JuMPVariable,Vector{Float64}} = Vector{VariableRef}()
    ushut::Union{JuMPVariable,Vector{Float64}} = Vector{VariableRef}()
    ustart::Union{JuMPVariable,Vector{Float64}} = Vector{VariableRef}()
end

function make_edge_UC(
    id::Symbol,
    data::Dict{Symbol,Any},
    time_data::TimeData,
    commodity::DataType,
    start_vertex::AbstractVertex,
    end_vertex::AbstractVertex,
)
    _edge = EdgeWithUC{commodity}(;
        id = id,
        timedata = time_data,
        start_vertex = start_vertex,
        end_vertex = end_vertex,
        availability = get(data, :availability, Float64[]),
        can_expand = get(data, :can_expand, false),
        can_retire = get(data, :can_retire, false),
        capacity_size = get(data, :capacity_size, 1.0),
        distance = get(data, :distance, 0.0),
        existing_capacity = get(data, :existing_capacity, 0.0),
        fixed_om_cost = get(data, :fixed_om_cost, 0.0),
        has_planning_variables = get(data, :has_planning_variables, false),
        investment_cost = get(data, :investment_cost, 0.0),
        max_capacity = get(data, :max_capacity, Inf),
        min_capacity = get(data, :min_capacity, 0.0),
        min_flow_fraction = get(data, :min_flow_fraction, 0.0),
        price = get(data, :price, Float64[]),
        ramp_down_fraction = get(data, :ramp_down_fraction, 1.0),
        ramp_up_fraction = get(data, :ramp_up_fraction, 1.0),
        unidirectional = get(data, :unidirectional, false),
        variable_om_cost = get(data, :variable_om_cost, 0.0),
        min_down_time = get(data, :min_down_time, 0.0),
        min_up_time = get(data, :min_up_time, 0.0),
        startup_cost = get(data, :startup_cost, 0.0),
        startup_fuel = get(data, :startup_fuel, 0.0),
        startup_fuel_balance_id = get(data, :startup_fuel_balance_id, :none),
    )
    return _edge
end
EdgeWithUC(
    id::Symbol,
    data::Dict{Symbol,Any},
    time_data::TimeData,
    commodity::DataType,
    start_vertex::AbstractVertex,
    end_vertex::AbstractVertex,
) = make_edge_UC(id, data, time_data, commodity, start_vertex, end_vertex)

######### EdgeWithUC interface #########
min_down_time(e::EdgeWithUC) = e.min_down_time;
min_up_time(e::EdgeWithUC) = e.min_up_time;
startup_cost(e::EdgeWithUC) = e.startup_cost;
startup_fuel(e::EdgeWithUC) = e.startup_fuel;
startup_fuel_balance_id(e::EdgeWithUC) = e.startup_fuel_balance_id;
ucommit(e::EdgeWithUC) = e.ucommit;
ucommit(e::EdgeWithUC, t::Int64) = ucommit(e)[t];
ushut(e::EdgeWithUC) = e.ushut;
ushut(e::EdgeWithUC, t::Int64) = ushut(e)[t];
ustart(e::EdgeWithUC) = e.ustart;
ustart(e::EdgeWithUC, t::Int64) = ustart(e)[t];
##### End of EdgeWithUC interface #####

function operation_model!(e::EdgeWithUC, model::Model)

    if !e.unidirectional
        error(
            "UC is available only for unidirectional edges, set edge $(id(e)) to be unidirectional",
        )
        return nothing
    end

    e.flow = @variable(
        model,
        [t in time_interval(e)],
        lower_bound = 0.0,
        base_name = "vFLOW_$(id(e))"
    )

    e.ucommit = @variable(
        model,
        [t in time_interval(e)],
        lower_bound = 0.0,
        base_name = "vCOMMIT_$(id(e))"
    )

    e.ustart = @variable(
        model,
        [t in time_interval(e)],
        lower_bound = 0.0,
        base_name = "vSTART_$(id(e))"
    )

    e.ushut = @variable(
        model,
        [t in time_interval(e)],
        lower_bound = 0.0,
        base_name = "vSHUT_$(id(e))"
    )

    update_balance!(e, start_vertex(e), -1)

    update_balance!(e, end_vertex(e), 1)

    for t in time_interval(e)

        w = current_subperiod(e, t)

        if variable_om_cost(e) > 0
            add_to_expression!(
                model[:eVariableCost],
                subperiod_weight(e, w) * variable_om_cost(e),
                flow(e, t),
            )
        end

        if !isempty(price(e))
            add_to_expression!(
                model[:eVariableCost],
                subperiod_weight(e, w) * price(e, t),
                flow(e, t),
            )
        end

        if startup_cost(e) > 0
            add_to_expression!(
                model[:eVariableCost],
                subperiod_weight(e, w) * startup_cost(e) * capacity_size(e),
                ustart(e, t),
            )
        end

    end

    ### DEFAULT CONSTRAINTS ###

    @constraints(
        model,
        begin
            [t in time_interval(e)], ucommit(e, t) <= capacity(e) / capacity_size(e)
            [t in time_interval(e)], ustart(e, t) <= capacity(e) / capacity_size(e)
            [t in time_interval(e)], ushut(e, t) <= capacity(e) / capacity_size(e)
        end
    )

    @constraint(
        model,
        [t in time_interval(e)],
        ucommit(e, t) - ucommit(e, timestepbefore(t, 1, subperiods(e))) ==
        ustart(e, t) - ushut(e, t)
    )

    return nothing
end


function edges(assets::Vector{AbstractAsset})
    edges = Vector{AbstractEdge}()
    for a in assets
        for f in fieldnames(typeof(a))
            if isa(getfield(a, f), AbstractEdge)
                push!(edges, getfield(a, f))
            end
        end
    end
    return edges
end

function update_balance!(e::Edge, v::AbstractVertex, s::Int64)
    for i in balance_ids(v)
        add_to_expression!.(get_balance(v, i), s * balance_data(e, v, i) * flow(e))
    end
end

function update_balance!(e::EdgeWithUC, v::AbstractVertex, s::Int64)

    for i in balance_ids(v)
        add_to_expression!.(get_balance(v, i), s * balance_data(e, v, i) * flow(e))
    end

    if startup_fuel(e) > 0
        ii = startup_fuel_balance_id(e)
        if ii ∈ balance_ids(v)
            add_to_expression!.(
                get_balance(v, ii),
                s * startup_fuel(e) * capacity_size(e) * ustart(e),
            )
        end
    end

end

function update_balance!(e::Edge, v::Transformation, s::Int64)
    for t in time_interval(e)
        transform_time = ceil(Int, (hours_per_timestep(e) * t) / hours_per_timestep(v))
        for i in balance_ids(v)
            add_to_expression!(
                get_balance(v, i, transform_time),
                s * balance_data(e, v, i) * flow(e, t),
            )
        end
    end
end

function update_balance!(e::EdgeWithUC, v::Transformation, s::Int64)

    for t in time_interval(e)
        transform_time = ceil(Int, (hours_per_timestep(e) * t) / hours_per_timestep(v))
        for i in balance_ids(v)
            add_to_expression!(
                get_balance(v, i, transform_time),
                s * balance_data(e, v, i) * flow(e, t),
            )
        end
        if startup_fuel(e) > 0
            ii = startup_fuel_balance_id(e)
            if ii ∈ balance_ids(v)
                add_to_expression!(
                    get_balance(v, ii, transform_time),
                    s * startup_fuel(e) * capacity_size(e) * ustart(e, t),
                )
            end
        end
    end


end
