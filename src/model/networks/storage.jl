macro AbstractStorageBaseAttributes()
    storage_defaults = storage_default_data()
    esc(quote
    charge_edge::Union{Nothing,AbstractEdge} = nothing
    discharge_edge::Union{Nothing,AbstractEdge} = nothing
    spillage_edge::Union{Nothing, AbstractEdge} = nothing
    can_expand::Bool = $storage_defaults[:can_expand]
    can_retire::Bool = $storage_defaults[:can_retire]
    capacity::AffExpr = AffExpr(0.0)
    capacity_size::Float64 = $storage_defaults[:capacity_size]
    capital_recovery_period::Int64 = $storage_defaults[:capital_recovery_period]
    charge_discharge_ratio::Float64 = $storage_defaults[:charge_discharge_ratio]
    existing_capacity::Float64 = $storage_defaults[:existing_capacity]
    fixed_om_cost::Float64 = $storage_defaults[:fixed_om_cost]
    investment_cost::Float64 = $storage_defaults[:investment_cost]
    lifetime::Int64 = $storage_defaults[:lifetime]
    long_duration::Bool = $storage_defaults[:long_duration]
    loss_fraction::Float64 = $storage_defaults[:loss_fraction]
    max_capacity::Float64 = $storage_defaults[:max_capacity]
    max_duration::Float64 = $storage_defaults[:max_duration]
    max_storage_level::Float64 = $storage_defaults[:max_storage_level]
    min_capacity::Float64 = $storage_defaults[:min_capacity]
    min_duration::Float64 = $storage_defaults[:min_duration]
    min_outflow_fraction::Float64 = $storage_defaults[:min_outflow_fraction]
    min_storage_level::Float64 = $storage_defaults[:min_storage_level]
    new_capacity::AffExpr = AffExpr(0.0)
    new_capacity_track::Dict{Int64,AffExpr} = Dict(1=>AffExpr(0.0))
    new_units::Union{Missing, JuMPVariable} = missing
    retired_capacity::AffExpr = AffExpr(0.0)
    retired_capacity_track::Dict{Int64,AffExpr} = Dict(1=>AffExpr(0.0))
    retirement_stage::Int64 = $storage_defaults[:retirement_stage]
    retired_units::Union{Missing, JuMPVariable} = missing
    storage_level::JuMPVariable = Vector{VariableRef}()
    wacc::Float64 = $storage_defaults[:wacc]
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
    # We could instead filter on an explicit list of keys
    # As it is, this will add configure several additional
    # attributes than we had before, e.g. :constraints 
    storage_kwargs = Base.fieldnames(Storage)
    filtered_data = Dict{Symbol, Any}(
        k => v for (k,v) in data if k in storage_kwargs
    )
    remove_keys = [:id, :timedata]
    for key in remove_keys
        if haskey(filtered_data, key)
            delete!(filtered_data, key)
        end
    end
    _storage = Storage{commodity}(;
        id = id,
        timedata = time_data,
        filtered_data...
    )
    return _storage
end
Storage(id::Symbol, data::Dict{Symbol,Any}, time_data::TimeData, commodity::DataType) =
    make_storage(id, data, time_data, commodity)

######### Storage interface #########
all_constraints(g::AbstractStorage) = g.constraints;
can_expand(g::AbstractStorage) = g.can_expand;
capacity(g::AbstractStorage) = g.capacity;
capacity_size(g::AbstractStorage) = g.capacity_size;
capital_recovery_period(g::AbstractStorage) = g.capital_recovery_period;
can_retire(g::AbstractStorage) = g.can_retire;
charge_edge(g::AbstractStorage) = g.charge_edge;
charge_discharge_ratio(g::AbstractStorage) = g.charge_discharge_ratio;
commodity_type(g::AbstractStorage{T}) where {T} = T;
discharge_edge(g::AbstractStorage) = g.discharge_edge;
existing_capacity(g::AbstractStorage) = g.existing_capacity;
fixed_om_cost(g::AbstractStorage) = g.fixed_om_cost;
has_capacity(g::AbstractStorage) = true;
investment_cost(g::AbstractStorage) = g.investment_cost;
lifetime(g::AbstractStorage) = g.lifetime;
loss_fraction(g::AbstractStorage) = g.loss_fraction;
max_capacity(g::AbstractStorage) = g.max_capacity;
max_duration(g::AbstractStorage) = g.max_duration;
max_storage_level(g::AbstractStorage) = g.max_storage_level;
min_capacity(g::AbstractStorage) = g.min_capacity;
min_duration(g::AbstractStorage) = g.min_duration;
min_outflow_fraction(g::AbstractStorage) = g.min_outflow_fraction;
min_storage_level(g::AbstractStorage) = g.min_storage_level;
new_capacity(g::AbstractStorage) = g.new_capacity;
new_capacity_track(g::AbstractStorage) = g.new_capacity_track;
#### Note that storage "g" may not be present in the inputs for all stages
new_capacity_track(g::AbstractStorage,s::Int64) =  (haskey(new_capacity_track(g),s) == false) ? 0.0 : g.new_capacity_track[s];
new_units(g::AbstractStorage) = g.new_units;
retired_capacity(g::AbstractStorage) = g.retired_capacity;
retired_capacity_track(g::AbstractStorage) = g.retired_capacity_track;
#### Note that storage "g" may not be present in the inputs for all stages
retired_capacity_track(g::AbstractStorage,s::Int64) =  (haskey(retired_capacity_track(g),s) == false) ? 0.0 : g.retired_capacity_track[s];
retired_units(g::AbstractStorage) = g.retired_units;
retirement_stage(g::AbstractStorage) = g.retirement_stage;
spillage_edge(g::AbstractStorage) = g.spillage_edge;
storage_level(g::AbstractStorage) = g.storage_level;
storage_level(g::AbstractStorage, t::Int64) = storage_level(g)[t];
wacc(g::AbstractStorage) = g.wacc;

function define_available_capacity!(g::AbstractStorage, model::Model)

    g.capacity = @expression(
        model,
        new_capacity(g) - retired_capacity(g) + existing_capacity(g)
    )

end

function add_linking_variables!(g::Storage, model::Model)

    g.new_units = @variable(model, lower_bound = 0.0, base_name = "vNEWUNIT_$(id(g))_stage$(stage_index(g))")

    g.retired_units = @variable(model, lower_bound = 0.0, base_name = "vRETUNIT_$(id(g))_stage$(stage_index(g))")

    g.new_capacity = @expression(model, capacity_size(g) * new_units(g))
    
    g.retired_capacity = @expression(model, capacity_size(g) * retired_units(g))

    g.new_capacity_track[stage_index(g)] = new_capacity(g);
        
    g.retired_capacity_track[stage_index(g)] = retired_capacity(g);

end

function planning_model!(g::Storage, model::Model)

    if !g.can_expand
        fix(new_units(g), 0.0; force = true)
    else
        add_to_expression!(
            model[:eFixedCost],
            investment_cost(g),
            new_capacity(g),
        )
    end

    if !g.can_retire
        fix(retired_units(g), 0.0; force = true)
    end


    if fixed_om_cost(g) > 0
        add_to_expression!(
            model[:eFixedCost],
            fixed_om_cost(g),
            capacity(g),
        )
    end

    @constraint(model, retired_capacity(g) <= existing_capacity(g))

end

function operation_model!(g::Storage, model::Model)

    g.storage_level = @variable(
        model,
        [t in time_interval(g)],
        lower_bound = 0.0,
        base_name = "vSTOR_$(g.id)_stage$(stage_index(g))"
    )

    if :storage ∈ balance_ids(g)

        for i in balance_ids(g)
            if i == :storage 
                g.operation_expr[:storage] = @expression(
                    model,
                    [t in time_interval(g)],
                    -storage_level(g, t) +
                    (1 - loss_fraction(g)) *
                    storage_level(g, timestepbefore(t, 1, subperiods(g)))
                )
            else
                g.operation_expr[i] =
                @expression(model, [t in time_interval(g)], 0 * model[:vREF])
            end
        end
    else
        error("A storage vertex requires to have a balance named :storage")
    end

end

Base.@kwdef mutable struct LongDurationStorage{T} <: AbstractStorage{T}
    @AbstractVertexBaseAttributes()
    @AbstractStorageBaseAttributes()
    storage_initial::JuMPVariable = Vector{VariableRef}()
    storage_change::JuMPVariable = Vector{VariableRef}()
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

    storage_kwargs = Base.fieldnames(LongDurationStorage)
    filtered_data = Dict{Symbol,Any}(
        k => v for (k, v) in data if k in storage_kwargs
    )
    remove_keys = [:id, :timedata]
    for key in remove_keys
        if haskey(filtered_data, key)
            delete!(filtered_data, key)
        end
    end
    _storage = LongDurationStorage{commodity}(;
        id=id,
        timedata=time_data,
        filtered_data...
    )
    return _storage
end
LongDurationStorage(id::Symbol, data::Dict{Symbol,Any}, time_data::TimeData, commodity::DataType) =
    make_long_duration_storage(id, data, time_data, commodity)

function add_linking_variables!(g::LongDurationStorage, model::Model)

    g.new_units = @variable(model, lower_bound = 0.0, base_name = "vNEWUNIT_$(id(g))_stage$(stage_index(g))")

    g.retired_units = @variable(model, lower_bound = 0.0, base_name = "vRETUNIT_$(id(g))_stage$(stage_index(g))")

    g.new_capacity = @expression(model, capacity_size(g) * new_units(g))
    
    g.retired_capacity = @expression(model, capacity_size(g) * retired_units(g))

    g.storage_initial =
    @variable(model, [r in modeled_subperiods(g)], lower_bound = 0.0, base_name = "vSTOR_INIT_$(g.id)_stage$(stage_index(g))")

    g.storage_change =
    @variable(model, [w in subperiod_indices(g)], base_name = "vSTOR_CHANGE_$(g.id)_stage$(stage_index(g))")

end


function planning_model!(g::LongDurationStorage, model::Model)

    if !g.can_expand
        fix(new_units(g), 0.0; force = true)
    else
        add_to_expression!(
            model[:eFixedCost],
            investment_cost(g),
            new_capacity(g),
        )
    end

    if !g.can_retire
        fix(retired_units(g), 0.0; force = true)
    end


    if fixed_om_cost(g) > 0
        add_to_expression!(
            model[:eFixedCost],
            fixed_om_cost(g),
            capacity(g),
        )
    end

    @constraint(model, retired_capacity(g) <= existing_capacity(g))

    MODELED_SUBPERIODS = modeled_subperiods(g)
    NPeriods = length(MODELED_SUBPERIODS);

    @constraint(model,[r in MODELED_SUBPERIODS], 
        storage_initial(g, r) <= capacity(g)
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
        base_name = "vSTOR_$(g.id)_stage$(stage_index(g))"
    )

    
    if :storage ∈ balance_ids(g)

        for i in balance_ids(g)
            if i == :storage 
                STARTS = [first(sp) for sp in subperiods(g)];
                g.operation_expr[:storage] = @expression(
                    model,
                    [t in time_interval(g)],
                    if t ∈ STARTS 
                        -storage_level(g, t) +
                        (1 - loss_fraction(g)) *
                        (storage_level(g, timestepbefore(t, 1, subperiods(g))) - storage_change(g, current_subperiod(g,t)))
                    else
                        -storage_level(g, t) +
                        (1 - loss_fraction(g)) *
                        storage_level(g, timestepbefore(t, 1, subperiods(g)))
                    end
                )
            else
                g.operation_expr[i] =
                @expression(model, [t in time_interval(g)], 0 * model[:vREF])
            end
        end
    else
        error("A storage vertex requires to have a balance named :storage")
    end

    subperiod_end = Dict(w => last(get_subperiod(g, w)) for w in subperiod_indices(g));

    @constraint(model, [w in subperiod_indices(g)], 
        storage_initial(g, w) ==  storage_level(g,subperiod_end[w]) - storage_change(g, w)
    )

end