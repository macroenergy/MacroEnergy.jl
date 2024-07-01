Base.@kwdef mutable struct Edge{T} <: AbstractEdge{T}
    timedata::TimeData{T}
    start_node::AbstractNode{T}
    end_node::AbstractNode{T}
    existing_capacity::Float64
    unidirectional::Bool = false
    max_line_reinforcement::Float64 = Inf
    line_reinforcement_cost::Float64 = 0.0
    #### num_lines_existing::Int64 = 1
    can_expand::Bool = true
    ####max_num_lines_expanded::Int64 = Inf
    ####investment_cost_per_line::Float64 = 0.0
    op_cost::Float64 = 0.0
    distance::Float64 = 0.0
    line_loss_fraction::Float64 = 0.0
    planning_vars::Dict = Dict()
    operation_vars::Dict = Dict()
    constraints::Vector{AbstractTypeConstraint} = Vector{AbstractTypeConstraint}()
end

function make_edge(data::Dict{Symbol,Any}, time_data::Dict{Symbol,TimeData}, commodity::DataType, start_node::AbstractNode, end_node::AbstractNode)
    _edge = Edge{commodity}(;
        timedata = time_data[Symbol(commodity)],
        start_node = start_node,
        end_node = end_node,
        existing_capacity = get(data, :existing_capacity, 0.0),
        unidirectional = get(data, :unidirectional, false),
        max_line_reinforcement = get(data, :max_line_reinforcement, Inf),
        line_reinforcement_cost = get(data, :line_reinforcement_cost, 0.0),
        can_expand = get(data, :can_expand, true),
        op_cost = get(data, :op_cost, 0.0),
        distance = get(data, :distance, 0.0),
        line_loss_fraction = get(data, :line_loss_fraction, 0.0)
    )
    add_constraints!(_edge, data)
    return _edge
end
Edge(data::Dict{Symbol,Any}, time_data::Dict{Symbol,TimeData}, commodity::DataType, start_node::AbstractNode, end_node::AbstractNode) = make_edge(data, time_data, commodity, start_node, end_node)

start_node(e::AbstractEdge) = e.start_node;
end_node(e::AbstractEdge) = e.end_node;

start_node_id(e::AbstractEdge) = get_id(e.start_node);
end_node_id(e::AbstractEdge) = get_id(e.end_node);

timesteps(e::AbstractEdge) = e.timedata.timesteps;
subperiods(e::AbstractEdge) = e.timedata.subperiods;
subperiod_weight(e::AbstractEdge,w::StepRange{Int64, Int64}) = e.timedata.subperiod_weights[w];
current_subperiod(e::AbstractEdge,t::Int64) = subperiods(e)[findfirst(t .∈ subperiods(e))];

commodity_type(e::AbstractEdge{T}) where {T} = T;
existing_capacity(e::AbstractEdge) = e.existing_capacity;
max_line_reinforcement(e::AbstractEdge) = e.max_line_reinforcement;
line_reinforcement_cost(e::AbstractEdge) = e.line_reinforcement_cost;
can_expand(e::AbstractEdge) = e.can_expand;
new_capacity(e::AbstractEdge) = e.planning_vars[:new_capacity];
capacity(e::AbstractEdge) = e.planning_vars[:capacity];
flow(e::AbstractEdge) = e.operation_vars[:flow];
flow(e::AbstractEdge,t::Int64) = flow(e)[t];

all_constraints(e::AbstractEdge) = e.constraints;

function add_planning_variables!(e::AbstractEdge, model::Model)

    e.planning_vars[:new_capacity] = @variable(
        model,
        lower_bound = 0.0,
        upper_bound = max_line_reinforcement(e),
        base_name = "vNEWCAPEDGE_$(start_node_id(e))_$(end_node_id(e))"
    )

    e.planning_vars[:capacity] = @variable(
        model,
        lower_bound = 0.0,
        base_name = "vCAPEDGE_$(start_node_id(e))_$(end_node_id(e))"
    )

    @constraint(model, capacity(e) == new_capacity(e) + existing_capacity(e))

    if !can_expand(e)
        fix(new_capacity(e), 0.0; force = true)
    else
        add_to_expression!(model[:eFixedCost], line_reinforcement_cost(e), new_capacity(e))
    end

    return nothing

end

function add_operation_variables!(e::AbstractEdge, model::Model)
    if e.unidirectional
        e.operation_vars[:flow] = @variable(
            model,
            [t in timesteps(e)],
            lower_bound = 0.0,
            base_name = "vFLOW_$(start_node_id(e))_$(end_node_id(e))"
        )
    else
        e.operation_vars[:flow] = @variable(
            model,
            [t in timesteps(e)],
            base_name = "vFLOW_$(start_node_id(e))_$(end_node_id(e))"
        )
    end

    add_to_expression!.(net_balance(start_node(e)), -flow(e))
    
    add_to_expression!.(net_balance(end_node(e)), flow(e))

end

