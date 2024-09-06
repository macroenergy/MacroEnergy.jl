Base.@kwdef mutable struct Node{T} <: AbstractVertex
    @AbstractVertexBaseAttributes()
    demand::Union{Vector{Float64},Dict{Int64,Float64}} = Vector{Float64}()
    demand_header::Union{Nothing,Symbol} = nothing
    max_nsd::Vector{Float64} = [0.0]
    price_nsd::Vector{Float64} = [0.0]
    non_served_demand::Matrix{Union{VariableRef,Float64}} = Matrix{VariableRef}(undef,0,0)
    price_unmet_policy::Dict{DataType,Float64} = Dict{DataType,Float64}()
    rhs_policy::Dict{DataType,Float64} = Dict{DataType,Float64}()
    policy_budgeting_vars::Dict = Dict()
    policy_slack_vars::Dict = Dict()
end


function make_node(data::AbstractDict{Symbol,Any}, time_data::TimeData, commodity::DataType)
    _node = Node{commodity}(;
        id = Symbol(data[:id]),
        demand = get(data, :demand, Vector{Float64}()),
        demand_header = get(data, :demand_header, nothing),
        timedata = time_data,
        max_nsd = get(data, :max_nsd, [0.0]),
        price_nsd = get(data, :price_nsd, [0.0]),
        price_unmet_policy = get(data, :price_unmet_policy, Dict{DataType,Float64}()),
        rhs_policy = get(data, :rhs_policy, Dict{DataType,Float64}())
    )
    # add_constraints!(_node, data)
    return _node
end

Node(data::AbstractDict{Symbol,Any}, time_data::TimeData, commodity::DataType) = make_node(data, time_data, commodity)

commodity_type(n::Node{T}) where {T} = T;
demand(n::Node) = n.demand;
demand(n::Node,t::Int64) = demand(n)[t];
demand_header(n::Node) = n.demand_header;
non_served_demand(n::Node) = n.non_served_demand;
non_served_demand(n::Node,s::Int64,t::Int64) = non_served_demand(n)[s,t];
max_non_served_demand(n::Node) = n.max_nsd;
max_non_served_demand(n::Node,s::Int64) = max_non_served_demand(n)[s];
price_non_served_demand(n::Node) = n.price_nsd;
price_non_served_demand(n::Node,s::Int64) = price_non_served_demand(n)[s];
segments_non_served_demand(n::Node) = 1:length(n.max_nsd);
price_unmet_policy(n::Node) = n.price_unmet_policy;
price_unmet_policy(n::Node,c::DataType) = price_unmet_policy(n)[c];
rhs_policy(n::Node) = n.rhs_policy;
rhs_policy(n::Node,c::DataType) = rhs_policy(n)[c];
policy_budgeting_vars(n::Node) = n.policy_budgeting_vars;
policy_slack_vars(n::Node) = n.policy_slack_vars;

function add_planning_variables!(n::Node,model::Model)
    if in(PolicyConstraint,supertype.(typeof.(n.constraints)))
        ct_all = findall(PolicyConstraint.==supertype.(typeof.(n.constraints)));
        for ct in ct_all
            
            ct_type = typeof(n.constraints[ct]);
            
            n.policy_budgeting_vars[Symbol(string(ct_type)*"_Budget")] = @variable(
            model,
            [w in subperiod_indices(n)],
            base_name = "v"*string(ct_type)*"_Budget_$(get_id(n))"
            )
            @constraint(model,sum(n.policy_budgeting_vars[Symbol(string(ct_type)*"_Budget")]) == rhs_policy(n,ct_type))
        end
    end
    return nothing
end

function add_operation_variables!(n::Node, model::Model)

    if !isempty(balance_ids(n))
        for i in balance_ids(n)
            if i==:demand
                n.operation_expr[:demand] = @expression(model, [t in time_interval(n)], -demand(n,t) * model[:vREF])
            else
                n.operation_expr[i] = @expression(model, [t in time_interval(n)], 0 * model[:vREF])
            end
        end
    end

    if !all(max_non_served_demand(n).==0)
        n.non_served_demand = @variable(
            model,
            [s in segments_non_served_demand(n) ,t in time_interval(n)],
            lower_bound = 0.0,
            base_name = "vNSD_$(get_id(n))"
        )

        for t in time_interval(n)
            w = current_subperiod(n,t);
            for s in segments_non_served_demand(n)
                add_to_expression!(model[:eVariableCost], subperiod_weight(n,w)*price_non_served_demand(n,s), non_served_demand(n,s,t))
                add_to_expression!(get_balance(n,:demand,t), non_served_demand(n,s,t))
            end
        end
    end

    return nothing
end


function get_nodes_sametype(nodes::Vector{Node},commodity::DataType)
    return filter(n -> commodity_type(n)==commodity, nodes)
end