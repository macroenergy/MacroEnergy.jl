macro AbstractNodeBaseAttributes()
    node_defaults = node_default_data()
    esc(quote
        demand::Vector{Float64} = Vector{Float64}()
        min_nsd::Vector{Float64} = $node_defaults[:min_nsd]
        max_nsd::Vector{Float64} = $node_defaults[:max_nsd]
        max_supply::Vector{Float64} = $node_defaults[:max_supply]
        non_served_demand::JuMPVariable = Matrix{VariableRef}(undef, 0, 0)
        policy_budgeting_vars::Dict = Dict()
        policy_slack_vars::Dict = Dict()
        price::Vector{Float64} = Vector{Float64}()
        price_nsd::Vector{Float64} = $node_defaults[:price_nsd]
        price_supply::Vector{Float64} = $node_defaults[:price_supply]
        price_unmet_policy::Dict{DataType,Float64} = Dict{DataType,Float64}()
        rhs_policy::Dict{DataType,Float64} = Dict{DataType,Float64}()
        supply_flow::JuMPVariable = Matrix{VariableRef}(undef, 0, 0)
    end)
end

"""
    Node{T} <: AbstractVertex

    A mutable struct representing a node in a network, parameterized by commodity type T.

    # Inherited Attributes
    - id::Symbol: Unique identifier for the node
    - timedata::TimeData: Time-related data for the node
    - balance_data::Dict{Symbol,Dict{Symbol,Float64}}: Balance equations data
    - constraints::Vector{AbstractTypeConstraint}: List of constraints applied to the node
    - operation_expr::Dict: Operational JuMP expressions for the node

    # Fields
    - demand::Union{Vector{Float64},Dict{Int64,Float64}}: Time series of demand values
    - max_nsd::Vector{Float64}: Maximum allowed non-served demand for each segment
    - max_supply::Vector{Float64}: Maximum supply for each segment
    - non_served_demand::Union{JuMPVariable,Matrix{Float64}}: JuMP variables or matrix representing unmet demand
    - policy_budgeting_vars::Dict: Policy budgeting variables for constraints
    - policy_slack_vars::Dict: Policy slack variables for constraints
    - price::Union{Vector{Float64},Dict{Int64,Float64}}: Time series of prices
    - price_nsd::Vector{Float64}: Penalties for non-served demand by segment
    - price_supply::Vector{Float64}: Supply costs by segment
    - price_unmet_policy::Dict{DataType,Float64}: Mapping of policy types to penalty costs
    - rhs_policy::Dict{DataType,Float64}: Mapping of policy types to right-hand side values
    - supply_flow::Union{JuMPVariable,Matrix{Float64}}: JuMP variables or matrix representing supply flows

    Note: Base attributes are inherited from AbstractVertex via @AbstractVertexBaseAttributes macro.
"""
Base.@kwdef mutable struct Node{T} <: AbstractVertex
    @AbstractVertexBaseAttributes()
    @AbstractNodeBaseAttributes()
end

function make_node(data::AbstractDict{Symbol,Any}, time_data::TimeData, commodity::DataType)
    node_kwargs = Base.fieldnames(Node)
    filtered_data = Dict{Symbol, Any}(
        k => v for (k,v) in data if k in node_kwargs
    )
    id = Symbol(data[:id])
    remove_keys = [:id, :timedata]
    for key in remove_keys
        if haskey(filtered_data, key)
            delete!(filtered_data, key)
        end
    end
    _node = Node{commodity}(;
        id = id,
        timedata = time_data,
        demand = get(data, :demand, Vector{Float64}()),
        max_nsd = get(data, :max_nsd, [0.0]),
        max_supply = get(data, :max_supply, [0.0]),
        price = get(data, :price, Vector{Float64}()),
        price_nsd = get(data, :price_nsd, [0.0]),
        price_supply = get(data, :price_supply, [0.0]),
        price_unmet_policy = get(data, :price_unmet_policy, Dict{DataType,Float64}()),
        rhs_policy = get(data, :rhs_policy, Dict{DataType,Float64}())
        # filtered_data...
    )
    
    # add_constraints!(_node, data)
    return _node
end
Node(data::AbstractDict{Symbol,Any}, time_data::TimeData, commodity::DataType) =
    make_node(data, time_data, commodity)

######### Node interface #########
commodity_type(n::Node{T}) where {T} = T;
demand(n::Node) = n.demand;
# demand(n::Node, t::Int64) = length(demand(n)) == 1 ? demand(n)[1] : demand(n)[t];
function demand(n::Node, t::Int64)
    d = demand(n)
    if isempty(d)
        return 0.0
    elseif length(d) == 1 
        return d[1]
    else
        return d[t]
    end
end
max_non_served_demand(n::Node) = n.max_nsd;
max_non_served_demand(n::Node, s::Int64) = max_non_served_demand(n)[s];
non_served_demand(n::Node) = n.non_served_demand;
non_served_demand(n::Node, s::Int64, t::Int64) = non_served_demand(n)[s, t];
policy_budgeting_vars(n::Node) = n.policy_budgeting_vars;
policy_slack_vars(n::Node) = n.policy_slack_vars;
price(n::Node) = n.price;
price(n::Node, t::Int64) = length(price(n)) == 1 ? price(n)[1] : price(n)[t];
price_non_served_demand(n::Node) = n.price_nsd;
price_non_served_demand(n::Node, s::Int64) = price_non_served_demand(n)[s];
price_unmet_policy(n::Node) = n.price_unmet_policy;
price_unmet_policy(n::Node, c::DataType) = price_unmet_policy(n)[c];
rhs_policy(n::Node) = n.rhs_policy;
rhs_policy(n::Node, c::DataType) = rhs_policy(n)[c];
segments_non_served_demand(n::Node) = 1:length(n.max_nsd);
supply_flow(n::Node) = n.supply_flow;
supply_flow(n::Node, s::Int64, t::Int64) = supply_flow(n)[s, t];
supply_segments(n::Node) = eachindex(n.max_supply);
max_supply(n::Node) = n.max_supply;
max_supply(n::Node,s::Int64) = n.max_supply[s];
price_supply(n::Node,s::Int64) = n.price_supply[s];
######### Node interface #########


function add_linking_variables!(n::Node, model::Model)

    if any(isa.(n.constraints, PolicyConstraint))
        ct_all = findall(isa.(n.constraints, PolicyConstraint))
        for ct in ct_all

            ct_type = typeof(n.constraints[ct])
            n.policy_budgeting_vars[Symbol(string(ct_type) * "_Budget")] = @variable(
                model,
                [w in subperiod_indices(n)],
                base_name = "v" * string(ct_type) * "_Budget_$(id(n))_period$(period_index(n))"
            )
        end
    end

end

function define_available_capacity!(n::Node, model::Model)
    return nothing
end

function planning_model!(n::Node, model::Model)

    ### DEFAULT CONSTRAINTS ###

    if any(isa.(n.constraints, PolicyConstraint))
        ct_all = findall(isa.(n.constraints, PolicyConstraint))
        for ct in ct_all
            ct_type = typeof(n.constraints[ct])
            @constraint(
                model,
                sum(n.policy_budgeting_vars[Symbol(string(ct_type) * "_Budget")]) ==
                rhs_policy(n, ct_type)
            )
        end
    end
    return nothing
end

function operation_model!(n::Node, model::Model)

    if !isempty(balance_ids(n))
        for i in balance_ids(n)
            if i == :demand
                n.operation_expr[:demand] = @expression(
                    model,
                    [t in time_interval(n)],
                    -demand(n, t) * model[:vREF]
                )
            else
                n.operation_expr[i] =
                    @expression(model, [t in time_interval(n)], 0 * model[:vREF])
            end
        end
    end

    if !all(max_non_served_demand(n) .== 0)
        n.non_served_demand = @variable(
            model,
            [s in segments_non_served_demand(n), t in time_interval(n)],
            lower_bound = 0.0,
            base_name = "vNSD_$(id(n))_period$(period_index(n))"
        )
        for t in time_interval(n)
            w = current_subperiod(n,t)
            for s in segments_non_served_demand(n)
                add_to_expression!(
                    model[:eVariableCost],
                    subperiod_weight(n, w) * price_non_served_demand(n, s),
                    non_served_demand(n, s, t),
                )
                add_to_expression!(get_balance(n, :demand, t), non_served_demand(n, s, t))
            end
        end
    end

    if !all(max_supply(n) .== 0)

        n.supply_flow = @variable(
            model,
            [s in supply_segments(n) ,t in time_interval(n)],
            lower_bound = 0.0,
            upper_bound = max_supply(n,s),
            base_name = "vSUPPLY_$(id(n))_period$(period_index(n))"
        )

        for t in time_interval(n)
            w = current_subperiod(n,t)
            for s in supply_segments(n)

                add_to_expression!(model[:eVariableCost], subperiod_weight(n,w)*price_supply(n,s), supply_flow(n,s,t))

                add_to_expression!(get_balance(n, :demand, t), supply_flow(n, s, t))
            end
        end

    end

    return nothing
end


function get_nodes_sametype(nodes::Vector{Node}, commodity::DataType)
    return filter(n -> commodity_type(n) == commodity, nodes)
end

# Function to make a node. 
# This is called when the "Type" of the object is a commodity
# We can do:
#   Commodity -> Node{Commodity}

function make(commodity::Type{<:Commodity}, input_data::AbstractDict{Symbol,Any}, system)

    input_data = recursive_merge(clear_dict(node_default_data()), input_data)
    defaults = node_default_data()

    @process_data(data, input_data, [(input_data, key)])

    node = Node(data, system.time_data[typesymbol(commodity)], commodity)

    #### Note that not all nodes have a balance constraint, e.g., a NG source node does not have one. So the default should be empty.
    node.constraints = get(data, :constraints, Vector{AbstractTypeConstraint}())

    if any(isa.(node.constraints, BalanceConstraint))
        node.balance_data =
            get(data, :balance_data, Dict(:demand => Dict{Symbol,Float64}()))
    elseif any(isa.(node.constraints, CO2CapConstraint))
        node.balance_data =
            get(data, :balance_data, Dict(:emissions => Dict{Symbol,Float64}()))
    elseif any(isa.(node.constraints, CO2StorageConstraint))
        node.balance_data =
            get(data, :balance_data, Dict(:co2_storage => Dict{Symbol,Float64}()))
    else
        node.balance_data =
            get(data, :balance_data, Dict(:exogenous => Dict{Symbol,Float64}()))
    end

    if haskey(data, :location)
        location_id = data[:location]
        @debug "Adding node $(node.id) to location $location_id"
        location = find_locations(system, Symbol(location_id))
        if isnothing(location) && system.settings.AutoCreateLocations
            @info(" ++ Creating new location: $(location_id)")
            location = Location(;id=Symbol(location_id), system=system)
            push!(system.locations, location)
        end
        if isnothing(location)
            @warn("Location $(location_id) not found and AutoCreateLocations = false.\nNot adding node $(node.id) to any location.")
        else
            add_node!(location, node)
        end
    end

    return node
end