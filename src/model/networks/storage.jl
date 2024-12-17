macro AbstractStorageBaseAttributes()
    esc(quote
        can_expand::Bool = false
        capacity::AffExpr = AffExpr(0.0)
        capacity_size::Float64 = 1.0
        can_retire::Bool = false
        charge_edge::Union{Nothing,AbstractEdge} = nothing
        charge_discharge_ratio::Float64 = 1.0
        discharge_edge::Union{Nothing,AbstractEdge} = nothing
        existing_capacity::Float64 = 0.0
        fixed_om_cost::Float64 = 0.0
        investment_cost::Float64 = 0.0
        loss_fraction::Float64 = 0.0
        max_capacity::Float64 = Inf
        max_duration::Float64 = 0.0
        max_storage_level::Float64 = 0.0
        min_capacity::Float64 = 0.0
        min_duration::Float64 = 0.0
        min_outflow_fraction::Float64 = 0.0
        min_storage_level::Float64 = 0.0
        new_capacity::AffExpr = AffExpr(0.0)
        new_units::Union{Missing, JuMPVariable} = missing
        retired_capacity::AffExpr = AffExpr(0.0)
        retired_units::Union{Missing, JuMPVariable} = missing
        spillage_edge::Union{Nothing, AbstractEdge} = nothing
        storage_level::JuMPVariable = Vector{VariableRef}()
    end)
end

"""
    Storage{T} <: AbstractVertex

    A mutable struct representing a storage vertex in a network model, parameterized by commodity type T.

    # Inherited Attributes
    - id::Symbol: Unique identifier for the storage
    - timedata::TimeData: Time-related data for the storage
    - balance_data::Dict{Symbol,Dict{Symbol,Float64}}: Dictionary mapping balance equation IDs to coefficients
    - constraints::Vector{AbstractTypeConstraint}: List of constraints applied to the storage
    - operation_expr::Dict: Dictionary storing operational JuMP expressions for the storage

    # Fields
    - can_expand::Bool: Whether storage capacity can be expanded
    - can_retire::Bool: Whether storage capacity can be retired
    - capacity::AffExpr: Total available storage capacity
    - capacity_size::Float64: Size of each storage unit
    - charge_edge::Union{Nothing,AbstractEdge}: `Edge` representing charging flow
    - charge_discharge_ratio::Float64: Ratio between charging and discharging rates
    - discharge_edge::Union{Nothing,AbstractEdge}: `Edge` representing discharging flow
    - existing_capacity::Float64: Initial installed storage capacity
    - fixed_om_cost::Float64: Fixed operation and maintenance costs
    - investment_cost::Float64: Cost per unit of new storage capacity
    - loss_fraction::Float64: Fraction of stored commodity lost at each timestep
    - max_capacity::Float64: Maximum allowed storage capacity
    - max_duration::Float64: Maximum storage duration in hours
    - max_storage_level::Float64: Maximum storage level as fraction of capacity
    - min_capacity::Float64: Minimum required storage capacity
    - min_duration::Float64: Minimum storage duration in hours
    - min_outflow_fraction::Float64: Minimum discharge rate as fraction of capacity
    - min_storage_level::Float64: Minimum storage level as fraction of capacity
    - new_capacity::AffExpr: New storage capacity to be built
    - new_units::Union{Missing, JuMPVariable}: New storage units to be built
    - retired_capacity::AffExpr: Storage capacity to be retired
    - retired_units::Union{Missing, JuMPVariable}: Storage units to be retired
    - spillage_edge::Union{Nothing,AbstractEdge}: Edge representing spillage/losses (e.g. hydro reservoirs)
    - storage_level::Vector{VariableRef}: Storage level at each timestep

    Storage vertices represent facilities that can store commodities over time, such as batteries, 
    pumped hydro, or gas storage. They can charge (store) and discharge (release) commodities, 
    subject to capacity and operational constraints.
"""
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
        can_expand = get(data, :can_expand, false),
        can_retire = get(data, :can_retire, false),
        capacity_size = get(data, :capacity_size, 1.0),
        charge_edge =  get(data, :charge_edge, nothing),
        charge_discharge_ratio = get(data, :charge_discharge_ratio, false),
        discharge_edge =  get(data, :discharge_edge, nothing),
        existing_capacity = get(data, :existing_capacity, 0.0),
        fixed_om_cost = get(data, :fixed_om_cost, 0.0),
        investment_cost = get(data, :investment_cost, 0.0),
        loss_fraction = get(data, :loss_fraction, 0.0),
        max_capacity = get(data, :max_capacity, Inf),
        max_duration = get(data, :max_duration, 0.0),
        max_storage_level = get(data, :max_storage_level, 0.0),
        min_capacity = get(data, :min_capacity, 0.0),
        min_duration = get(data, :min_duration, 0.0),
        min_outflow_fraction = get(data, :min_outflow_fraction, 0.0),
        min_storage_level = get(data, :min_storage_level, 0.0),
        spillage_edge = get(data, :spillage_edge, nothing),
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
can_retire(g::AbstractStorage) = g.can_retire;
charge_edge(g::AbstractStorage) = g.charge_edge;
charge_discharge_ratio(g::AbstractStorage) = g.charge_discharge_ratio;
commodity_type(g::AbstractStorage{T}) where {T} = T;
discharge_edge(g::AbstractStorage) = g.discharge_edge;
existing_capacity(g::AbstractStorage) = g.existing_capacity;
fixed_om_cost(g::AbstractStorage) = g.fixed_om_cost;
investment_cost(g::AbstractStorage) = g.investment_cost;
loss_fraction(g::AbstractStorage) = g.loss_fraction;
max_capacity(g::AbstractStorage) = g.max_capacity;
max_duration(g::AbstractStorage) = g.max_duration;
max_storage_level(g::AbstractStorage) = g.max_storage_level;
min_capacity(g::AbstractStorage) = g.min_capacity;
min_duration(g::AbstractStorage) = g.min_duration;
min_outflow_fraction(g::AbstractStorage) = g.min_outflow_fraction;
min_storage_level(g::AbstractStorage) = g.min_storage_level;
new_capacity(g::AbstractStorage) = g.new_capacity;
new_units(g::AbstractStorage) = g.new_units;
retired_capacity(g::AbstractStorage) = g.retired_capacity;
retired_units(g::AbstractStorage) = g.retired_units;
spillage_edge(g::AbstractStorage) = g.spillage_edge;
storage_level(g::AbstractStorage) = g.storage_level;
storage_level(g::AbstractStorage, t::Int64) = storage_level(g)[t];

function define_available_capacity!(g::AbstractStorage, model::Model)

    g.capacity = @expression(
        model,
        new_capacity(g) - retired_capacity(g) + existing_capacity(g)
    )

end

function add_linking_variables!(g::Storage, model::Model)

    g.new_units = @variable(model, lower_bound = 0.0, base_name = "vNEWUNIT_$(id(g))")

    g.retired_units = @variable(model, lower_bound = 0.0, base_name = "vRETUNIT_$(id(g))")

    g.new_capacity = @expression(model, capacity_size(g) * new_units(g))
    
    g.retired_capacity = @expression(model, capacity_size(g) * retired_units(g))


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
        base_name = "vSTOR_$(g.id)"
    )

    if :storage ∈ balance_ids(g)

        g.operation_expr[:storage] = @expression(
            model,
            [t in time_interval(g)],
            -storage_level(g, t) +
            (1 - loss_fraction(g)) *
            storage_level(g, timestepbefore(t, 1, subperiods(g)))
        )

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
    _storage = LongDurationStorage{commodity}(;
        id = id,
        timedata = time_data,
        can_expand = get(data, :can_expand, false),
        capacity_size = get(data, :capacity_size, 1.0),
        can_retire = get(data, :can_retire, false),
        charge_edge =  get(data, :charge_edge, nothing),
        charge_discharge_ratio = get(data, :charge_discharge_ratio, false),
        discharge_edge =  get(data, :discharge_edge, nothing),
        existing_capacity = get(data, :existing_capacity, 0.0),
        fixed_om_cost = get(data, :fixed_om_cost, 0.0),
        investment_cost = get(data, :investment_cost, 0.0),
        loss_fraction = get(data, :loss_fraction, 0.0),
        max_capacity = get(data, :max_capacity, Inf),
        max_duration = get(data, :max_duration, 0.0),
        max_storage_level = get(data, :max_storage_level, 0.0),
        min_capacity = get(data, :min_capacity, 0.0),
        min_duration = get(data, :min_duration, 0.0),
        min_outflow_fraction = get(data, :min_outflow_fraction, 0.0),
        min_storage_level = get(data, :min_storage_level, 0.0),
        spillage_edge = get(data, :spillage_edge, nothing),
    )
    return _storage
end
LongDurationStorage(id::Symbol, data::Dict{Symbol,Any}, time_data::TimeData, commodity::DataType) =
    make_long_duration_storage(id, data, time_data, commodity)

function add_linking_variables!(g::LongDurationStorage, model::Model)

    g.new_units = @variable(model, lower_bound = 0.0, base_name = "vNEWUNIT_$(id(g))")

    g.retired_units = @variable(model, lower_bound = 0.0, base_name = "vRETUNIT_$(id(g))")

    g.new_capacity = @expression(model, capacity_size(g) * new_units(g))
    
    g.retired_capacity = @expression(model, capacity_size(g) * retired_units(g))

    g.storage_initial =
    @variable(model, [r in modeled_subperiods(g)], lower_bound = 0.0, base_name = "vSTOR_INIT_$(g.id)")

    g.storage_change =
    @variable(model, [w in subperiod_indices(g)], base_name = "vSTOR_CHANGE_$(g.id)")

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
        base_name = "vSTOR_$(g.id)"
    )

    if :storage ∈ balance_ids(g)

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
        error("A storage vertex requires to have a balance named :storage")
    end

    subperiod_end = Dict(w => last(get_subperiod(g, w)) for w in subperiod_indices(g));

    @constraint(model, [w in subperiod_indices(g)], 
        storage_initial(g, w) ==  storage_level(g,subperiod_end[w]) - storage_change(g, w)
    )

end