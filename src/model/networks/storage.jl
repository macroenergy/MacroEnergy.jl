macro AbstractStorageBaseAttributes()
    storage_defaults = storage_default_data()
    esc(quote
        charge_edge::Union{Nothing,AbstractEdge} = nothing
        discharge_edge::Union{Nothing,AbstractEdge} = nothing
        spillage_edge::Union{Nothing, AbstractEdge} = nothing
        can_expand::Bool = $storage_defaults[:can_expand]
        can_retire::Bool = $storage_defaults[:can_retire]
        capacity::Union{JuMPVariable,AffExpr,Float64} = AffExpr(0.0)
        capacity_size::Float64 = $storage_defaults[:capacity_size]
        capital_recovery_period::Int64 = $storage_defaults[:capital_recovery_period]
        charge_discharge_ratio::Float64 = $storage_defaults[:charge_discharge_ratio]
        existing_capacity::Union{JuMPVariable,AffExpr,Float64,Int64} = $storage_defaults[:existing_capacity]
        fixed_om_cost::Float64 = $storage_defaults[:fixed_om_cost]
        investment_cost::Float64 = $storage_defaults[:investment_cost]
        lifetime::Int64 = $storage_defaults[:lifetime]
        long_duration::Bool = $storage_defaults[:long_duration]
        loss_fraction::Vector{Float64} = $storage_defaults[:loss_fraction]
        max_capacity::Float64 = $storage_defaults[:max_capacity]
        max_duration::Float64 = $storage_defaults[:max_duration]
        max_new_capacity::Float64 = $storage_defaults[:max_new_capacity]
        max_storage_level::Float64 = $storage_defaults[:max_storage_level]
        min_capacity::Float64 = $storage_defaults[:min_capacity]
        min_duration::Float64 = $storage_defaults[:min_duration]
        min_outflow_fraction::Float64 = $storage_defaults[:min_outflow_fraction]
        min_retired_capacity::Float64 = $storage_defaults[:min_retired_capacity]
        min_retired_capacity_track::Float64 = 0.0
        min_storage_level::Float64 = $storage_defaults[:min_storage_level]
        new_capacity::Union{AffExpr,Float64} = AffExpr(0.0)
        new_capacity_track::Dict{Int64,AffExpr} = Dict(1=>AffExpr(0.0))
        new_units::Union{Missing, JuMPVariable} = missing
        retired_capacity::Union{AffExpr,Float64} = AffExpr(0.0)
        retired_capacity_track::Dict{Int64,AffExpr} = Dict(1=>AffExpr(0.0))
        retirement_period::Int64 = $storage_defaults[:retirement_period]
        retired_units::Union{Missing, JuMPVariable} = missing
        storage_level::JuMPVariable = Vector{VariableRef}()
        variable_om_cost::Float64 = $storage_defaults[:variable_om_cost]
        wacc::Union{Missing,Float64} = missing
        annualized_investment_cost::Union{Nothing,Float64} = $storage_defaults[:annualized_investment_cost]
        pv_period_investment_cost::Union{Nothing,Float64} = $storage_defaults[:pv_period_investment_cost]
        pv_period_fixed_om_cost::Union{Nothing,Float64} = $storage_defaults[:pv_period_fixed_om_cost]
        pv_period_variable_om_cost::Union{Nothing,Float64} = $storage_defaults[:pv_period_variable_om_cost]
        cf_period_investment_cost::Union{Nothing,Float64} = $storage_defaults[:cf_period_investment_cost]
        cf_period_fixed_om_cost::Union{Nothing,Float64} = $storage_defaults[:cf_period_fixed_om_cost]
        cf_period_variable_om_cost::Union{Nothing,Float64} = $storage_defaults[:cf_period_variable_om_cost]
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
    - investment_cost::Float64: CAPEX per unit of new storage capacity
    - loss_fraction::Float64: Fraction of stored commodity lost at each timestep
    - loss_fraction::Vector{Float64}: Fraction of stored commodity lost at each timestep
    - max_capacity::Float64: Maximum allowed storage capacity
    - max_duration::Float64: Maximum storage duration in hours
    - max_storage_level::Float64: Maximum storage level as fraction of capacity
    - min_capacity::Float64: Minimum required storage capacity
    - min_duration::Float64: Minimum storage duration in hours
    - min_outflow_fraction::Float64: Minimum discharge rate as fraction of capacity
    - min_retired_capacity::Float64: Minimum capacity that must be retired in this period
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


commodity_type(::Type{AbstractStorage{T}}) where {T} = T
function commodity_type(t::Type{AbstractStorage{<:T}}) where {T}
    ub_type = t.var.ub
    return commodity_type(AbstractStorage{ub_type})
end
commodity_type(::Type{Storage{T}}) where {T} = T
function commodity_type(t::Type{Storage{<:T}}) where {T}
    ub_type = t.var.ub
    return commodity_type(Storage{ub_type})
end

function make_storage(
    id::Symbol,
    data::Dict{Symbol,Any},
    time_data::TimeData,
    commodity::DataType,
    location::Union{Missing,Symbol} = missing
)
    # We could instead filter on an explicit list of keys
    # As it is, this will add configure several additional
    # attributes than we had before, e.g. :constraints 
    storage_kwargs = Base.fieldnames(Storage)
    filtered_data = Dict{Symbol, Any}(
        k => v for (k,v) in data if k in storage_kwargs
    )
    remove_keys = [:id, :timedata, :location]
    for key in remove_keys
        if haskey(filtered_data, key)
            delete!(filtered_data, key)
        end
    end
    if haskey(filtered_data,:loss_fraction) && !isa(filtered_data[:loss_fraction], Vector{Float64})
        filtered_data[:loss_fraction] = [filtered_data[:loss_fraction]];
    end 
    _storage = Storage{commodity}(;
        id = id,
        timedata = time_data,
        location = location,
        filtered_data...
    )
    return _storage
end
Storage(id::Symbol, data::Dict{Symbol,Any}, time_data::TimeData, commodity::DataType, location::Union{Missing,Symbol} = missing) =
    make_storage(id, data, time_data, commodity, location)

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
function loss_fraction(g::AbstractStorage, t::Int64)
    a = loss_fraction(g)
    if isempty(a)
        return 0.0
    elseif length(a) == 1
        return a[1]
    else
        return a[t]
    end
end
max_capacity(g::AbstractStorage) = g.max_capacity;
max_duration(g::AbstractStorage) = g.max_duration;
max_new_capacity(g::AbstractStorage) = g.max_new_capacity;
max_storage_level(g::AbstractStorage) = g.max_storage_level;
min_capacity(g::AbstractStorage) = g.min_capacity;
min_duration(g::AbstractStorage) = g.min_duration;
min_outflow_fraction(g::AbstractStorage) = g.min_outflow_fraction;
min_retired_capacity(g::AbstractStorage) = g.can_retire ? g.min_retired_capacity : 0.0;
min_retired_capacity_track(g::AbstractStorage) = g.min_retired_capacity_track;
min_storage_level(g::AbstractStorage) = g.min_storage_level;
new_capacity(g::AbstractStorage) = g.new_capacity;
new_capacity_track(g::AbstractStorage) = g.new_capacity_track;
#### Note that storage "g" may not be present in the inputs for all case
new_capacity_track(g::AbstractStorage,s::Int64) =  (haskey(new_capacity_track(g),s) == false) ? 0.0 : g.new_capacity_track[s];
new_units(g::AbstractStorage) = g.new_units;
retired_capacity(g::AbstractStorage) = g.retired_capacity;
retired_capacity_track(g::AbstractStorage) = g.retired_capacity_track;
#### Note that storage "g" may not be present in the inputs for all case
retired_capacity_track(g::AbstractStorage,s::Int64) =  (haskey(retired_capacity_track(g),s) == false) ? 0.0 : g.retired_capacity_track[s];
retired_units(g::AbstractStorage) = g.retired_units;
retirement_period(g::AbstractStorage) = g.retirement_period;
retrofitted_capacity_track(g::AbstractStorage,s::Int64) = 0.0; ### Note that retrofits are not implemented for storage yet
spillage_edge(g::AbstractStorage) = g.spillage_edge;
storage_level(g::AbstractStorage) = g.storage_level;
storage_level(g::AbstractStorage, t::Int64) = storage_level(g)[t];
wacc(g::AbstractStorage) = g.wacc;
annualized_investment_cost(g::AbstractStorage) = g.annualized_investment_cost;
pv_period_investment_cost(g::AbstractStorage) = g.pv_period_investment_cost;
cf_period_investment_cost(g::AbstractStorage) = g.cf_period_investment_cost;
pv_period_fixed_om_cost(g::AbstractStorage) = g.pv_period_fixed_om_cost;
cf_period_fixed_om_cost(g::AbstractStorage) = g.cf_period_fixed_om_cost;
variable_om_cost(g::AbstractStorage) = g.variable_om_cost;
pv_period_variable_om_cost(g::AbstractStorage) = g.pv_period_variable_om_cost;
cf_period_variable_om_cost(g::AbstractStorage) = g.cf_period_variable_om_cost;

function add_linking_variables!(g::Storage, model::Model)
    if has_capacity(g)
        g.capacity = @variable(model, lower_bound = 0.0, base_name = "vCAP_$(id(g))_period$(period_index(g))")
    end
end

function define_available_capacity!(g::AbstractStorage, model::Model)

    if has_capacity(g)
        g.new_units = @variable(model, lower_bound = 0.0, base_name = "vNEWUNIT_$(id(g))_period$(period_index(g))")

        g.retired_units = @variable(model, lower_bound = 0.0, base_name = "vRETUNIT_$(id(g))_period$(period_index(g))")
        
        g.new_capacity = @expression(model, capacity_size(g) * new_units(g))
        
        g.retired_capacity = @expression(model, capacity_size(g) * retired_units(g))
        
        g.new_capacity_track[period_index(g)] = new_capacity(g);
            
        g.retired_capacity_track[period_index(g)] = retired_capacity(g);

        @constraint(model, capacity(g) == new_capacity(g) - retired_capacity(g) + existing_capacity(g))

        # g.capacity = @expression(
        #     model,
        #     new_capacity(g) - retired_capacity(g) + existing_capacity(g)
        # )
    end
end

function planning_model!(g::Storage, model::Model)

    if !g.can_expand
        fix(new_units(g), 0.0; force = true)
    end

    if !g.can_retire
        fix(retired_units(g), 0.0; force = true)
    end

    compute_fixed_costs!(g, model)

    @constraint(model, retired_capacity(g) <= existing_capacity(g))

end

function operation_model!(g::Storage, model::Model)

    g.storage_level = @variable(
        model,
        [t in time_interval(g)],
        lower_bound = 0.0,
        base_name = "vSTOR_$(g.id)_period$(period_index(g))"
    )

    if :storage ∈ balance_ids(g)

        for i in balance_ids(g)
            if i == :storage 
                g.operation_expr[:storage] = @expression(
                    model,
                    [t in time_interval(g)],
                    -storage_level(g, t) +
                    (1 - loss_fraction(g,timestepbefore(t, 1, subperiods(g)))) *
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
    storage_initial::Union{JuMPVariable,Dict{Int64,Float64}}= Vector{VariableRef}()
    storage_change::Union{JuMPVariable,Dict{Int64,Float64}} = Vector{VariableRef}()
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
    location::Union{Missing,Symbol} = missing
)
    storage_kwargs = Base.fieldnames(LongDurationStorage)
    filtered_data = Dict{Symbol,Any}(
        k => v for (k, v) in data if k in storage_kwargs
    )
    remove_keys = [:id, :timedata, :location]
    for key in remove_keys
        if haskey(filtered_data, key)
            delete!(filtered_data, key)
        end
    end
    if haskey(filtered_data,:loss_fraction) && !isa(filtered_data[:loss_fraction], Vector{Float64})
        filtered_data[:loss_fraction] = [filtered_data[:loss_fraction]];
    end 
    _storage = LongDurationStorage{commodity}(;
        id=id,
        timedata=time_data,
        location = location,
        filtered_data...
    )
    return _storage
end
LongDurationStorage(id::Symbol, data::Dict{Symbol,Any}, time_data::TimeData, commodity::DataType, location::Union{Missing,Symbol} = missing) =
    make_long_duration_storage(id, data, time_data, commodity, location)

function add_linking_variables!(g::LongDurationStorage, model::Model)

    g.capacity = @variable(model, lower_bound = 0.0, base_name = "vCAP_$(id(g))_period$(period_index(g))")

    g.storage_initial =
    @variable(model, [r in modeled_subperiods(g)], lower_bound = 0.0, base_name = "vSTOR_INIT_$(g.id)_period$(period_index(g))")

    g.storage_change =
    @variable(model, [w in subperiod_indices(g)], base_name = "vSTOR_CHANGE_$(g.id)_period$(period_index(g))")

end


function planning_model!(g::LongDurationStorage, model::Model)

    if !g.can_expand
        fix(new_units(g), 0.0; force = true)
    end

    if !g.can_retire
        fix(retired_units(g), 0.0; force = true)
    end

    compute_fixed_costs!(g, model)

    @constraint(model, retired_capacity(g) <= existing_capacity(g))

    MODELED_SUBPERIODS = modeled_subperiods(g)
    NPeriods = length(MODELED_SUBPERIODS);

    @constraint(model,[r in MODELED_SUBPERIODS], 
        storage_initial(g, r) <= capacity(g)
    )

    @constraint(model, [r in MODELED_SUBPERIODS], 
        storage_initial(g, mod1(r + 1, NPeriods)) == storage_initial(g, r) + storage_change(g, subperiod_map(g,r))
    )

end


function operation_model!(g::LongDurationStorage, model::Model)

    g.storage_level = @variable(
        model,
        [t in time_interval(g)],
        lower_bound = 0.0,
        base_name = "vSTOR_$(g.id)_period$(period_index(g))"
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
                        (1 - loss_fraction(g,timestepbefore(t, 1, subperiods(g)))) *
                        (storage_level(g, timestepbefore(t, 1, subperiods(g))) - storage_change(g, current_subperiod(g,t)))
                    else
                        -storage_level(g, t) +
                        (1 - loss_fraction(g,timestepbefore(t, 1, subperiods(g)))) *
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

    newcon = LongDurationStorageChangeConstraint();
    add_model_constraint!(newcon, g, model)
    push!(g.constraints, newcon)

    # subperiod_end = Dict(w => last(get_subperiod(g, w)) for w in subperiod_indices(g));

    # @constraint(model, [w in subperiod_indices(g)], 
    #     storage_initial(g, w) ==  storage_level(g,subperiod_end[w]) - storage_change(g, w)
    # )

end

function compute_investment_costs!(g::AbstractStorage, model::Model, cost_type::Function=pv_period_investment_cost)
    if has_capacity(g)
        if can_expand(g)
            add_to_expression!(
                    model[:eInvestmentFixedCost],
                    cost_type(g),
                    new_capacity(g),
                )
        end
    end
end

function compute_om_fixed_costs!(g::AbstractStorage, model::Model, cost_type::Function=pv_period_fixed_om_cost)
    if has_capacity(g)
        if fixed_om_cost(g) > 0
            add_to_expression!(
                model[:eOMFixedCost],
                cost_type(g),
                capacity(g),
            )
        end
    end
end

function compute_fixed_costs!(g::AbstractStorage, model::Model, cost_type::Symbol=:PV)
    allowed_cost_types = [:PV, :CF]
    if !(cost_type in allowed_cost_types)
        error("Invalid cost type: $cost_type. Allowed types are: $(allowed_cost_types)")
    end
    invesment_cost_function = Dict{Symbol, Function}(
        :PV => pv_period_investment_cost,
        :CF => cf_period_investment_cost
    )
    fom_cost_function = Dict{Symbol, Function}(
        :PV => pv_period_fixed_om_cost,
        :CF => cf_period_fixed_om_cost
    )
    compute_investment_costs!(g, model, invesment_cost_function[cost_type])
    compute_om_fixed_costs!(g, model, fom_cost_function[cost_type])
end

# Function to filter storages with capacity variables from a Vector of storages.
storages_with_capacity_variables(storages::Vector{<:AbstractStorage}) =
    AbstractStorage[storage for storage in storages if has_capacity(storage)]
