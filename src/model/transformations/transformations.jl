macro AbstractTransformationEdgeBaseAttributes()
    esc(quote
        id::Symbol
        node::AbstractNode{T}
        transformation::AbstractTransformation
        timedata::TimeData{T}
        direction::Symbol = :input
        has_planning_variables::Bool = false
        can_retire::Bool = false
        can_expand::Bool = false 
        capacity_size :: Float64 = 1.0
        capacity_factor::Vector{Float64} = Float64[]
        st_coeff::Dict{Symbol,Float64} = Dict{Symbol,Float64}()
        min_capacity::Float64 = 0.0
        max_capacity::Float64 = Inf
        existing_capacity::Float64 = 0.0
        investment_cost::Float64 = 0.0
        fixed_om_cost::Float64 = 0.0
        variable_om_cost::Float64 = 0.0
        price::Vector{Float64} = Float64[]
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

Base.@kwdef mutable struct Transformation{T} <: AbstractTransformation{T}
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
    discharge_edge::Symbol = Symbol(".")
    charge_edge::Symbol = Symbol(".")
end

#### Transformation interface
transformation_type(g::AbstractTransformation{T}) where {T} = T;
stoichiometry_balance_names(g::AbstractTransformation) = g.stoichiometry_balance_names;
has_storage(g::AbstractTransformation) = :storage ∈ stoichiometry_balance_names(g);
has_hydro(g::AbstractTransformation) = :hydro ∈ stoichiometry_balance_names(g);
has_hydrostor(g::Storage) = :hydrostor ∈ stoichiometry_balance_names(g);
get_id(g::AbstractTransformation) = g.id;
time_interval(g::AbstractTransformation) = g.timedata.time_interval;
subperiods(g::AbstractTransformation) = g.timedata.subperiods;
subperiod_weight(g::AbstractTransformation,w::StepRange{Int64, Int64}) = g.timedata.subperiod_weights[w];
current_subperiod(g::AbstractTransformation,t::Int64) = subperiods(g)[findfirst(t .∈ subperiods(g))];

all_constraints(g::AbstractTransformation) = g.constraints;
stoichiometry_balance(g::AbstractTransformation) = g.operation_expr[:stoichiometry_balance];
stoichiometry_balance(g::AbstractTransformation,i::Symbol,t::Int64) = stoichiometry_balance(g)[i,t];
edges(g::AbstractTransformation) = g.TEdges;
existing_capacity_storage(g::AbstractTransformation) = g.existing_capacity_storage;
new_capacity_storage(g::AbstractTransformation) = g.planning_vars[:new_capacity_storage];
ret_capacity_storage(g::AbstractTransformation) = g.planning_vars[:ret_capacity_storage];
capacity_storage(g::AbstractTransformation) = g.planning_vars[:capacity_storage];
investment_cost_storage(g::AbstractTransformation) = g.investment_cost_storage;
fixed_om_cost_storage(g::AbstractTransformation) = g.fixed_om_cost_storage;
storage_level(g::AbstractTransformation) = g.operation_vars[:storage_level];
storage_level(g::AbstractTransformation,t::Int64) = storage_level(g)[t];
storage_loss_fraction(g::AbstractTransformation) = g.storage_loss_fraction;

existing_capacity_hydro(g::AbstractTransformation) = g.existing_capacity_hydro;
new_capacity_hydro(g::AbstractTransformation) = g.planning_vars[:new_capacity_hydro];
ret_capacity_hydro(g::AbstractTransformation) = g.planning_vars[:ret_capacity_hydro];
capacity_hydro(g::AbstractTransformation) = g.planning_vars[:capacity_hydro];
investment_cost_hydro(g::AbstractTransformation) = g.investment_cost_hydro;
fixed_om_cost_hydro(g::AbstractTransformation) = g.fixed_om_cost_hydro;
hydro_level(g::AbstractTransformation) = g.operation_vars[:hydro_level];
hydro_level(g::AbstractTransformation,t::Int64) = hydro_level(g)[t];
hydro_loss_fraction(g::AbstractTransformation) = g.hydro_loss_fraction;

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


function add_planning_variables!(g::AbstractTransformation,model::Model)

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

        if g.max_duration > 0
    
            e_discharge = g.TEdges[g.discharge_edge];

            @constraint(model, capacity_storage(g) <= g.max_duration * capacity(e_discharge))

            if g.min_duration > 0
                @constraint(model, capacity_storage(g) >= g.min_duration * capacity(e_discharge))
            end

        end

    end


    if has_hydro(g)
    
        g.planning_vars[:new_capacity_hydro] = @variable(
            model,
            lower_bound = 0.0,
            base_name = "vNEWCAPHYDRO_$(g.id)"
        )
    
        g.planning_vars[:ret_capacity_hydro] = @variable(
            model,
            lower_bound = 0.0,
            base_name = "vRETCAPHYDRO_$(g.id)"
        )
    
        g.planning_vars[:capacity_hydro] = @variable(
            model,
            lower_bound = 0.0,
            base_name = "vCAPHYDRO_$(g.id)"
        )
       
        @constraint(
            model,
            capacity_hydro(g) ==
            new_capacity_hydro(g) - ret_capacity_hydro(g) + existing_capacity_hydro(g)
        )
     
        @constraint(model, ret_capacity_hydro(g) <= existing_capacity_hydro(g))
    

        if !g.can_expand
            fix(new_capacity_hydro(g), 0.0; force = true)
        else
            add_to_expression!(model[:eFixedCost],investment_cost_hydro(g), new_capacity_hydro(g)) 
        end
    
        if !g.can_retire
            fix(ret_capacity_hydro(g), 0.0; force = true)
        end
    
    
        if fixed_om_cost_hydro(g)>0
            add_to_expression!(model[:eFixedCost],fixed_om_cost_hydro(g), capacity_hydro(g))
        end

        if g.max_duration > 0
    
            e_discharge = g.TEdges[g.discharge_edge];

            @constraint(model, capacity_hydro(g) <= g.max_duration * capacity(e_discharge))

            if g.min_duration > 0
                @constraint(model, capacity_hydro(g) >= g.min_duration * capacity(e_discharge))
            end

        end

    end

end

function add_operation_variables!(g::AbstractTransformation,model::Model)

    if !isempty(stoichiometry_balance_names(g))
        g.operation_expr[:stoichiometry_balance] = @expression(model, [i in stoichiometry_balance_names(g), t in time_interval(g)], 0 * model[:vREF])
    end

    edges_vec = collect(values(edges(g)));

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
        @constraint(model,
        [t in time_interval(g)], 
        st_coeff(e_discharge)[:storage]*flow(e_discharge,t)<=storage_level(g,timestepbefore(t,1,subperiods(g))))

    end

end

function add_planning_variables!(g::Storage,model::Model)

    edges_vec = collect(values(edges(g)));

    add_planning_variables!.(edges_vec,model)

    if has_hydrostor(g)
    
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

        if g.max_duration > 0
    
            e_discharge = g.TEdges[g.discharge_edge];

            @constraint(model, capacity_storage(g) <= g.max_duration * capacity(e_discharge))

            if g.min_duration > 0
                @constraint(model, capacity_storage(g) >= g.min_duration * capacity(e_discharge))
            end

        end
    
        g.planning_vars[:new_capacity_hydro] = @variable(
            model,
            lower_bound = 0.0,
            base_name = "vNEWCAPHYDRO_$(g.id)"
        )
    
        g.planning_vars[:ret_capacity_hydro] = @variable(
            model,
            lower_bound = 0.0,
            base_name = "vRETCAPHYDRO_$(g.id)"
        )
    
        g.planning_vars[:capacity_hydro] = @variable(
            model,
            lower_bound = 0.0,
            base_name = "vCAPHYDRO_$(g.id)"
        )
       
        @constraint(
            model,
            capacity_hydro(g) ==
            new_capacity_hydro(g) - ret_capacity_hydro(g) + existing_capacity_hydro(g)
        )
     
        @constraint(model, ret_capacity_hydro(g) <= existing_capacity_hydro(g))
    

        if !g.can_expand
            fix(new_capacity_hydro(g), 0.0; force = true)
        else
            add_to_expression!(model[:eFixedCost],investment_cost_hydro(g), new_capacity_hydro(g)) 
        end
    
        if !g.can_retire
            fix(ret_capacity_hydro(g), 0.0; force = true)
        end
    
    
        if fixed_om_cost_hydro(g)>0
            add_to_expression!(model[:eFixedCost],fixed_om_cost_hydro(g), capacity_hydro(g))
        end

        if g.max_duration > 0
    
            e_discharge = g.TEdges[g.discharge_edge];

            @constraint(model, capacity_hydro(g) <= g.max_duration * capacity(e_discharge))

            if g.min_duration > 0
                @constraint(model, capacity_hydro(g) >= g.min_duration * capacity(e_discharge))
            end

        end

    end

end

function add_operation_variables!(g::Storage,model::Model)

    if !isempty(stoichiometry_balance_names(g))
        g.operation_expr[:stoichiometry_balance] = @expression(model, [i in stoichiometry_balance_names(g), t in time_interval(g)], 0 * model[:vREF])
    end

    edges_vec = collect(values(edges(g)));

    add_operation_variables!.(edges_vec,model)

    if has_hydrostor(g)
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
        @constraint(model,
        [t in time_interval(g)], 
        st_coeff(e_discharge)[:storage]*flow(e_discharge,t)<=storage_level(g,timestepbefore(t,1,subperiods(g))))

        @constraint(model,
        [t in time_interval(g)], 
        st_coeff(e_discharge)[:storage]*flow(e_discharge,t)<=spill_term(g)+p_gen_term(g)+outflow_term(g))

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
