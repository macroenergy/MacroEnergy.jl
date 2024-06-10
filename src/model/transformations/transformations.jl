macro AbstractTransformationEdgeBaseAttributes()
    esc(quote
        id::Symbol
        node::AbstractNode{T}
        transformation::AbstractTransform
        timedata::TimeData{T}
        direction::Symbol = :input
        has_planning_variables::Bool = false
        can_retire::Bool = false
        can_expand::Bool = false 
        capacity_size::Float64 = 1.0
        capacity_factor::Vector{Float64} = Float64[]
        st_coeff::Dict{Symbol,Float64} = Dict{Symbol,Float64}()
        min_capacity::Float64 = 0.0
        max_capacity::Float64 = Inf
        existing_capacity::Float64 = 0.0
        investment_cost::Float64 = 0.0
        fixed_om_cost::Float64 = 0.0
        variable_om_cost::Float64 = 0.0
        price::Union{Vector{Float64},Dict{Int64,Float64}} = Float64[]
        price_header::Union{Nothing,Symbol} = nothing
        ramp_up_fraction::Float64 = 1.0
        ramp_down_fraction::Float64 = 1.0
        min_flow_fraction::Float64 = 0.0
        planning_vars::Dict = Dict()
        operation_vars::Dict = Dict()
        constraints::Vector{AbstractTypeConstraint} = Vector{AbstractTypeConstraint}()
    end)
end

Base.@kwdef mutable struct TEdge{T} <: AbstractTransformationEdge{T}
    @AbstractTransformationEdgeBaseAttributes()
end

function make_tedge(::Type{TEdge}, data::Dict{Symbol,Any}, time_data::Dict{Symbol,TimeData}, transformation::AbstractTransform, node::AbstractNode)
    commodity = commodity_type(node)
    _t_edge = TEdge{commodity}(;
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
        price_header = get(data, :price_header, nothing),
        ramp_up_fraction = get(data, :ramp_up_fraction, 1.0),
        ramp_down_fraction = get(data, :ramp_down_fraction, 1.0),
        min_flow_fraction = get(data, :min_flow_fraction, 0.0),
    )
    add_constraints!(_t_edge, data)
    return _t_edge
end
TEdge(data::Dict{Symbol,Any}, time_data::Dict{Symbol,TimeData}, transformation::AbstractTransform, node::AbstractNode) = make_tedge(data, time_data, transformation, node)


function make_tedge(data::Dict{Symbol,Any}, time_data::Dict{Symbol,TimeData}, transformation::AbstractTransform, node::AbstractNode)
    validate_data!(data)
    if get(data, :uc, false)
        return make_tedge(TEdgeWithUC, data, time_data, transformation, node)
    else
        return make_tedge(TEdge, data, time_data, transformation, node)
    end
end

Base.@kwdef mutable struct Transformation <: AbstractTransform
    id::Symbol
    timedata::TimeData
    stoichiometry_balance_names::Vector{Symbol} = Vector{Symbol}()
    TEdges::Dict{Symbol,AbstractTransformationEdge} = Dict{Symbol,AbstractTransformationEdge}()
    operation_expr::Dict = Dict()
    planning_vars::Dict = Dict()
    operation_vars::Dict = Dict()
    constraints::Vector{AbstractTypeConstraint} = Vector{AbstractTypeConstraint}()
    min_capacity_storage::Float64 = 0.0
    max_capacity_storage::Float64 = Inf
    existing_capacity_storage::Float64 = 0.0
    can_expand::Bool = false
    can_retire::Bool = false
    investment_cost_storage::Float64 = 0.0
    fixed_om_cost_storage::Float64 = 0.0
    min_storage_level::Float64 = 0.0
    min_duration::Float64 = 0.0
    max_duration::Float64 = 0.0
    storage_loss_fraction::Float64 = 0.0
    discharge_edge::Symbol = :discharge
    charge_edge::Symbol = :charge
end

#### Transformation interface
stoichiometry_balance_names(g::AbstractTransform) = g.stoichiometry_balance_names;
has_storage(g::AbstractTransform) = :storage ∈ stoichiometry_balance_names(g);
get_id(g::AbstractTransform) = g.id;
time_interval(g::AbstractTransform) = g.timedata.time_interval;
subperiods(g::AbstractTransform) = g.timedata.subperiods;
subperiod_weight(g::AbstractTransform,w::StepRange{Int64, Int64}) = g.timedata.subperiod_weights[w];
current_subperiod(g::AbstractTransform,t::Int64) = subperiods(g)[findfirst(t .∈ subperiods(g))];
min_duration(g::AbstractTransform) = g.min_duration;
max_duration(g::AbstractTransform) = g.max_duration;

all_constraints(g::AbstractTransform) = g.constraints;
stoichiometry_balance(g::AbstractTransform) = g.operation_expr[:stoichiometry_balance];
stoichiometry_balance(g::AbstractTransform,i::Symbol,t::Int64) = stoichiometry_balance(g)[i,t];
edges(g::AbstractTransform) = g.TEdges;
existing_capacity_storage(g::AbstractTransform) = g.existing_capacity_storage;
new_capacity_storage(g::AbstractTransform) = g.planning_vars[:new_capacity_storage];
ret_capacity_storage(g::AbstractTransform) = g.planning_vars[:ret_capacity_storage];
capacity_storage(g::AbstractTransform) = g.planning_vars[:capacity_storage];
investment_cost_storage(g::AbstractTransform) = g.investment_cost_storage;
fixed_om_cost_storage(g::AbstractTransform) = g.fixed_om_cost_storage;
storage_level(g::AbstractTransform) = g.operation_vars[:storage_level];
storage_level(g::AbstractTransform,t::Int64) = storage_level(g)[t];
storage_loss_fraction(g::AbstractTransform) = g.storage_loss_fraction;

#### Transformation Edge interface
commodity_type(e::AbstractTransformationEdge{T}) where {T} = T;
time_interval(e::AbstractTransformationEdge) = e.timedata.time_interval;
subperiods(e::AbstractTransformationEdge) = e.timedata.subperiods;
subperiod_weight(e::AbstractTransformationEdge,w::StepRange{Int64, Int64}) = e.timedata.subperiod_weights[w];
current_subperiod(e::AbstractTransformationEdge,t::Int64) = subperiods(e)[findfirst(t .∈ subperiods(e))];

has_planning_variables(e::AbstractTransformationEdge) = e.has_planning_variables;
direction(e::AbstractTransformationEdge) = e.direction;
existing_capacity(e::AbstractTransformationEdge) = e.existing_capacity;
capacity_size(e::AbstractTransformationEdge) = e.capacity_size;
capacity_factor(e::AbstractTransformationEdge) = e.capacity_factor;
capacity_factor(e::AbstractTransformationEdge,t::Int64) = (isempty(capacity_factor(e)) == true) ? 1.0 : capacity_factor(e)[t];
investment_cost(e::AbstractTransformationEdge) = e.investment_cost;
fixed_om_cost(e::AbstractTransformationEdge) = e.fixed_om_cost;
variable_om_cost(e::AbstractTransformationEdge) = e.variable_om_cost;
price(e::AbstractTransformationEdge) = e.price;
price(e::AbstractTransformationEdge,t::Int64) = price(e)[t];
price_header(e::AbstractTransformationEdge) = e.price_header;
min_capacity(e::AbstractTransformationEdge) = e.min_capacity;
max_capacity(e::AbstractTransformationEdge) = e.max_capacity;
can_expand(e::AbstractTransformationEdge) = e.can_expand;
can_retire(e::AbstractTransformationEdge) = e.can_retire;
new_capacity(e::AbstractTransformationEdge) = e.planning_vars[:new_capacity];
ret_capacity(e::AbstractTransformationEdge) = e.planning_vars[:ret_capacity];
ramp_up_fraction(e::AbstractTransformationEdge) = e.ramp_up_fraction;
ramp_down_fraction(e::AbstractTransformationEdge) = e.ramp_down_fraction;
min_flow_fraction(e::AbstractTransformationEdge) = e.min_flow_fraction;
capacity(e::AbstractTransformationEdge) = e.planning_vars[:capacity];
flow(e::AbstractTransformationEdge) = e.operation_vars[:flow];
flow(e::AbstractTransformationEdge,t::Int64) = flow(e)[t];
all_constraints(e::AbstractTransformationEdge) = e.constraints;
node(e::AbstractTransformationEdge) = e.node;
stoichiometry_balance(e::AbstractTransformationEdge) = stoichiometry_balance(e.transformation);
stoichiometry_balance(e::AbstractTransformationEdge,i::Symbol,t::Int64) = stoichiometry_balance(e.transformation)[i,t];

stoichiometry_balance_names(e::AbstractTransformationEdge) = stoichiometry_balance_names(e.transformation);
get_transformation_id(e::AbstractTransformationEdge) = get_id(e.transformation);
get_id(e::AbstractTransformationEdge) = e.id;
st_coeff(e::AbstractTransformationEdge) = e.st_coeff;
transformation(e::AbstractTransformationEdge) = e.transformation;

function add_planning_variables!(g::AbstractTransform,model::Model)

    edges_vec = collect(values(edges(g)));
    add_planning_variables!.(edges_vec,model)

    if has_storage(g)
    
        g.planning_vars[:new_capacity_storage] = @variable(
            model,
            lower_bound = 0.0,
            base_name = "vNEWCAPSTOR_$(g.id)"
        )
    
        g.planning_vars[:ret_capacity_storage] = @variable(
            model,
            lower_bound = 0.0,
            base_name = "vRETCAPSTOR_$(g.id)"
        )
    
        g.planning_vars[:capacity_storage] = @variable(
            model,
            lower_bound = 0.0,
            base_name = "vCAPSTOR_$(g.id)"
        )
       
        @constraint(
            model,
            capacity_storage(g) ==
            new_capacity_storage(g) - ret_capacity_storage(g) + existing_capacity_storage(g)
        )
     
        @constraint(model, ret_capacity_storage(g) <= existing_capacity_storage(g))
    

        if !g.can_expand
            fix(new_capacity_storage(g), 0.0; force = true)
        else
            add_to_expression!(model[:eFixedCost],investment_cost_storage(g), new_capacity_storage(g)) 
        end
    
        if !g.can_retire
            fix(ret_capacity_storage(g), 0.0; force = true)
        end
    
    
        if fixed_om_cost_storage(g)>0
            add_to_expression!(model[:eFixedCost],fixed_om_cost_storage(g), capacity_storage(g))
        end

        if max_duration(g) > 0

            e_discharge = g.TEdges[g.discharge_edge]

            @constraint(model, capacity_storage(g) <= max_duration(g) * capacity(e_discharge))

            if min_duration(g) > 0
                @constraint(model, capacity_storage(g) >= min_duration(g) * capacity(e_discharge))
            end
        end

    end

    return nothing
end

function add_operation_variables!(g::AbstractTransform,model::Model)

    if !isempty(stoichiometry_balance_names(g))
        g.operation_expr[:stoichiometry_balance] = @expression(model, [i in stoichiometry_balance_names(g), t in time_interval(g)], 0 * model[:vREF])
    end

    edges_vec = collect(values(edges(g)))
    add_operation_variables!.(edges_vec,model)

    if has_storage(g)
        g.operation_vars[:storage_level] = @variable(
            model,
            [t in time_interval(g)],
            lower_bound = 0.0,
            base_name = "vSTOR_$(g.id)"
        )
        for t in time_interval(g)
            add_to_expression!(
            stoichiometry_balance(g,:storage,t),
            storage_level(g,t) - (1 - storage_loss_fraction(g)) * storage_level(g,timestepbefore(t,1,subperiods(g))),
            )
        end

        e_discharge = g.TEdges[g.discharge_edge]
        @constraint(
            model,
            [t in time_interval(g)], 
            st_coeff(e_discharge)[:storage]*flow(e_discharge,t) <= storage_level(g,timestepbefore(t,1,subperiods(g))))

    end

end

function add_planning_variables!(e::AbstractTransformationEdge, model::Model)

    if has_planning_variables(e)

        e.planning_vars[:new_capacity] = @variable(
            model,
            lower_bound = 0.0,
            base_name = "vNEWCAP_$(get_transformation_id(e))_$(get_id(e))"
        )

        e.planning_vars[:ret_capacity] = @variable(
            model,
            lower_bound = 0.0,
            base_name = "vRETCAP_$(get_transformation_id(e))_$(get_id(e))"
        )

        e.planning_vars[:capacity] = @variable(
            model,
            lower_bound = 0.0,
            base_name = "vCAP_$(get_transformation_id(e))_$(get_id(e))"
        )

        ### This constraint is just to set the auxiliary capacity variable. Capacity variable could be an expression if we don't want to have this constraint.
        @constraint(
            model,
            capacity(e) == capacity_size(e)*(new_capacity(e) - ret_capacity(e)) + existing_capacity(e)
        )

        if !can_expand(e)
            fix(new_capacity(e), 0.0; force = true)
        else
            add_to_expression!(model[:eFixedCost], investment_cost(e)*capacity_size(e), new_capacity(e))
        end

        if !can_retire(e)
            fix(ret_capacity(e), 0.0; force = true)
        end

        if fixed_om_cost(e)>0
            add_to_expression!(model[:eFixedCost], fixed_om_cost(e), capacity(e))
        end
    end

    return nothing

end

function add_operation_variables!(e::AbstractTransformationEdge, model::Model)

    e.operation_vars[:flow] = @variable(
        model,
        [t in time_interval(e)],
        lower_bound = 0.0,
        base_name = "vFLOW_$(get_transformation_id(e))_$(get_id(e))"
    )

    dir_coeff =  (direction(e) == :input) ? -1 : (direction(e) == :output) ? 1 : error("Invalid TEdge direction")

    e_st_coeff = st_coeff(e);
    
    e_node = node(e);

    directional_flow = dir_coeff * flow(e);

    add_to_expression!.(net_balance(e_node),directional_flow)

    for t in time_interval(e)

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

    end

    return nothing
end

function add_constraints!(target::T, data::Dict{Symbol,Any}) where T<:Union{Node, Edge, AbstractAsset, AbstractTransform, AbstractTransformationEdge}
    constraints = get(data, :constraints, nothing)
    if constraints !== nothing
        macro_constraints = constraint_types()
        for (k,v) in constraints
            v == true && add_constraint!(target, macro_constraints[k])
        end
    end
    return nothing
end

function add_planning_variables!(a::AbstractAsset, model::Model)
    for t in fieldnames(a)
        if isa(getfield(a,t), AbstractTransform)
            add_planning_variables!(getfield(a,t), model)
        end
    end
    return nothing
end

function add_operation_variables!(a::AbstractAsset, model::Model)
    for t in fieldnames(a)
        if isa(getfield(a,t), AbstractTransform)
            add_operation_variables!(getfield(a,t), model)
        end
    end
    return nothing
end

function add_constraint!(a::AbstractAsset, c::Type{<:AbstractTypeConstraint})
    for t in fieldnames(a)
        add_constraint!(getfield(a,t), c())
    end
    return nothing
end

function add_constraint!(t::T, c::Type{<:AbstractTypeConstraint}) where T<:Union{Node, Edge, AbstractTransform, AbstractTransformationEdge}
    push!(t.constraints, c())
    return nothing
end

function add_all_model_constraints!(a::AbstractAsset, model::Model)
    for t in fieldnames(a)
        add_all_model_constraints!(getfield(a,t), model)
    end
    return nothing
end

function fieldnames(a::AbstractAsset)
    ordered_fields = Symbol[]
    fields = Base.fieldnames(typeof(a))
    # move edge fields to the front
    for f in fields
        if isa(getfield(a, f), AbstractTransformationEdge)
            push!(ordered_fields, f)
        end
    end
    # move transformation fields to the back
    for f in fields
        if isa(getfield(a, f), AbstractTransform)
            push!(ordered_fields, f)
        end
    end
    # check if all fields are accounted for
    if length(ordered_fields) != length(fields)
        error("Not all fields accounted for in fieldnames(::Type{<:AbstractAsset})")
    end
    return ordered_fields
end

function tedges(assets::Dict{Symbol,AbstractAsset})
    tedges = Dict{Symbol,AbstractTransformationEdge}()
    for (k, v) in assets
        for f in fieldnames(v)
            if isa(getfield(v, f), AbstractTransformationEdge)
                tedges[Symbol(string(k, "_", f))] = getfield(v, f)
            end
        end
    end
    return tedges
end 

function Base.show(io::IO, g::AbstractTransform)
    println(io, "Transformation id: $(g.id)")
    # edges ids
    print(io, "Edges: [")
    print(io, join([string(":",get_id(e)) for e in values(edges(g))], ", "))
    println(io, "]")
    println(io, "Time data: $(g.timedata)")
    println(io, "stoichiometry_balance_names: $(stoichiometry_balance_names(g))")
    println(io, "Existing capacity storage: $(existing_capacity_storage(g))")
    println(io, "Min capacity storage: $(g.min_capacity_storage)")
    println(io, "Max capacity storage: $(g.max_capacity_storage)")
    println(io, "Can expand: $(g.can_expand)")
    println(io, "Can retire: $(g.can_retire)")
    println(io, "Investment cost storage: $(g.investment_cost_storage)")
    println(io, "Fixed OM cost storage: $(g.fixed_om_cost_storage)")
    println(io, "Min storage level: $(g.min_storage_level)")
    println(io, "Min duration: $(g.min_duration)")
    println(io, "Max duration: $(g.max_duration)")
    println(io, "Storage loss fraction: $(g.storage_loss_fraction)")
    println(io, "Discharge edge: :$(g.discharge_edge)")
    println(io, "Charge edge: :$(g.charge_edge)")
    
    println(io, "Planning variables: $(g.planning_vars)")
    println(io, "Operation variables: $(g.operation_vars)")
    println(io, "Constraints: $(g.constraints)")
end

function Base.show(io::IO, e::AbstractTransformationEdge)
    println(io, "TEdge id: $(e.id)")
    println(io, "TEdge type: $(typeof(e))")
    println(io, "Commodity type: $(commodity_type(e))")
    println(io, "Node: $(get_id(node(e)))")
    println(io, "Transformation id: $(get_id(transformation(e)))")
    println(io, "Time data: $(e.timedata)")
    println(io, "Direction: $(direction(e))")
    println(io, "Has planning variables: $(has_planning_variables(e))")
    println(io, "Can retire: $(can_retire(e))")
    println(io, "Can expand: $(can_expand(e))")
    println(io, "Capacity size: $(capacity_size(e))")
    println(io, "Capacity factor: $(capacity_factor(e))")
    println(io, "Stoichiometry coefficients: $(st_coeff(e))")
    println(io, "Min capacity: $(min_capacity(e))")
    println(io, "Max capacity: $(max_capacity(e))")
    println(io, "Existing capacity: $(existing_capacity(e))")
    println(io, "Investment cost: $(investment_cost(e))")
    println(io, "Fixed OM cost: $(fixed_om_cost(e))")
    println(io, "Variable OM cost: $(variable_om_cost(e))")
    println(io, "Price: $(price(e))")
    println(io, "Price header: $(price_header(e))")
    println(io, "Ramp up fraction: $(ramp_up_fraction(e))")
    println(io, "Ramp down fraction: $(ramp_down_fraction(e))")
    println(io, "Min flow fraction: $(min_flow_fraction(e))")
    if isa(e, TEdgeWithUC)
        println(io, "Min up time: $(min_up_time(e))")
        println(io, "Min down time: $(min_down_time(e))")
        println(io, "Start cost: $(start_cost(e))")
        println(io, "Start fuel: $(start_fuel(e))")
        println(io, "Start fuel stoichiometry name: :$(start_fuel_stoichiometry_name(e))")
    end
    println(io, "Planning variables: $(e.planning_vars)")
    println(io, "Operation variables: $(e.operation_vars)")
    println(io, "Constraints: $(e.constraints)")
end

function Base.show(io::IO, a::AbstractAsset)
    for f in fieldnames(a)
        println(io, "Field: $f")
        println(io, getfield(a, f))
    end
end