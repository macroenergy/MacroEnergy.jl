macro AbstractNodeBaseAttributes()
    node_defaults = node_default_data()
    esc(quote
        demand::Vector{Float64} = Vector{Float64}()
        min_nsd::Vector{Float64} = $node_defaults[:min_nsd]
        max_nsd::Vector{Float64} = $node_defaults[:max_nsd]
        non_served_demand::JuMPVariable = Matrix{VariableRef}(undef, 0, 0)
        policy_budgeting_vars::Dict = Dict()
        policy_budgeting_constraints::Dict{DataType,JuMPConstraint} = Dict{DataType,JuMPConstraint}()  # Store policy budget constraint references
        policy_slack_vars::Dict = Dict()
        price::Vector{Float64} = Vector{Float64}()
        price_nsd::Vector{Float64} = $node_defaults[:price_nsd]
        price_unmet_policy::Dict{DataType,Float64} = Dict{DataType,Float64}()
        rhs_policy::Dict{DataType,Float64} = Dict{DataType,Float64}()
        supply::OrderedDict{Symbol,SupplySegment} = $node_defaults[:supply]
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
    - non_served_demand::Union{JuMPVariable,Matrix{Float64}}: JuMP variables or matrix representing unmet demand
    - policy_budgeting_vars::Dict: Policy budgeting variables for constraints
    - policy_budgeting_constraints::Dict{DataType,JuMPConstraint}: Policy budget constraint references (sum across subperiods, keyed by :ConstraintType)
    - policy_slack_vars::Dict: Policy slack variables for constraints
    - price::Union{Vector{Float64},Dict{Int64,Float64}}: Time series of prices
    - price_nsd::Vector{Float64}: Penalties for non-served demand by segment
    - price_unmet_policy::Dict{DataType,Float64}: Mapping of policy types to penalty costs
    - rhs_policy::Dict{DataType,Float64}: Mapping of policy types to right-hand side values
    - supply::OrderedDict{Symbol,SupplySegment}: Supply segments keyed by segment name, each storing price, minimum, and maximum supply vectors
    - supply_flow::Union{JuMPVariable,Matrix{Float64}}: JuMP variables or matrix representing supply flows

    Note: Base attributes are inherited from AbstractVertex via @AbstractVertexBaseAttributes macro.
"""
Base.@kwdef mutable struct Node{T} <: AbstractVertex
    @AbstractVertexBaseAttributes()
    @AbstractNodeBaseAttributes()
end

commodity_type(::Type{Node{T}}) where {T} = T
function commodity_type(t::Type{Node{<:T}}) where {T}
    ub_type = t.var.ub
    return commodity_type(Node{ub_type})
end

function make_node(data::AbstractDict{Symbol,Any}, time_data::TimeData, commodity::DataType)
    node_data = copy(data)
    supply = get(node_data, :supply, OrderedDict{Symbol,SupplySegment}())

    node_kwargs = Base.fieldnames(Node)
    filtered_data = Dict{Symbol, Any}(
        k => v for (k,v) in node_data if k in node_kwargs
    )
    id = Symbol(node_data[:id])
    remove_keys = [:id, :timedata]
    for key in remove_keys
        if haskey(filtered_data, key)
            delete!(filtered_data, key)
        end
    end
    _node = Node{commodity}(;
        id = id,
        timedata = time_data,
        demand = get(node_data, :demand, Vector{Float64}()),
        location = as_symbol_or_missing(get(node_data, :location, missing)),
        max_nsd = get(node_data, :max_nsd, [0.0]),
        price = get(node_data, :price, Vector{Float64}()),
        price_nsd = get(node_data, :price_nsd, [0.0]),
        price_unmet_policy = get(node_data, :price_unmet_policy, Dict{DataType,Float64}()),
        rhs_policy = get(node_data, :rhs_policy, Dict{DataType,Float64}()),
        supply = supply,
        filtered_data...
    )    
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
policy_budgeting_constraints(n::Node) = n.policy_budgeting_constraints;
policy_budgeting_constraints(n::Node, c::DataType) = policy_budgeting_constraints(n)[c]
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
supply(n::Node) = n.supply;
supply_segment_names(n::Node) = collect(keys(supply(n)));
supply_segment_name(n::Node, s::Int64) = supply_segment_names(n)[s];
supply_segments(n::Node) = eachindex(supply_segment_names(n));
min_supply(n::Node) = [segment.min for segment in values(supply(n))];
min_supply(n::Node, segment_name::Symbol) = get(supply(n), segment_name, SupplySegment(price=Float64[], min=[0.0], max=[Inf])).min;
min_supply(n::Node,s::Int64) = min_supply(n, supply_segment_name(n, s));
min_supply(n::Node, s::Int64, t::Int64) = length(min_supply(n, s)) == 1 ? min_supply(n, s)[1] : min_supply(n, s)[t];
max_supply(n::Node) = [segment.max for segment in values(supply(n))];
max_supply(n::Node, segment_name::Symbol) = supply(n)[segment_name].max;
max_supply(n::Node,s::Int64) = max_supply(n, supply_segment_name(n, s));
max_supply(n::Node, s::Int64, t::Int64) = length(max_supply(n, s)) == 1 ? max_supply(n, s)[1] : max_supply(n, s)[t];
price_supply(n::Node, segment_name::Symbol) = supply(n)[segment_name].price;
price_supply(n::Node,s::Int64) = price_supply(n, supply_segment_name(n, s));
price_supply(n::Node,s::Int64,t::Int64) = length(price_supply(n, s)) == 1 ? price_supply(n, s)[1] : price_supply(n, s)[t];
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

    add_uservariables!(n, model, false)

    ### DEFAULT CONSTRAINTS ###

    if any(isa.(n.constraints, PolicyConstraint))
        ct_all = findall(isa.(n.constraints, PolicyConstraint))
        for ct in ct_all
            ct_type = typeof(n.constraints[ct])
            n.policy_budgeting_constraints[ct_type] = @constraint(
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

    if !isempty(supply_segments(n))

        n.supply_flow = @variable(
            model,
            [s in supply_segments(n) ,t in time_interval(n)],
            lower_bound = 0.0,
            base_name = "vSUPPLY_$(id(n))_period$(period_index(n))"
        )

        for t in time_interval(n)
            w = current_subperiod(n,t)
            for s in supply_segments(n)
                sf = supply_flow(n, s, t)
                min_sf = min_supply(n, s, t)
                max_sf = max_supply(n, s, t)
                if isfinite(min_sf) && min_sf > 0.0
                    @constraint(model, sf >= min_sf)
                end
                if isfinite(max_sf)                    
                    @constraint(model, sf <= max_sf)
                end

                add_to_expression!(model[:eVariableCost], subperiod_weight(n,w) * price_supply(n,s,t), sf)

                add_to_expression!(get_balance(n, :demand, t), sf)
            end
        end
    end

    add_uservariables!(n, model, true)

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
    elseif any(isa.(node.constraints, AggregatedDemandConstraint))
        node.balance_data =
            get(data, :balance_data, Dict(:demand_flow => Dict{Symbol,Float64}()))
    else
        node.balance_data =
            get(data, :balance_data, Dict(:exogenous => Dict{Symbol,Float64}()))
    end

    if haskey(data, :location) && data[:location] !== Symbol("")
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