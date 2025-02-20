macro AbstractEdgeBaseAttributes()
    edge_defaults = edge_default_data()
    esc(quote
        id::Symbol
        timedata::TimeData{T}
        start_vertex::AbstractVertex
        end_vertex::AbstractVertex
        availability::Vector{Float64} = Float64[]
        can_expand::Bool = $edge_defaults[:can_expand]
        can_retire::Bool = $edge_defaults[:can_retire]
        capacity::AffExpr = AffExpr(0.0)
        capacity_size::Float64 = $edge_defaults[:capacity_size]
        capital_recovery_period::Int64 = $edge_defaults[:capital_recovery_period]
        constraints::Vector{AbstractTypeConstraint} = Vector{AbstractTypeConstraint}()
        distance::Float64 = $edge_defaults[:distance]
        existing_capacity::Float64 = $edge_defaults[:existing_capacity]
        fixed_om_cost::Float64 = $edge_defaults[:fixed_om_cost]
        flow::JuMPVariable = Vector{VariableRef}()
        has_capacity::Bool = $edge_defaults[:has_capacity]
        integer_decisions::Bool = $edge_defaults[:integer_decisions]
        investment_cost::Float64 = $edge_defaults[:investment_cost]
        lifetime::Int64 = $edge_defaults[:lifetime]
        loss_fraction::Float64 = $edge_defaults[:loss_fraction]
        max_capacity::Float64 = $edge_defaults[:max_capacity]
        min_capacity::Float64 = $edge_defaults[:min_capacity]
        min_flow_fraction::Float64 = $edge_defaults[:min_flow_fraction]
        new_capacity::AffExpr = AffExpr(0.0)
        new_capacity_track::Dict{Int64,AffExpr} = Dict(1 => AffExpr(0.0))
        new_units::Union{JuMPVariable,Float64} = 0.0
        ramp_down_fraction::Float64 = $edge_defaults[:ramp_down_fraction]
        ramp_up_fraction::Float64 = $edge_defaults[:ramp_up_fraction]
        retired_capacity::AffExpr = AffExpr(0.0)
        retired_capacity_track::Dict{Int64,AffExpr} = Dict(1 => AffExpr(0.0))
        retired_units::Union{JuMPVariable,Float64} = 0.0
        unidirectional::Bool = $edge_defaults[:unidirectional]
        variable_om_cost::Float64 = $edge_defaults[:variable_om_cost]
        min_down_time::Int64 = $edge_defaults[:min_down_time]
        min_up_time::Int64 = $edge_defaults[:min_up_time]
        startup_cost::Float64 = $edge_defaults[:startup_cost]
        startup_fuel_consumption::Float64 = $edge_defaults[:startup_fuel_consumption]
        startup_fuel_balance_id::Symbol = $edge_defaults[:startup_fuel_balance_id]
        retirement_stage::Int64 = $edge_defaults[:retirement_stage]
        wacc::Float64 = $edge_defaults[:wacc]
    end)
end
Base.@kwdef mutable struct Edge{T} <: AbstractEdge{T}
    @AbstractEdgeBaseAttributes()
end

function target_is_valid(commodity::Type{<:Commodity}, target::T) where T<:Union{Node, AbstractStorage}
    if commodity <: commodity_type(target)
        return true
    end
    return false
end

function target_is_valid(commodity::Type{<:Commodity}, target)
    return true
end

function target_is_valid(edge::AbstractEdge, target::AbstractVertex)
    return target_is_valid(commodity_type(edge), target)
end

function make_edge(
    id::Symbol,
    data::AbstractDict{Symbol,Any},
    time_data::TimeData,
    commodity::DataType,
    start_vertex::AbstractVertex,
    end_vertex::AbstractVertex,
)
    if !(target_is_valid(commodity, start_vertex))
        error("Edge $id cannot be connected to its start vertex, $(start_vertex.id).\nThey have different commodities\n$id is a $commodity edge.\n$(start_vertex.id) is a $(commodity_type(start_vertex)) vertex.")
    elseif !target_is_valid(commodity, end_vertex)
        error("Edge $id cannot be connected to its end vertex, $(end_vertex.id).\nThey have different commodities\n$id is a $commodity edge.\n$(end_vertex.id) is a $(commodity_type(end_vertex)) vertex.")
    end

    edge_kwargs = Base.fieldnames(Edge)
    filtered_data = Dict{Symbol, Any}(
        k => v for (k,v) in data if k in edge_kwargs
    )
    remove_keys = [:id, :start_vertex, :end_vertex, :timedata]
    for key in remove_keys
        if haskey(filtered_data, key)
            delete!(filtered_data, key)
        end
    end
    _edge = Edge{commodity}(;
        id = id,
        timedata = time_data,
        start_vertex = start_vertex,
        end_vertex = end_vertex,
        filtered_data...
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


# Function to filter edges with capacity variables from a Vector of edges.
edges_with_capacity_variables(edges::Vector{<:AbstractEdge}) =
    AbstractEdge[edge for edge in edges if has_capacity(edge)]

######### Edge interface #########
all_constraints(e::AbstractEdge) = e.constraints;
availability(e::AbstractEdge) = e.availability;
function availability(e::AbstractEdge, t::Int64)
    a = availability(e)
    if isempty(a)
        return 1.0
    elseif length(a) == 1
        return a[1]
    else
        return a[t]
    end
end
can_expand(e::AbstractEdge) = e.can_expand;
can_retire(e::AbstractEdge) = e.can_retire;
capacity(e::AbstractEdge) = e.capacity;
capacity_size(e::AbstractEdge) = e.capacity_size;
capital_recovery_period(e::AbstractEdge) = e.capital_recovery_period;
commodity_type(e::AbstractEdge{T}) where {T} = T;
end_vertex(e::AbstractEdge) = e.end_vertex;
existing_capacity(e::AbstractEdge) = e.existing_capacity;
fixed_om_cost(e::AbstractEdge) = e.fixed_om_cost;
flow(e::AbstractEdge) = e.flow;
flow(e::AbstractEdge, t::Int64) = flow(e)[t];
has_capacity(e::AbstractEdge) = e.has_capacity;
id(e::AbstractEdge) = e.id;
integer_decisions(e::AbstractEdge) = e.integer_decisions;
investment_cost(e::AbstractEdge) = e.investment_cost;
lifetime(e::AbstractEdge) = e.lifetime;
loss_fraction(e::AbstractEdge) = e.loss_fraction;
max_capacity(e::AbstractEdge) = e.max_capacity;
min_capacity(e::AbstractEdge) = e.min_capacity;
min_flow_fraction(e::AbstractEdge) = e.min_flow_fraction;
new_capacity(e::AbstractEdge) = e.new_capacity;
new_capacity_track(e::AbstractEdge) = e.new_capacity_track;
#### Note that edge "e" may not be present in the inputs for all stages
new_capacity_track(e::AbstractEdge,s::Int64) =  (haskey(new_capacity_track(e),s) == false) ? 0.0 : e.new_capacity_track[s];
new_units(e::AbstractEdge) = e.new_units;
ramp_down_fraction(e::AbstractEdge) = e.ramp_down_fraction;
ramp_up_fraction(e::AbstractEdge) = e.ramp_up_fraction;
retired_capacity(e::AbstractEdge) = e.retired_capacity;
retired_capacity_track(e::AbstractEdge) = e.retired_capacity_track;
#### Note that edge "e" may not be present in the inputs for all stages
retired_capacity_track(e::AbstractEdge,s::Int64) =  (haskey(retired_capacity_track(e),s) == false) ? 0.0 : e.retired_capacity_track[s];
retired_units(e::AbstractEdge) = e.retired_units;
retirement_stage(e::AbstractEdge) = e.retirement_stage;
start_vertex(e::AbstractEdge)::AbstractVertex = e.start_vertex;
variable_om_cost(e::AbstractEdge) = e.variable_om_cost;
wacc(e::AbstractEdge) = e.wacc;
##### End of Edge interface #####


function add_linking_variables!(e::AbstractEdge, model::Model)

    if has_capacity(e)
        e.new_units = @variable(model, lower_bound = 0.0, base_name = "vNEWUNIT_$(id(e))_stage$(stage_index(e))")

        e.retired_units = @variable(model, lower_bound = 0.0, base_name = "vRETUNIT_$(id(e))_stage$(stage_index(e))")

        e.new_capacity = @expression(model, capacity_size(e) * new_units(e))
        
        e.retired_capacity = @expression(model, capacity_size(e) * retired_units(e))

        e.new_capacity_track[stage_index(e)] = new_capacity(e);
        
        e.retired_capacity_track[stage_index(e)] = retired_capacity(e);
    end

    return nothing

end

function define_available_capacity!(e::AbstractEdge,model::Model)

    if has_capacity(e)
        e.capacity = @expression(
            model,
            new_capacity(e) - retired_capacity(e) + existing_capacity(e)
        )
    end

    return nothing

end

function planning_model!(e::AbstractEdge, model::Model)

    if has_capacity(e)

        if !can_expand(e)
            fix(new_units(e), 0.0; force = true)
        else
            if integer_decisions(e)
                set_integer(new_units(e))
            end
            add_to_expression!(
                model[:eFixedCost],
                investment_cost(e),
                new_capacity(e),
            )
        end

        if !can_retire(e)
            fix(retired_units(e), 0.0; force = true)
        else
            if integer_decisions(e)
                set_integer(retired_units(e))
            end
        end

        if fixed_om_cost(e) > 0
            add_to_expression!(model[:eFixedCost], fixed_om_cost(e), capacity(e))
        end

        @constraint(model, retired_capacity(e) <= existing_capacity(e))

    end


    return nothing

end

function operation_model!(e::Edge, model::Model)

    if e.unidirectional
        e.flow = @variable(
            model,
            [t in time_interval(e)],
            lower_bound = 0.0,
            base_name = "vFLOW_$(id(e))_stage$(stage_index(e))"
        )
    else
        e.flow = @variable(model, [t in time_interval(e)], base_name = "vFLOW_$(id(e))_stage$(stage_index(e))")
    end

    update_balances!(e, model)

    for t in time_interval(e)
        w = current_subperiod(e,t)
        if variable_om_cost(e) > 0
            add_to_expression!(
                model[:eVariableCost],
                subperiod_weight(e, w) * variable_om_cost(e),
                flow(e, t),
            )
        end
        if isa(start_vertex(e),Node)
            if !isempty(price(start_vertex(e)))
                add_to_expression!(
                    model[:eVariableCost],
                    subperiod_weight(e, w) * price(start_vertex(e), t),
                    flow(e, t),
                )
            end
        end

    end

    return nothing
end

Base.@kwdef mutable struct EdgeWithUC{T} <: AbstractEdge{T}
    @AbstractEdgeBaseAttributes()
    ucommit::JuMPVariable = Vector{VariableRef}()
    ushut::JuMPVariable = Vector{VariableRef}()
    ustart::JuMPVariable = Vector{VariableRef}()
end

function make_edge_UC(
    id::Symbol,
    data::Dict{Symbol,Any},
    time_data::TimeData,
    commodity::DataType,
    start_vertex::AbstractVertex,
    end_vertex::AbstractVertex,
)

    if !(target_is_valid(commodity, start_vertex))
        error("Edge $id cannot be connected to its start vertex, $(start_vertex.id).\nThey have different commodities\n$id is a $commodity edge.\n$(start_vertex.id) is a $(commodity_type(start_vertex)) vertex.")
    elseif !target_is_valid(commodity, end_vertex)
        error("Edge $id cannot be connected to its end vertex, $(end_vertex.id).\nThey have different commodities\n$id is a $commodity edge.\n$(end_vertex.id) is a $(commodity_type(end_vertex)) vertex.")
    end

    edge_kwargs = Base.fieldnames(EdgeWithUC)
    filtered_data = Dict{Symbol,Any}(
        k => v for (k, v) in data if k in edge_kwargs
    )
    remove_keys = [:id, :start_vertex, :end_vertex, :timedata]
    for key in remove_keys
        if haskey(filtered_data, key)
            delete!(filtered_data, key)
        end
    end
    _edge = EdgeWithUC{commodity}(;
        id = id,
        timedata = time_data,
        start_vertex = start_vertex,
        end_vertex = end_vertex,
        filtered_data...,
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
startup_fuel_consumption(e::EdgeWithUC) = e.startup_fuel_consumption;
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
        base_name = "vFLOW_$(id(e))_stage$(stage_index(e))"
    )

    e.ucommit = @variable(
        model,
        [t in time_interval(e)],
        lower_bound = 0.0,
        base_name = "vCOMMIT_$(id(e))_stage$(stage_index(e))"
    )

    e.ustart = @variable(
        model,
        [t in time_interval(e)],
        lower_bound = 0.0,
        base_name = "vSTART_$(id(e))_stage$(stage_index(e))"
    )

    e.ushut = @variable(
        model,
        [t in time_interval(e)],
        lower_bound = 0.0,
        base_name = "vSHUT_$(id(e))_stage$(stage_index(e))"
    )

    update_balances!(e, model)

    update_startup_fuel_balance!(e)

    for t in time_interval(e)

        w = current_subperiod(e,t)
        if variable_om_cost(e) > 0
            add_to_expression!(
                model[:eVariableCost],
                subperiod_weight(e, w) * variable_om_cost(e),
                flow(e, t),
            )
        end

        if isa(start_vertex(e),Node)
            if !isempty(price(start_vertex(e)))
                add_to_expression!(
                    model[:eVariableCost],
                    subperiod_weight(e, w) * price(start_vertex(e), t),
                    flow(e, t),
                )
            end
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

function balance_data(e::AbstractEdge, v::AbstractVertex, i::Symbol)   

    if isempty(balance_data(v,i))
        return 1.0
    elseif id(e) ∈ keys(balance_data(v,i))
        return balance_data(v,i)[id(e)]
    else
        return 0.0
    end

end

function update_balances!(e::AbstractEdge, model::Model)

    update_balance_start!(e, model)

    update_balance_end!(e, model)

end

function update_startup_fuel_balance!(e::EdgeWithUC)

    # The startup fuel will not contribute to the end vertex balance as it is not consumed there.

    v = start_vertex(e);

    i = startup_fuel_balance_id(e)

    if i ∈ balance_ids(v)
        add_to_expression!.(get_balance(v, i), -1 * startup_fuel_consumption(e) * capacity_size(e) * ustart(e))
    end

    return nothing

end

function update_balance_start!(e::AbstractEdge, model::Model)

    v = start_vertex(e);

    if loss_fraction(e) == 0 || e.unidirectional == true

        effective_flow = @expression(model,[t in time_interval(e)], flow(e,t))
        
    else
        flow_pos = @variable(model, [t in time_interval(e)], lower_bound = 0.0, base_name = "vFLOWPOS_$(id(e))_stage$(stage_index(e))")
        flow_neg = @variable(model, [t in time_interval(e)], lower_bound = 0.0, base_name = "vFLOWNEG_$(id(e))_stage$(stage_index(e))")

        @constraint(model, [t in time_interval(e)], flow_pos[t] - flow_neg[t] == flow(e, t))

        if isa(e,EdgeWithUC)
            @constraint(model, [t in time_interval(e)], flow_pos[t] + flow_neg[t] <= availability(e, t) * capacity_size(e) * ucommit(e, t))
        else
            @constraint(model, [t in time_interval(e)], flow_pos[t] + flow_neg[t] <= availability(e, t) * capacity(e))
        end

        effective_flow = @expression(model, [t in time_interval(e)], flow_pos[t] - (1 - loss_fraction(e)) * flow_neg[t])
    end

    for i in balance_ids(v)
        add_to_expression!.(get_balance(v, i),  -1 * balance_data(e, v, i) * effective_flow)
    end
    

end

function update_balance_end!(e::AbstractEdge, model::Model)
    
    v = end_vertex(e);

    if loss_fraction(e) == 0 || e.unidirectional == true
        effective_flow = @expression(model, [t in time_interval(e)], flow(e,t))
    else
    
        flow_pos = @variable(model, [t in time_interval(e)], lower_bound = 0.0, base_name = "vFLOWPOS_$(id(e))_stage$(stage_index(e))")
        flow_neg = @variable(model, [t in time_interval(e)], lower_bound = 0.0, base_name = "vFLOWNEG_$(id(e))_stage$(stage_index(e))")

        @constraint(model, [t in time_interval(e)], flow_pos[t] - flow_neg[t] == flow(e, t))

        if isa(e,EdgeWithUC)
            @constraint(model, [t in time_interval(e)], flow_pos[t] + flow_neg[t] <= availability(e, t) * capacity_size(e) * ucommit(e, t))
        else
            @constraint(model, [t in time_interval(e)], flow_pos[t] + flow_neg[t] <= availability(e, t) * capacity(e))
        end

        effective_flow = @expression(model, [t in time_interval(e)], (1 - loss_fraction(e)) * flow_pos[t] - flow_neg[t])

    end

    for i in balance_ids(v)
        add_to_expression!.(get_balance(v, i),  balance_data(e, v, i) * effective_flow)
    end
    
end

###### Templates ######

macro edge_template_args()
    quote 
        [ 
            :id,
            :timedata,
            :start_vertex,
            :end_vertex,
            :availability,
            :can_expand,
            :can_retire,
            :capacity_size,
            :distance,
            :existing_capacity,
            :fixed_om_cost,
            :has_capacity,
            :integer_decisions,
            :investment_cost,
            :loss_fraction,
            :max_capacity,
            :min_capacity,
            :min_flow_fraction,
            :ramp_down_fraction,
            :ramp_up_fraction,
            :unidirectional,
            :variable_om_cost
        ]
    end
end

function input_template(e::AbstractEdge)
    template = Dict{Symbol,Any}()
    for sym in @edge_template_args
        if !hasproperty(e, sym)
            @debug "$(sym) not found in $(typeof(e)), $(id(e)))"
            continue
        end
        prop = getfield(e, sym)
        if typeof(prop) <: Real
            template[sym] = prop
        elseif typeof(prop) == Symbol
            template[sym] = ""
        elseif typeof(prop) <: Vector
            template[sym] = [0.0]
        end
    end
    return template
end