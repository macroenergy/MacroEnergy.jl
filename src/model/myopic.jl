struct MyopicResults
    models::Vector{Model}
end

function run_myopic_iteration!(case::Case, opt::Optimizer)
    periods = get_periods(case)
    num_periods = number_of_periods(case)
    fixed_cost = Dict()
    om_fixed_cost = Dict()
    investment_cost = Dict()
    variable_cost = Dict()
    models = Vector{Model}(undef, num_periods)

    period_lengths = collect(get_settings(case).PeriodLengths)

    discount_rate = get_settings(case).DiscountRate

    cum_years = [sum(period_lengths[i] for i in 1:s-1; init=0) for s in 1:num_periods];

    discount_factor = 1 ./ ( (1 + discount_rate) .^ cum_years)

    opexmult = [sum([1 / (1 + discount_rate)^(i) for i in 1:period_lengths[s]]) for s in 1:num_periods]

    for (period_idx,system) in enumerate(periods)
        @info(" -- Generating model for period $(period_idx)")
        model = Model()

        @variable(model, vREF == 1)

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

        @info(" -- Generating operational model")
        operation_model!(system, model)

        # Express myopic cost in present value from perspective of start of modeling horizon, in consistency with Monolithic version

        model[:eFixedCost] = model[:eInvestmentFixedCost] + model[:eOMFixedCost]
        fixed_cost[period_idx] = model[:eFixedCost];
        investment_cost[period_idx] = model[:eInvestmentFixedCost];
        om_fixed_cost[period_idx] = model[:eOMFixedCost];
	    unregister(model,:eFixedCost)
        unregister(model,:eInvestmentFixedCost)
        unregister(model,:eOMFixedCost)
        
        variable_cost[period_idx] = model[:eVariableCost];
        unregister(model,:eVariableCost)
    
        @expression(model, eFixedCostByPeriod[period_idx], discount_factor[period_idx] * fixed_cost[period_idx])

        @expression(model, eInvestmentFixedCostByPeriod[period_idx], discount_factor[period_idx] * investment_cost[period_idx])

        @expression(model, eOMFixedCostByPeriod[period_idx], discount_factor[period_idx] * om_fixed_cost[period_idx])
    
        @expression(model, eFixedCost, eFixedCostByPeriod[period_idx])
        
        @expression(model, eVariableCostByPeriod[period_idx], discount_factor[period_idx] * opexmult[period_idx] * variable_cost[period_idx])
    
        @expression(model, eVariableCost, eVariableCostByPeriod[period_idx])

        @objective(model, Min, model[:eFixedCost] + model[:eVariableCost])

        @info(" -- Including age-based retirements")
        add_age_based_retirements!.(system.assets, model)

        set_optimizer(model, opt)

        scale_constraints!(system, model)

        optimize!(model)

        if period_idx < num_periods
            @info(" -- Final capacity in period $(period_idx) is being carried over to period $(period_idx+1)")
            carry_over_capacities!(periods[period_idx+1], system, perfect_foresight=false)
        end

        models[period_idx] = model
    end

    return models
end