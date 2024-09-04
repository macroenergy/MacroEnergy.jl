
Base.@kwdef mutable struct Storage{T} <: AbstractVertex
    @AbstractVertexBaseAttributes()
    discharge_edge::Union{Nothing,AbstractEdge} = nothing
    charge_edge::Union{Nothing,AbstractEdge} = nothing
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
end
commodity_type(g::Storage{T}) where {T} = T;
all_constraints(g::Storage) = g.constraints;
min_duration(g::Storage) = g.min_duration;
max_duration(g::Storage) = g.max_duration;
min_storage_level(g::Storage) = g.min_storage_level;
existing_capacity_storage(g::Storage) = g.existing_capacity_storage;
new_capacity_storage(g::Storage) = g.planning_vars[:new_capacity_storage];
ret_capacity_storage(g::Storage) = g.planning_vars[:ret_capacity_storage];
capacity_storage(g::Storage) = g.planning_vars[:capacity_storage];
investment_cost_storage(g::Storage) = g.investment_cost_storage;
fixed_om_cost_storage(g::Storage) = g.fixed_om_cost_storage;
storage_level(g::Storage) = g.operation_vars[:storage_level];
storage_level(g::Storage,t::Int64) = storage_level(g)[t];
storage_loss_fraction(g::Storage) = g.storage_loss_fraction;
discharge_edge(g::Storage) = g.discharge_edge;
charge_edge(g::Storage) = g.charge_edge;

function make_storage(id::Symbol, data::Dict{Symbol,Any}, time_data::TimeData, commodity::DataType)
    _storage = Storage{commodity}(;
        id = id,
        timedata = time_data,
        can_retire = get(data, :can_retire, false),
        can_expand = get(data, :can_expand, false),
        existing_capacity_storage = get(data, :existing_capacity_storage, 0.0),
        investment_cost_storage = get(data, :investment_cost_storage, 0.0),
        fixed_om_cost_storage = get(data, :fixed_om_cost_storage, 0.0),
        storage_loss_fraction = get(data, :storage_loss_fraction, 0.0),
        min_duration = get(data, :min_duration, 0.0),
        max_duration = get(data, :max_duration, 0.0),
        min_storage_level = get(data, :min_storage_level, 0.0),
        min_capacity_storage = get(data, :min_capacity_storage, 0.0),
        max_capacity_storage = get(data, :max_capacity_storage, Inf)
    )
    return _storage
end
Storage(id::Symbol, data::Dict{Symbol,Any}, time_data::TimeData, commodity::DataType) = make_storage(id, data, time_data, commodity)

function add_planning_variables!(g::Storage,model::Model)
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

end

function add_operation_variables!(g::Storage,model::Model)

    g.operation_vars[:storage_level] = @variable(
        model,
        [t in time_interval(g)],
        lower_bound = 0.0,
        base_name = "vSTOR_$(g.id)"
    )

    if :storage ∈ balance_ids(g)
        
        g.operation_expr[:storage] = @expression(model, 
                                        [t in time_interval(g)], 
                                        -storage_level(g,t) + (1 - storage_loss_fraction(g)) * storage_level(g,timestepbefore(t,1,subperiods(g))))
    
    else
        error("A storage vertex requires to have a balance named :storage")
    end

end