function generate_model(case::Case, opt::Optimizer, ::Monolithic)
    @info("*** Generating monolithic model ***")

    if case.systems[1].settings.EnableJuMPDirectModel
        model = create_direct_model_with_optimizer(opt)
    else
        model = Model()
        set_optimizer(model, opt)
    end

    set_string_names_on_creation(model, case.systems[1].settings.EnableJuMPStringNames)

    @info("Generating model")
    start_time = time()

    @variable(model, vREF == 1)

    periods = get_periods(case)
    settings = get_settings(case)
    fixed_cost, investment_cost, om_fixed_cost, variable_cost = Dict(), Dict(), Dict(), Dict()

    for (period_idx, system) in enumerate(periods)
        next = period_idx < length(periods) ? periods[period_idx+1] : nothing
        add_period_to_model!(model, system, next, fixed_cost, investment_cost, om_fixed_cost, variable_cost)
    end

    finalize_model_objective!(model, settings, fixed_cost, investment_cost, om_fixed_cost, variable_cost)

    if case.systems[1].settings.ConstraintScaling
        @info "Scaling constraints and RHS"
        scale_constraints!(model)
    end
    
    @info(" -- Model generation complete, it took $(time() - start_time) seconds")
    
    return model
end

function generate_model(system::System, opt::Optimizer, settings::NamedTuple, ::Monolithic)
    @info("*** Generating monolithic model for period $(period_index(system)) ***")

    if system.settings.EnableJuMPDirectModel
        model = create_direct_model_with_optimizer(opt)
    else
        model = Model()
        set_optimizer(model, opt)
    end

    set_string_names_on_creation(model, system.settings.EnableJuMPStringNames)

    @variable(model, vREF == 1)

    fixed_cost, investment_cost, om_fixed_cost, variable_cost = Dict(), Dict(), Dict(), Dict()

    add_period_to_model!(model, system, nothing, fixed_cost, investment_cost, om_fixed_cost, variable_cost)

    finalize_model_objective!(model, settings, fixed_cost, investment_cost, om_fixed_cost, variable_cost)

    if system.settings.ConstraintScaling
        @info "Scaling constraints and RHS"
        scale_constraints!(model)
    end

    return model

end

function generate_model(case::Case, opt::Dict{Symbol,Dict{Symbol,Any}}, ::Benders)
    @info("*** Generating Benders decomposition model ***")
    
    planning_model = Model()
    planning_optimizer = opt[:planning]
    optimizer = create_optimizer(planning_optimizer[:solver], opt_env(planning_optimizer[:solver]), planning_optimizer[:attributes])
    set_optimizer(planning_model, optimizer)
    set_silent(planning_model)
    
    @info("Generating planning problem")
    start_time = time()
    
    @variable(planning_model, vREF == 1)
    
    periods = get_periods(case)
    settings = get_settings(case)
    fixed_cost, investment_cost, om_fixed_cost = Dict(), Dict(), Dict()

    periods_decomp = generate_decomposed_system(periods)
    
    for (i, system) in enumerate(periods)
        next = i < length(periods) ? periods[i+1] : nothing
        add_period_to_planning_model!(planning_model, system, next, fixed_cost, investment_cost, om_fixed_cost)
    end
    
    finalize_planning_model_objective!(planning_model, periods, settings, fixed_cost, investment_cost, om_fixed_cost)
    
    @info(" -- Planning problem generation complete, it took $(time() - start_time) seconds")
    
    if case.systems[1].settings.ConstraintScaling
        @info "Scaling constraints and RHS"
        scale_constraints!(planning_model)
    end
    
    bd_setup = settings.BendersSettings
    subproblems, linking_variables_sub = generate_subproblems(
        periods_decomp, opt[:subproblems], settings,
        bd_setup[:Distributed], bd_setup[:IncludeSubproblemSlacksAutomatically]
    )

    return BendersModel(bd_setup, case, planning_model, subproblems, linking_variables_sub)
end

function generate_model(system::System, opt::Dict{Symbol,Dict{Symbol,Any}}, settings::NamedTuple, ::Benders)
    @info("*** Generating Benders decomposition model ***")
    
    model = Model()
    planning_optimizer = opt[:planning]
    optimizer = create_optimizer(planning_optimizer[:solver], opt_env(planning_optimizer[:solver]), planning_optimizer[:attributes])
    set_optimizer(model, optimizer)
    set_silent(model)
    
    @info("Generating planning problem for period $(period_index(system))")
    
    @variable(model, vREF == 1)
    
    fixed_cost, investment_cost, om_fixed_cost = Dict(), Dict(), Dict()
    
    period_decomp = generate_decomposed_system([system])
    
    add_period_to_planning_model!(model, system, nothing, fixed_cost, investment_cost, om_fixed_cost)
    
    finalize_planning_model_objective!(model, [system], settings, fixed_cost, investment_cost, om_fixed_cost)
    
    if system.settings.ConstraintScaling
        @info "Scaling constraints and RHS"
        scale_constraints!(model)
    end
    
    bd_setup = settings.BendersSettings
    subproblems, linking_variables_sub = generate_subproblems(
        period_decomp, opt[:subproblems], settings,
        bd_setup[:Distributed], bd_setup[:IncludeSubproblemSlacksAutomatically]
    )

    return BendersModel(bd_setup, system, model, subproblems, linking_variables_sub)
end

function add_period_to_model!(
    model::Model,
    system::System,
    next_system::Union{System, Nothing},
    fixed_cost::Dict,
    investment_cost::Dict,
    om_fixed_cost::Dict,
    variable_cost::Dict
)
    model[:eVariableCost] = AffExpr(0.0)

    build_period_planning!(model, system, next_system)

    @info(" -- Generating operational model")
    operation_model!(system, model)

    store_and_unregister_costs!(model, system, fixed_cost, investment_cost, om_fixed_cost)

    variable_cost[period_index(system)] = model[:eVariableCost]
    unregister(model, :eVariableCost)
end

"""Set up the shared planning components for a single period: cost expressions,
linking variables, available capacity, planning model, retrofitting, age-based
retirements, and capacity carry-over."""
function build_period_planning!(
    model::Model,
    system::System,
    next_system::Union{System, Nothing}
)
    @info(" -- Period $(period_index(system))")

    model[:eFixedCost] = AffExpr(0.0)
    model[:eInvestmentFixedCost] = AffExpr(0.0)
    model[:eOMFixedCost] = AffExpr(0.0)

    @info(" -- Adding linking variables")
    add_linking_variables!(system, model)

    @info(" -- Defining available capacity")
    define_available_capacity!(system, model)

    @info(" -- Generating planning model")
    planning_model!(system, model)

    if system.settings.Retrofitting
        @info(" -- Adding retrofit constraints")
        add_retrofit_constraints!(system, model)
    end

    @info(" -- Including age-based retirements")
    add_age_based_retirements!.(system.assets, model)

    if !isnothing(next_system)
        @info(" -- Available capacity in period $(period_index(system)) is being carried over to period $(period_index(next_system))")
        carry_over_capacities!(next_system, system)
    end
end

"""Store fixed cost expressions in the cost dicts and unregister them from the model."""
function store_and_unregister_costs!(model::Model, system::System, fixed_cost::Dict, investment_cost::Dict, om_fixed_cost::Dict)
    curr_period = period_index(system)
    model[:eFixedCost] = model[:eInvestmentFixedCost] + model[:eOMFixedCost]
    fixed_cost[curr_period] = model[:eFixedCost]
    investment_cost[curr_period] = model[:eInvestmentFixedCost]
    om_fixed_cost[curr_period] = model[:eOMFixedCost]
    unregister(model, :eFixedCost)
    unregister(model, :eInvestmentFixedCost)
    unregister(model, :eOMFixedCost)
end

function finalize_model_objective!(
    model::Model,
    settings::NamedTuple,
    fixed_cost::Dict,
    investment_cost::Dict,
    om_fixed_cost::Dict,
    variable_cost::Dict
)
    period_indices = sort(collect(keys(fixed_cost)))
    period_lengths = collect(settings.PeriodLengths)
    discount_rate = settings.DiscountRate
    discount_factor = present_value_factor(discount_rate, period_lengths)

    @expression(model, eFixedCostByPeriod[s in period_indices], discount_factor[s] * fixed_cost[s])

    @expression(model, eInvestmentFixedCostByPeriod[s in period_indices], discount_factor[s] * investment_cost[s])

    @expression(model, eOMFixedCostByPeriod[s in period_indices], discount_factor[s] * om_fixed_cost[s])

    @expression(model, eFixedCost, sum(eFixedCostByPeriod[s] for s in period_indices))

    opexmult = present_value_annuity_factor.(discount_rate, period_lengths)

    @expression(model, eVariableCostByPeriod[s in period_indices], discount_factor[s] * opexmult[s] * variable_cost[s])

    @expression(model, eVariableCost, sum(eVariableCostByPeriod[s] for s in period_indices))

    @objective(model, Min, model[:eFixedCost] + model[:eVariableCost])

    return nothing
end

function planning_model!(system::System, model::Model)

    for location in system.locations
        planning_model!(location, model)
    end

    for asset in system.assets
        planning_model!(asset, model)
    end

    add_constraints_by_type!(system, model, PlanningConstraint)

end


function operation_model!(system::System, model::Model)
    # CRM prepared in operation_model! so that the CRM expressions and the edge contributions always emitted into the same model object. 
    # Done so as to make it compatible with Benders where planning and operation models are separate.
    if !isempty(system.settings.CapacityReserveMargin)
        @info(" -- Including capacity reserve margins: $(keys(system.settings.CapacityReserveMargin))")
        prepare_capacity_reserve_margin!(system, model)
    end

    for location in system.locations
        operation_model!(location, model)
    end

    for asset in system.assets
        operation_model!(asset, model)
    end

    add_constraints_by_type!(system, model, OperationConstraint)
    
end

function planning_model!(a::AbstractAsset, model::Model)
    for t in fieldnames(typeof(a))
        planning_model!(getfield(a, t), model)
    end
    return nothing
end

function operation_model!(a::AbstractAsset, model::Model)
    for t in fieldnames(typeof(a))
        operation_model!(getfield(a, t), model)
    end
    return nothing
end

function add_linking_variables!(system::System, model::Model)

    for location in system.locations
        add_linking_variables!(location, model)
    end

    for asset in system.assets
        add_linking_variables!(asset, model)
    end
end

function add_linking_variables!(a::AbstractAsset, model::Model)
    for t in fieldnames(typeof(a))
        add_linking_variables!(getfield(a, t), model)
    end
end

function define_available_capacity!(system::System, model::Model)

    for location in system.locations
        define_available_capacity!(location, model)
    end

    for asset in system.assets
        define_available_capacity!(asset, model)
    end
end

function define_available_capacity!(a::AbstractAsset, model::Model)
    for t in fieldnames(typeof(a))
        define_available_capacity!(getfield(a, t), model)
    end
end

function add_age_based_retirements!(a::AbstractAsset,model::Model)

    for t in fieldnames(typeof(a))
        y = getfield(a, t)
        if isa(y,AbstractEdge) || isa(y,AbstractStorage)
            if retirement_period(y) > 0 || min_retired_capacity_track(y) > 0.0 ### Otherwise the constraint is trivially satisfied because the left hand side is zero
                push!(y.constraints, AgeBasedRetirementConstraint())
                add_model_constraint!(y.constraints[end], y, model)
            end
        end
    end

end

#### All new capacity built up to the retirement period must retire in the current period
### Key assumption: all capacity decisions are taken at the very beggining of the period.
### Example: Consider four periods of lengths [5,5,5,5] and technology with a lifetime of 15 years. 
### All capacity built in period 1 will have at most 10 years old at the start of period 3, so no age based retirement will be needed.
### In period 4 we will have to retire at least all new capacity built up until period get_retirement_period(4,15,[5,5,5,5])=1
function get_retirement_period(cur_period::Int,lifetime::Int,period_lengths::Vector{Int})

    return maximum(filter(r -> sum(period_lengths[t] for t in r:cur_period-1; init=0) >= lifetime,1:cur_period-1);init=0)

end

function compute_retirement_period!(system::System, period_lengths::Vector{Int})
    
    for a in system.assets
        compute_retirement_period!(a, period_lengths)
    end

    return nothing
end

function compute_retirement_period!(a::AbstractAsset, period_lengths::Vector{Int})

    for t in fieldnames(typeof(a))
        y = getfield(a, t)
        
        if :retirement_period ∈ Base.fieldnames(typeof(y))
            if can_retire(y)
                y.retirement_period = get_retirement_period(period_index(y),lifetime(y),period_lengths)
            end
        end
    end

    return nothing
end

function carry_over_capacities!(system::System, system_prev::System; perfect_foresight::Bool = true)

    for a in system.assets
        a_prev_index = findfirst(id.(system_prev.assets).==id(a))
        if isnothing(a_prev_index)
            @info("Skipping asset $(id(a)) as it was not present in the previous period")
            validate_existing_capacity(a)
        else
            a_prev = system_prev.assets[a_prev_index];
            carry_over_capacities!(a, a_prev ; perfect_foresight)
        end
    end

end

function carry_over_capacities!(a::AbstractAsset, a_prev::AbstractAsset; perfect_foresight::Bool = true)

    for t in fieldnames(typeof(a))
        carry_over_capacities!(getfield(a,t), getfield(a_prev,t); perfect_foresight)
    end

end

function carry_over_capacities!(y::Union{AbstractEdge,AbstractStorage},y_prev::Union{AbstractEdge,AbstractStorage}; perfect_foresight::Bool = true)
    if has_capacity(y_prev)
        
        if perfect_foresight
            y.existing_capacity = capacity(y_prev)
        else
            y.existing_capacity = value(capacity(y_prev))
        end

        for prev_period in keys(new_capacity_track(y_prev))
            if perfect_foresight
                y.new_capacity_track[prev_period] = new_capacity_track(y_prev,prev_period)
                y.retired_capacity_track[prev_period] = retired_capacity_track(y_prev,prev_period)

                if isa(y, AbstractEdge)
                    y.retrofitted_capacity_track[prev_period] = retrofitted_capacity_track(y_prev,prev_period)
                else
                    continue # Storage does not have retrofitted capacity
                end
            else
                y.new_capacity_track[prev_period] = value(new_capacity_track(y_prev,prev_period))
                y.retired_capacity_track[prev_period] = value(retired_capacity_track(y_prev,prev_period))

                if isa(y, AbstractEdge)
                    y.retrofitted_capacity_track[prev_period] = value(retrofitted_capacity_track(y_prev,prev_period))
                else
                    continue # Storage does not have retrofitted capacity
                    
                end
            end
        end
        
    end
end
function carry_over_capacities!(g::Transformation,g_prev::Transformation; perfect_foresight::Bool = true)
    return nothing
end
function carry_over_capacities!(n::Node,n_prev::Node; perfect_foresight::Bool = true)
    return nothing
end

function compute_annualized_costs!(system::System,settings::NamedTuple)
    for a in system.assets
        compute_annualized_costs!(a,settings)
    end
end

function compute_annualized_costs!(a::AbstractAsset,settings::NamedTuple)
    for t in fieldnames(typeof(a))
        compute_annualized_costs!(getfield(a, t),settings)
    end
end

function compute_annualized_costs!(y::Union{AbstractEdge,AbstractStorage},settings::NamedTuple)
    if isnothing(annualized_investment_cost(y))
        if iszero(investment_cost(y))
            y.annualized_investment_cost = 0.0
            return nothing
        end
        if ismissing(wacc(y))
            y.wacc = settings.DiscountRate;
        end
        y.annualized_investment_cost = investment_cost(y) * capital_recovery_factor(wacc(y), capital_recovery_period(y));
    end
    return nothing
end

function compute_annualized_costs!(g::Transformation,settings::NamedTuple)
    return nothing
end
function compute_annualized_costs!(n::Node,settings::NamedTuple)
    return nothing
end

function discount_fixed_costs!(system::System, settings::NamedTuple)
    for a in system.assets
        discount_fixed_costs!(a, settings)
    end
end

function discount_fixed_costs!(a::AbstractAsset,settings::NamedTuple)
    for t in fieldnames(typeof(a))
        discount_fixed_costs!(getfield(a, t), settings)
    end
end

function discount_fixed_costs!(y::Union{AbstractEdge,AbstractStorage},settings::NamedTuple)
    
    period_lengths = settings.PeriodLengths
    discount_rate = settings.DiscountRate
    period_idx = period_index(y)
    period_length = period_lengths[period_idx]

    # Number of years of payments that are remaining
    model_years_remaining = years_remaining(period_idx, period_lengths)

    # Myopic expansion only considers costs within the modeled period.
    # Costs that are consequently omitted will be added after the model run when reporting results.
    if isa(settings[:ExpansionHorizon], Myopic)
        payment_years_remaining = min(capital_recovery_period(y), period_length);
    elseif isa(settings[:ExpansionHorizon], PerfectForesight)
        payment_years_remaining = min(capital_recovery_period(y), model_years_remaining);
    else
        # Placeholder for other future cases like rolling horizon
        nothing
    end

    # This PV is relative to the start of the Case, not the start of the period
    y.pv_period_investment_cost = annualized_investment_cost(y) * present_value_annuity_factor(discount_rate, payment_years_remaining)
    
    period_pv_annuity_factor = present_value_annuity_factor(discount_rate, period_length)
    y.pv_period_fixed_om_cost = fixed_om_cost(y) * period_pv_annuity_factor
    y.pv_period_variable_om_cost = variable_om_cost(y) * period_pv_annuity_factor
end

function discount_fixed_costs!(g::Transformation,settings::NamedTuple)
    return nothing
end
function discount_fixed_costs!(n::Node,settings::NamedTuple)
    return nothing
end

function undo_discount_fixed_costs!(system::System, settings::NamedTuple)
    for a in system.assets
        undo_discount_fixed_costs!(a, settings)
    end
end

function undo_discount_fixed_costs!(a::AbstractAsset,settings::NamedTuple)
    for t in fieldnames(typeof(a))
        undo_discount_fixed_costs!(getfield(a, t), settings)
    end
end

function undo_discount_fixed_costs!(y::Union{AbstractEdge,AbstractStorage},settings::NamedTuple)
    
    period_lengths = settings.PeriodLengths
    discount_rate = settings.DiscountRate
    period_idx = period_index(y)

    # Number of years of payments that are remaining
    model_years_remaining = years_remaining(period_idx, period_lengths)
    
    # Include all annuities within the modeling horizon for all cases (including Myopic), since undiscounting only concerns reporting of results 
    payment_years_remaining = min(capital_recovery_period(y), model_years_remaining);

    # y.annualized_investment_cost = payment_years_remaining * annualized_investment_cost(y) * capital_recovery_factor(discount_rate, payment_years_remaining)

    # y.cf_period_investment_cost = payment_years_remaining * annualized_investment_cost(y)
    y.cf_period_investment_cost = payment_years_remaining * pv_period_investment_cost(y) * capital_recovery_factor(discount_rate, payment_years_remaining)
    y.cf_period_fixed_om_cost = period_lengths[period_idx] * fixed_om_cost(y)
    y.cf_period_variable_om_cost = period_lengths[period_idx] * variable_om_cost(y)
end

function undo_discount_fixed_costs!(g::Transformation,settings::NamedTuple)
    return nothing
end
function undo_discount_fixed_costs!(n::Node,settings::NamedTuple)
    return nothing
end

function add_costs_not_seen_by_myopic!(system::System, settings::NamedTuple)
    for a in system.assets
        add_costs_not_seen_by_myopic!(a, settings)
    end
end

function add_costs_not_seen_by_myopic!(y::Union{AbstractEdge,AbstractStorage}, settings::NamedTuple)
    
    period_lengths = settings.PeriodLengths
    discount_rate = settings.DiscountRate
    period_idx = period_index(y)

    model_years_remaining = years_remaining(period_idx, period_lengths)

    k_total  = min(capital_recovery_period(y), model_years_remaining)
    k_myopic = min(capital_recovery_period(y), period_lengths[period_idx])

    total_mult  = present_value_annuity_factor(discount_rate, k_total)
    myopic_mult = present_value_annuity_factor(discount_rate, k_myopic)

    # TODO: We can reorganize this to not need to mutate the pv investment cost
    y.pv_period_investment_cost += annualized_investment_cost(y) * (total_mult - myopic_mult)
end

function add_costs_not_seen_by_myopic!(a::AbstractAsset,settings::NamedTuple)
    for t in fieldnames(typeof(a))
        add_costs_not_seen_by_myopic!(getfield(a, t), settings)
    end
end

function add_costs_not_seen_by_myopic!(g::Transformation,settings::NamedTuple)
    return nothing
end

function add_costs_not_seen_by_myopic!(n::Node,settings::NamedTuple)
    return nothing
end

function validate_existing_capacity(asset::AbstractAsset)
    for t in fieldnames(typeof(asset))
        if isa(getfield(asset, t), AbstractEdge) || isa(getfield(asset, t), AbstractStorage)
            if existing_capacity(getfield(asset, t)) > 0
                msg = " -- Asset with id: \"$(id(asset))\" has existing capacity equal to $(existing_capacity(getfield(asset,t)))"
                msg *= "\nbut it was not present in the previous period. Please double check that the input data is correct."
                @warn(msg)
            end
        end
    end
end

function prepare_capacity_reserve_margin!(system::System, model::Model)

    capacity_reserve_margin_nodes = get_capacity_reserve_margin_nodes(system)

    capacity_reserve_margin_ids = keys(system.settings.CapacityReserveMargin)
    
    if capacity_reserve_margin_ids != keys(capacity_reserve_margin_nodes)
        missing_ids = setdiff(capacity_reserve_margin_ids, keys(capacity_reserve_margin_nodes))
        extra_ids = setdiff(keys(capacity_reserve_margin_nodes), capacity_reserve_margin_ids)
        if !isempty(missing_ids)
            msg  = " ++ Capacity reserve margin ids defined in settings but not associated with any node: $(collect(missing_ids)). Please double check the input data."
            @error(msg)
        end
        if !isempty(extra_ids)
            msg  = " ++ Capacity reserve margin ids associated with nodes but not defined in settings: $(collect(extra_ids)). Please double check the input data."
            @error(msg)
        end
    end

    if any(system.settings.CapacityReserveMargin[k] == 0.0 for k in capacity_reserve_margin_ids)
        zero_ids = collect(k for k in capacity_reserve_margin_ids if system.settings.CapacityReserveMargin[k] == 0.0)
        @warn(" ++ Capacity reserve margin id(s): $zero_ids are set to 0.0")
    end

    # The requirement is indexed by the timesteps of the nodes it covers, so those nodes must share
    # a time interval for the demand sum below to be well defined.
    for k in capacity_reserve_margin_ids
        nodes_k = capacity_reserve_margin_nodes[k]
        if !all(time_interval(n) == time_interval(first(nodes_k)) for n in nodes_k)
            error("Nodes assigned to capacity reserve margin id $k do not share the same time interval: $(collect(id(n) for n in nodes_k)). Please double check the input data.")
        end
    end

    # Build the time-indexed expression eCapacityReserveMargin[(k,t)] = -(1+β_k) * Σ_n demand(n,t).
    # Edges add their contributions during the operational model; see add_crm_contribution!.
    # A Dict rather than a JuMP container because the index set is not rectangular: each requirement
    # spans only the timesteps of its own nodes.
    model[:eCapacityReserveMargin] = Dict{Tuple{Symbol,Int64}, AffExpr}(
        (k, t) => AffExpr(-(1 + system.settings.CapacityReserveMargin[k]) *
                           sum(demand(n, t) for n in capacity_reserve_margin_nodes[k]))
        for k in capacity_reserve_margin_ids
        for t in time_interval(first(capacity_reserve_margin_nodes[k]))
    )

    # Guard against re-registering the constraint if a System is reused across model builds.
    if !any(c -> isa(c, CapacityReserveMarginConstraint), system.constraints)
        push!(system.constraints, CapacityReserveMarginConstraint())
    end

    return nothing

end

function get_capacity_reserve_margin_nodes(system::System)
    capacity_reserve_margin_nodes = Dict{Symbol,Vector{Node}}()
    nodes = get_nodes(system)
    for n in nodes
        crm_id = capacity_reserve_margin_id(n)
        if !ismissing(crm_id)
            if !haskey(capacity_reserve_margin_nodes,crm_id)
                capacity_reserve_margin_nodes[crm_id] = [n]
            else
                push!(capacity_reserve_margin_nodes[crm_id], n)
            end
        end
    end
    return capacity_reserve_margin_nodes
end
function create_direct_model_with_optimizer(opt::Optimizer)
    
    if !isnothing(opt.optimizer_env)
        @debug("Setting optimizer with environment $(opt.optimizer_env)")
        try 
            model = direct_model(MOI.instantiate(() -> opt.optimizer(opt.optimizer_env)));
        catch e
            error("Error creating direct_model with optimizer and optimizer environment: $e")
        end
    else
        @debug("Setting optimizer $(opt.optimizer)")
        model = direct_model(MOI.instantiate(opt.optimizer));
    end
    @debug("Setting optimizer attributes $(opt.attributes)")
    
    set_optimizer_attributes(model, opt)

    return model
end
