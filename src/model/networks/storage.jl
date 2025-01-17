macro AbstractStorageBaseAttributes()
    esc(quote
    can_expand::Bool = false
    can_retire::Bool = false
    capacity_storage::Union{AffExpr,Float64} = 0.0
    charge_edge::Union{Nothing,AbstractEdge} = nothing
    charge_discharge_ratio::Float64 = 1.0
    discharge_edge::Union{Nothing,AbstractEdge} = nothing
    existing_capacity_storage::Float64 = 0.0
    fixed_om_cost_storage::Float64 = 0.0
    investment_cost_storage::Float64 = 0.0
    max_capacity_storage::Float64 = Inf
    max_duration::Float64 = 0.0
    min_capacity_storage::Float64 = 0.0
    min_duration::Float64 = 0.0
    min_outflow_fraction::Float64 = 0.0
    min_storage_level::Float64 = 0.0
    max_storage_level::Float64 = 0.0
    new_capacity_storage::Union{JuMPVariable,Float64} = 0.0
    ret_capacity_storage::Union{JuMPVariable,Float64} = 0.0
    spillage_edge::Union{Nothing,AbstractEdge} = nothing
    storage_level::Union{JuMPVariable,Vector{Float64}} = Vector{VariableRef}()
    storage_loss_fraction::Float64 = 0.0
    end)
end
Base.@kwdef mutable struct Storage{T} <: AbstractStorage{T}
    @AbstractVertexBaseAttributes()
    @AbstractStorageBaseAttributes()
end

function make_storage(
    id::Symbol,
    data::Dict{Symbol,Any},
    time_data::TimeData,
    commodity::DataType,
)
    _storage = Storage{commodity}(;
        id = id,
        timedata = time_data,
        can_retire = get(data, :can_retire, false),
        can_expand = get(data, :can_expand, false),
        charge_discharge_ratio = get(data, :charge_discharge_ratio, false),
        existing_capacity_storage = get(data, :existing_capacity_storage, 0.0),
        investment_cost_storage = get(data, :investment_cost_storage, 0.0),
        fixed_om_cost_storage = get(data, :fixed_om_cost_storage, 0.0),
        storage_loss_fraction = get(data, :storage_loss_fraction, 0.0),
        min_duration = get(data, :min_duration, 0.0),
        max_duration = get(data, :max_duration, 0.0),
        min_outflow_fraction = get(data, :min_outflow_fraction, 0.0),
        min_storage_level = get(data, :min_storage_level, 0.0),
        max_storage_level = get(data, :max_storage_level, 0.0),
        min_capacity_storage = get(data, :min_capacity_storage, 0.0),
        max_capacity_storage = get(data, :max_capacity_storage, Inf),
    )
    return _storage
end
Storage(id::Symbol, data::Dict{Symbol,Any}, time_data::TimeData, commodity::DataType) =
    make_storage(id, data, time_data, commodity)


######### Storage interface #########
all_constraints(g::AbstractStorage) = g.constraints;
capacity_storage(g::AbstractStorage) = g.capacity_storage;
charge_edge(g::AbstractStorage) = g.charge_edge;
charge_discharge_ratio(g::AbstractStorage) = g.charge_discharge_ratio;
commodity_type(g::AbstractStorage{T}) where {T} = T;
discharge_edge(g::AbstractStorage) = g.discharge_edge;
existing_capacity_storage(g::AbstractStorage) = g.existing_capacity_storage;
fixed_om_cost_storage(g::AbstractStorage) = g.fixed_om_cost_storage;
investment_cost_storage(g::AbstractStorage) = g.investment_cost_storage;
min_capacity_storage(g::AbstractStorage) = g.min_capacity_storage;
max_capacity_storage(g::AbstractStorage) = g.max_capacity_storage;
max_duration(g::AbstractStorage) = g.max_duration;
min_duration(g::AbstractStorage) = g.min_duration;
min_outflow_fraction(g::AbstractStorage) = g.min_outflow_fraction;
min_storage_level(g::AbstractStorage) = g.min_storage_level;
max_storage_level(g::AbstractStorage) = g.max_storage_level;
new_capacity_storage(g::AbstractStorage) = g.new_capacity_storage;
ret_capacity_storage(g::AbstractStorage) = g.ret_capacity_storage;
storage_level(g::AbstractStorage) = g.storage_level;
storage_level(g::AbstractStorage, t::Int64) = storage_level(g)[t];
storage_loss_fraction(g::AbstractStorage) = g.storage_loss_fraction;
######### Storage interface #########


function add_linking_variables!(g::Storage, model::Model)

    g.new_capacity_storage =
    @variable(model, lower_bound = 0.0, base_name = "vNEWCAPSTOR_$(g.id)")

    g.ret_capacity_storage =
    @variable(model, lower_bound = 0.0, base_name = "vRETCAPSTOR_$(g.id)")


end

function define_available_capacity!(g::AbstractStorage, model::Model)

    g.capacity_storage = @expression(
        model,
        new_capacity_storage(g) - ret_capacity_storage(g) + existing_capacity_storage(g)
    )


end

function planning_model!(g::Storage, model::Model)

    if !g.can_expand
        fix(new_capacity_storage(g), 0.0; force = true)
    else
        add_to_expression!(
            model[:eFixedCost],
            investment_cost_storage(g),
            new_capacity_storage(g),
        )
    end

    if !g.can_retire
        fix(ret_capacity_storage(g), 0.0; force = true)
    end


    if fixed_om_cost_storage(g) > 0
        add_to_expression!(
            model[:eFixedCost],
            fixed_om_cost_storage(g),
            capacity_storage(g),
        )
    end

    @constraint(model, ret_capacity_storage(g) <= existing_capacity_storage(g))

end

function operation_model!(g::Storage, model::Model)

    g.storage_level = @variable(
        model,
        [t in time_interval(g)],
        lower_bound = 0.0,
        base_name = "vSTOR_$(g.id)"
    )

    if :storage ∈ balance_ids(g)

        g.operation_expr[:storage] = @expression(
            model,
            [t in time_interval(g)],
            -storage_level(g, t) +
            (1 - storage_loss_fraction(g)) *
            storage_level(g, timestepbefore(t, 1, subperiods(g)))
        )

    else
        error("A storage vertex requires to have a balance named :storage")
    end

end

Base.@kwdef mutable struct LongDurationStorage{T} <: AbstractStorage{T}
    @AbstractVertexBaseAttributes()
    @AbstractStorageBaseAttributes()
    storage_initial::Union{JuMPVariable,Vector{Float64}} = Vector{VariableRef}()
    storage_change::Union{JuMPVariable,Vector{Float64}} = Vector{VariableRef}()
end
storage_initial(g::LongDurationStorage) = g.storage_initial;
storage_initial(g::LongDurationStorage, r::Int64) = g.storage_initial[r];
storage_change(g::LongDurationStorage) = g.storage_change;
storage_change(g::LongDurationStorage, w::Int64) =  g.storage_change[w];

function make_long_duration_storage(
    id::Symbol,
    data::Dict{Symbol,Any},
    time_data::TimeData,
    commodity::DataType,
)
    _storage = LongDurationStorage{commodity}(;
        id = id,
        timedata = time_data,
        can_retire = get(data, :can_retire, false),
        can_expand = get(data, :can_expand, false),
        charge_discharge_ratio = get(data, :charge_discharge_ratio, false),
        existing_capacity_storage = get(data, :existing_capacity_storage, 0.0),
        investment_cost_storage = get(data, :investment_cost_storage, 0.0),
        fixed_om_cost_storage = get(data, :fixed_om_cost_storage, 0.0),
        storage_loss_fraction = get(data, :storage_loss_fraction, 0.0),
        min_duration = get(data, :min_duration, 0.0),
        max_duration = get(data, :max_duration, 0.0),
        min_storage_level = get(data, :min_storage_level, 0.0),
        max_storage_level = get(data, :max_storage_level, 0.0),
        min_capacity_storage = get(data, :min_capacity_storage, 0.0),
        max_capacity_storage = get(data, :max_capacity_storage, Inf),
    )
    return _storage
end
LongDurationStorage(id::Symbol, data::Dict{Symbol,Any}, time_data::TimeData, commodity::DataType) =
    make_long_duration_storage(id, data, time_data, commodity)

function add_linking_variables!(g::LongDurationStorage, model::Model)

    g.new_capacity_storage =
    @variable(model, lower_bound = 0.0, base_name = "vNEWCAPSTOR_$(g.id)")

    g.ret_capacity_storage =
    @variable(model, lower_bound = 0.0, base_name = "vRETCAPSTOR_$(g.id)")

    g.storage_initial =
    @variable(model, [r in modeled_subperiods(g)], lower_bound = 0.0, base_name = "vSTOR_INIT_$(g.id)")

    g.storage_change =
    @variable(model, [w in subperiod_indices(g)], base_name = "vSTOR_CHANGE_$(g.id)")

end

function planning_model!(g::LongDurationStorage, model::Model)

    if !g.can_expand
        fix(new_capacity_storage(g), 0.0; force = true)
    else
        add_to_expression!(
            model[:eFixedCost],
            investment_cost_storage(g),
            new_capacity_storage(g),
        )
    end

    if !g.can_retire
        fix(ret_capacity_storage(g), 0.0; force = true)
    end


    if fixed_om_cost_storage(g) > 0
        add_to_expression!(
            model[:eFixedCost],
            fixed_om_cost_storage(g),
            capacity_storage(g),
        )
    end

    @constraint(model, 
        ret_capacity_storage(g) <= existing_capacity_storage(g)
    )

    MODELED_SUBPERIODS = modeled_subperiods(g)
    NPeriods = length(MODELED_SUBPERIODS);

    @constraint(model,[r in MODELED_SUBPERIODS], 
        storage_initial(g, r) <= capacity_storage(g)
    )

    @constraint(model, [r in MODELED_SUBPERIODS], 
        storage_initial(g, mod1(r + 1, NPeriods)) == storage_initial(g, r) + storage_change(g, period_map(g,r))
    )

end

function operation_model!(g::LongDurationStorage, model::Model)

    g.storage_level = @variable(
        model,
        [t in time_interval(g)],
        lower_bound = 0.0,
        base_name = "vSTOR_$(g.id)"
    )

    if :storage ∈ balance_ids(g)

        STARTS = [first(sp) for sp in subperiods(g)];

        g.operation_expr[:storage] = @expression(
            model,
            [t in time_interval(g)],
            if t ∈ STARTS 
                -storage_level(g, t) +
                (1 - storage_loss_fraction(g)) *
                (storage_level(g, timestepbefore(t, 1, subperiods(g))) - storage_change(g, current_subperiod(g,t)))
            else
                -storage_level(g, t) +
                (1 - storage_loss_fraction(g)) *
                storage_level(g, timestepbefore(t, 1, subperiods(g)))
            end
        )

    else
        error("A storage vertex requires to have a balance named :storage")
    end

    subperiod_end = Dict(w => last(get_subperiod(g, w)) for w in subperiod_indices(g));

    @constraint(model, [w in subperiod_indices(g)], 
        storage_initial(g, w) ==  storage_level(g,subperiod_end[w]) - storage_change(g, w)
    )

end