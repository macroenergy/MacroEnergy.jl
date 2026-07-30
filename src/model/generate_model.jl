
function generate_model(case::Case)

    periods = get_periods(case)
    settings = get_settings(case)
    num_periods = number_of_periods(case)

    @info("Generating model")

    start_time = time();

    model = Model()

    @variable(model, vREF == 1)

    fixed_cost = Dict()
    om_fixed_cost = Dict()
    investment_cost = Dict()
    variable_cost = Dict()

    for (period_idx,system) in enumerate(periods)

        @info(" -- Period $period_idx")

        model[:eFixedCost] = AffExpr(0.0)
        model[:eInvestmentFixedCost] = AffExpr(0.0)
        model[:eOMFixedCost] = AffExpr(0.0)
        model[:eVariableCost] = AffExpr(0.0)

        @info(" -- Adding linking variables")
        add_linking_variables!(system, model) 

        @info(" -- Defining available capacity")
        define_available_capacity!(system, model)

        @info(" -- Generating planning model")
        planning_model!(system, model)
        
        if system.settings.Retrofitting
            @info(" -- Adding retrofit constraints")
            add_retrofit_constraints!(system, period_idx, model)
        end

        @info(" -- Including age-based retirements")
        add_age_based_retirements!.(system.assets, model)

        if period_idx < num_periods
            @info(" -- Available capacity in period $(period_idx) is being carried over to period $(period_idx+1)")
            carry_over_capacities!(periods[period_idx+1], system)
        end

        @info(" -- Generating operational model")
        operation_model!(system, model)

        model[:eFixedCost] = model[:eInvestmentFixedCost] + model[:eOMFixedCost]
        fixed_cost[period_idx] = model[:eFixedCost];
        investment_cost[period_idx] = model[:eInvestmentFixedCost];
        om_fixed_cost[period_idx] = model[:eOMFixedCost];
	    unregister(model,:eFixedCost)
        unregister(model,:eInvestmentFixedCost)
        unregister(model,:eOMFixedCost)

        variable_cost[period_idx] = model[:eVariableCost];
        unregister(model,:eVariableCost)

    end

    #The settings are the same in all case, we have a single settings file that gets copied into each system struct
    period_lengths = collect(settings.PeriodLengths)

    discount_rate = settings.DiscountRate

    cum_years = [sum(period_lengths[i] for i in 1:s-1; init=0) for s in 1:num_periods];

    discount_factor = 1 ./ ( (1 + discount_rate) .^ cum_years)

    @expression(model, eFixedCostByPeriod[s in 1:num_periods], discount_factor[s] * fixed_cost[s])

    @expression(model, eInvestmentFixedCostByPeriod[s in 1:num_periods], discount_factor[s] * investment_cost[s])

    @expression(model, eOMFixedCostByPeriod[s in 1:num_periods], discount_factor[s] * om_fixed_cost[s])

    @expression(model, eFixedCost, sum(eFixedCostByPeriod[s] for s in 1:num_periods))

    opexmult = [sum([1 / (1 + discount_rate)^(i) for i in 1:period_lengths[s]]) for s in 1:num_periods]

    @expression(model, eVariableCostByPeriod[s in 1:num_periods], discount_factor[s] * opexmult[s] * variable_cost[s])

    @expression(model, eVariableCost, sum(eVariableCostByPeriod[s] for s in 1:num_periods))

    @objective(model, Min, model[:eFixedCost] + model[:eVariableCost])

    @info(" -- Model generation complete, it took $(time() - start_time) seconds")

    return model
    
end

function planning_model!(system::System, model::Model)

    planning_model!.(system.locations, Ref(model))

    planning_model!.(system.assets, Ref(model))

    add_constraints_by_type!(system, model, PlanningConstraint)

end


function operation_model!(system::System, model::Model)

    # Prepared here, rather than in the planning model, so that the capacity reserve margin
    # expressions and the edge contributions that fill them are always emitted into the same model
    # object. Under Benders the planning and operational models are distinct, so splitting the two
    # across passes would leave the row unbuildable; see add_crm_contribution!.
    if !isempty(system.settings.CapacityReserveMargin)
        @info(" -- Including capacity reserve margins: $(keys(system.settings.CapacityReserveMargin))")
        prepare_capacity_reserve_margin!(system, model)
    end

    operation_model!.(system.locations, Ref(model))

    operation_model!.(system.assets, Ref(model))

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

    add_linking_variables!.(system.locations, model)

    add_linking_variables!.(system.assets, model)

end

function add_linking_variables!(a::AbstractAsset, model::Model)
    for t in fieldnames(typeof(a))
        add_linking_variables!(getfield(a, t), model)
    end
end

function define_available_capacity!(system::System, model::Model)

    define_available_capacity!.(system.locations, model)

    define_available_capacity!.(system.assets, model)

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
            if y.retirement_period > 0 || y.min_retired_capacity > 0.0
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
        if ismissing(wacc(y))
            y.wacc = settings.DiscountRate;
        end
        annualization_factor = wacc(y)>0 ? wacc(y) / (1 - (1 + wacc(y))^-capital_recovery_period(y))  : 1.0
        y.annualized_investment_cost = investment_cost(y) * annualization_factor;
    end
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
    
    # Number of years of payments that are remaining
    model_years_remaining = sum(settings.PeriodLengths[period_index(y):end]; init = 0);

    # Myopic only considers costs within modeled period. Costs that are consequently omitted will be added after the model run when reporting results
    if isa(solution_algorithm(settings[:SolutionAlgorithm]), Myopic)
        payment_years_remaining = min(capital_recovery_period(y), settings.PeriodLengths[period_index(y)]);
    elseif isa(solution_algorithm(settings[:SolutionAlgorithm]), Monolithic) || isa(solution_algorithm(settings[:SolutionAlgorithm]), Benders)
        payment_years_remaining = min(capital_recovery_period(y), model_years_remaining);
    else
        # Placeholder for other future cases like rolling horizon
        nothing
    end

    y.annualized_investment_cost = annualized_investment_cost(y) * sum(1 / (1 + settings.DiscountRate)^s for s in 1:payment_years_remaining; init=0);
    
    opexmult = sum([1 / (1 + settings.DiscountRate)^(i) for i in 1:settings.PeriodLengths[period_index(y)]])

    y.fixed_om_cost = fixed_om_cost(y) * opexmult

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
    # Number of years of payments that are remaining
    model_years_remaining = sum(settings.PeriodLengths[period_index(y):end]; init = 0);
    
    # Include all annuities within the modeling horizon for all cases (including Myopic), since undiscounting only concerns reporting of results 
    payment_years_remaining = min(capital_recovery_period(y), model_years_remaining);

    y.annualized_investment_cost = payment_years_remaining * annualized_investment_cost(y) / sum(1 / (1 + settings.DiscountRate)^s for s in 1:payment_years_remaining; init=0);

    opexmult = sum([1 / (1 + settings.DiscountRate)^(i) for i in 1:settings.PeriodLengths[period_index(y)]])
    y.fixed_om_cost = settings.PeriodLengths[period_index(y)]*fixed_om_cost(y) / opexmult
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
    
    model_years_remaining = sum(settings.PeriodLengths[period_index(y):end]; init = 0);
    payment_years_remaining = min(capital_recovery_period(y), model_years_remaining);

    # Need to get the coefficient used by the model
    payment_years_remaining_myopic = min(capital_recovery_period(y), settings.PeriodLengths[period_index(y)]);

    total_mult = sum(1 / (1 + settings.DiscountRate)^s for s in 1:payment_years_remaining; init=0)
    myopic_mult = sum(1 / (1 + settings.DiscountRate)^s for s in 1:payment_years_remaining_myopic; init=0)

    y.annualized_investment_cost = annualized_investment_cost(y) * total_mult/myopic_mult;
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