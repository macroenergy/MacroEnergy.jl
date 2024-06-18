Base.@kwdef mutable struct Node{T} <: AbstractNode{T}
    ### Fields without defaults
    id::Symbol
    demand::Vector{Float64}
    demand_header::Union{Nothing,Symbol}
    timedata::TimeData{T}
    #### Fields with defaults
    max_nsd::Vector{Float64} = [0.0]
    price_nsd::Vector{Float64} = [0.0]
    operation_vars::Dict = Dict()
    operation_expr::Dict = Dict()
    planning_vars::Dict = Dict()
    price_unmet_policy::Dict{DataType,Float64} = Dict{DataType,Float64}()
    rhs_policy::Dict{DataType,Float64} = Dict{DataType,Float64}()
    constraints::Vector{AbstractTypeConstraint} = Vector{AbstractTypeConstraint}()
end

function make_node(data::Dict{Symbol,Any}, time_data::Dict{Symbol,TimeData}, commodity::DataType)
    _node = Node{commodity}(;
        id = data[:id],
        demand = get(data, :demand, Vector{Float64}()),
        demand_header = get(data, :demand_header, nothing),
        timedata = time_data[Symbol(commodity)],
        max_nsd = get(data, :max_nsd, [0.0]),
        price_nsd = get(data, :price_nsd, [0.0]),
        price_unmet_policy = get(data, :price_unmet_policy, Dict{DataType,Float64}()),
        rhs_policy = get(data, :rhs_policy, Dict{DataType,Float64}())
    )
    add_constraints!(_node, data)
    return _node
end

Node(data::Dict{Symbol,Any}, time_data::Dict{Symbol,TimeData}, commodity::DataType) = make_node(data, time_data, commodity)

time_interval(n::AbstractNode) = n.timedata.time_interval;
subperiods(n::AbstractNode) = n.timedata.subperiods;
subperiod_weight(n::AbstractNode,w::StepRange{Int64, Int64}) = n.timedata.subperiod_weights[w];
current_subperiod(n::AbstractNode,t::Int64) = subperiods(n)[findfirst(t .∈ subperiods(n))];

commodity_type(n::AbstractNode{T}) where {T} = T;

get_id(n::AbstractNode) = n.id;

demand(n::AbstractNode) = n.demand;
demand(n::AbstractNode,t::Int64) = demand(n)[t];
demand_header(n::AbstractNode) = n.demand_header;

non_served_demand(n::AbstractNode) = n.operation_vars[:non_served_demand];
non_served_demand(n::AbstractNode,s::Int64,t::Int64) = non_served_demand(n)[s,t];

net_balance(n::AbstractNode) = n.operation_expr[:net_balance];
net_balance(n::AbstractNode,t::Int64) = net_balance(n)[t];

max_non_served_demand(n::AbstractNode) = n.max_nsd;
max_non_served_demand(n::AbstractNode,s::Int64) = max_non_served_demand(n)[s];

price_non_served_demand(n::AbstractNode) = n.price_nsd;
price_non_served_demand(n::AbstractNode,s::Int64) = price_non_served_demand(n)[s];

segments_non_served_demand(n::AbstractNode) = 1:length(n.max_nsd);

all_constraints(n::AbstractNode) = n.constraints;

price_unmet_policy(n::AbstractNode) = n.price_unmet_policy;
price_unmet_policy(n::AbstractNode,c::DataType) = price_unmet_policy(n)[c];

rhs_policy(n::AbstractNode) = n.rhs_policy;
rhs_policy(n::AbstractNode,c::DataType) = rhs_policy(n)[c];

function add_operation_variables!(n::AbstractNode, model::Model)

    n.operation_expr[:net_balance] =
        @expression(model, [t in time_interval(n)], 0 * model[:vREF])

    if !all(max_non_served_demand(n).==0)
        n.operation_vars[:non_served_demand] = @variable(
            model,
            [s in segments_non_served_demand(n) ,t in time_interval(n)],
            lower_bound = 0.0,
            base_name = "vNSD_$(get_id(n))"
        )

        for t in time_interval(n)
            w = current_subperiod(n,t);
            for s in segments_non_served_demand(n)
                add_to_expression!(model[:eVariableCost], subperiod_weight(n,w)*price_non_served_demand(n,s), non_served_demand(n,s,t))
                add_to_expression!(net_balance(n,t), non_served_demand(n,s,t))
            end
        end
    end

    return nothing
end

function add_planning_variables!(n::AbstractNode,model::Model)
    if in(PolicyConstraint,supertype.(typeof.(n.constraints)))
        ct_all = findall(PolicyConstraint.==supertype.(typeof.(n.constraints)));
        for ct in ct_all
            
            ct_type = typeof(n.constraints[ct]);
            
            n.planning_vars[Symbol(string(ct_type)*"_Budget")] = @variable(
            model,
            [w in subperiods(n)],
            base_name = "v"*string(ct_type)*"_Budget_$(get_id(n))"
            )
            @constraint(model,sum(n.planning_vars[Symbol(string(ct_type)*"_Budget")]) == rhs_policy(n,ct_type))
        end
    end
    return nothing
end

function get_nodes_sametype(nodes::Dict{Symbol,Node},commodity::DataType)
    return filter(((k,n),) -> commodity_type(n)==commodity, nodes)
end