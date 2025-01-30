
Base.@kwdef mutable struct Storage{T} <: AbstractVertex
    @AbstractVertexBaseAttributes()
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
all_constraints(g::Storage) = g.constraints;
capacity_storage(g::Storage) = g.capacity_storage;
charge_edge(g::Storage) = g.charge_edge;
charge_discharge_ratio(g::Storage) = g.charge_discharge_ratio;
commodity_type(g::Storage{T}) where {T} = T;
discharge_edge(g::Storage) = g.discharge_edge;
existing_capacity_storage(g::Storage) = g.existing_capacity_storage;
fixed_om_cost_storage(g::Storage) = g.fixed_om_cost_storage;
investment_cost_storage(g::Storage) = g.investment_cost_storage;
min_capacity_storage(g::Storage) = g.min_capacity_storage;
max_capacity_storage(g::Storage) = g.max_capacity_storage;
max_duration(g::Storage) = g.max_duration;
max_storage_level(g::Storage) = g.max_storage_level;
min_duration(g::Storage) = g.min_duration;
min_outflow_fraction(g::Storage) = g.min_outflow_fraction;
min_storage_level(g::Storage) = g.min_storage_level;
new_capacity_storage(g::Storage) = g.new_capacity_storage;
ret_capacity_storage(g::Storage) = g.ret_capacity_storage;
spillage_edge(g::Storage) = g.spillage_edge;
storage_level(g::Storage) = g.storage_level;
storage_level(g::Storage, t::Int64) = storage_level(g)[t];
storage_loss_fraction(g::Storage) = g.storage_loss_fraction;
######### Storage interface #########


function add_linking_variables!(g::Storage, model::Model)

    g.new_capacity_storage =
    @variable(model, lower_bound = 0.0, base_name = "vNEWCAPSTOR_$(g.id)")

    g.ret_capacity_storage =
    @variable(model, lower_bound = 0.0, base_name = "vRETCAPSTOR_$(g.id)")


end

function define_available_capacity!(g::Storage, model::Model)

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

function write_2_json(s::Storage)
    json_output =  Dict{Symbol,Any}(
        :type => string(commodity_type(s)),
        :instance_data => Dict{Symbol,Any}(
            :id => s.id,
            :can_expand => s.can_expand,
            :can_retire => s.can_retire,
            :charge_discharge_ratio => s.charge_discharge_ratio,
            :existing_capacity_storage => s.existing_capacity_storage,
            :investment_cost_storage => s.investment_cost_storage,
            :fixed_om_cost_storage => s.fixed_om_cost_storage,
            :storage_loss_fraction => s.storage_loss_fraction,
            :min_duration => s.min_duration,
            :max_duration => s.max_duration,
            :min_outflow_fraction => s.min_outflow_fraction,
            :min_storage_level => s.min_storage_level,
            :max_storage_level => s.max_storage_level,
            :min_capacity_storage => s.min_capacity_storage,
            :max_capacity_storage => s.max_capacity_storage,
            :new_capacity_storage => s[:new_capacity_storage],
            :ret_capacity_storage => s[:ret_capacity_storage],
            :storage_level => s[:storage_level],
        )
    )
    return json_output
end