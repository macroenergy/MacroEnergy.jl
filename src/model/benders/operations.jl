function generate_operation_subproblem(system::System,case_settings::NamedTuple,include_subproblem_slacks::Bool)

    model = Model()

    @variable(model, vREF == 1)

    model[:eVariableCost] = AffExpr(0.0)
    
    add_linking_variables!(system, model)

    linking_variables = name.(setdiff(all_variables(model), model[:vREF]))

    define_available_capacity!(system, model)

    operation_model!(system, model)

    if include_subproblem_slacks == true
        @info("Adding slack variables to ensure subproblems are always feasible")
        slack_penalty = 2*maximum(coefficient(model[:eVariableCost],v) for v in all_variables(model))
        eq_cons_to_be_relaxed =  get_all_balance_constraints(system);
        less_ineq_cons_to_be_relaxed = get_all_policy_constraints(system);
        greater_ineq_cons_to_be_relaxed = Vector{ConstraintRef}();
        add_slack_variables!(model,slack_penalty,eq_cons_to_be_relaxed,less_ineq_cons_to_be_relaxed,greater_ineq_cons_to_be_relaxed)
    end
    
    period_index = system.time_data[:Electricity].period_index

    period_lengths = collect(case_settings.PeriodLengths)

    discount_rate = case_settings.DiscountRate

    discount_factor = present_value_factor(discount_rate, period_lengths)
    
    opexmult = present_value_annuity_factor.(discount_rate, period_lengths)

    @objective(model, Min, discount_factor[period_index] * opexmult[period_index] * model[:eVariableCost])

    return model, linking_variables


end

function initialize_subproblem(system::Any,optimizer::Optimizer,case_settings::NamedTuple,include_subproblem_slacks::Bool)
    
    subproblem,linking_variables_sub = generate_operation_subproblem(system,case_settings,include_subproblem_slacks);

    set_optimizer(subproblem, optimizer)

    set_silent(subproblem)

    if system.settings.ConstraintScaling
        @info "Scaling constraints and RHS"
        scale_constraints!(subproblem)
    end

    return subproblem,linking_variables_sub
end

function initialize_local_subproblems!(system_local::Vector,subproblems_local::Vector{Dict{Any,Any}},local_indices::UnitRange{Int64},optimizer::Optimizer,case_settings::NamedTuple, include_subproblem_slacks)

    nW = length(system_local)

    for i=1:nW
		subproblem,linking_variables_sub = initialize_subproblem(system_local[i],optimizer,case_settings,include_subproblem_slacks::Bool);
        subproblems_local[i][:model] = subproblem;
        subproblems_local[i][:linking_variables_sub] = linking_variables_sub;
        subproblems_local[i][:subproblem_index] = local_indices[i];
        subproblems_local[i][:system_local] = system_local[i]
    end
end

function initialize_subproblems!(system_decomp::Vector,opt::Dict,case_settings::NamedTuple,distributed_bool::Bool,include_subproblem_slacks::Bool)
    
    if distributed_bool
        subproblems, linking_variables_sub = initialize_dist_subproblems!(system_decomp,opt,case_settings,include_subproblem_slacks)
    else
        subproblems, linking_variables_sub = initialize_serial_subproblems!(system_decomp,opt,case_settings,include_subproblem_slacks)
    end

    return subproblems, linking_variables_sub
end

function initialize_dist_subproblems!(system_decomp::Vector,opt::Dict,case_settings::NamedTuple,include_subproblem_slacks::Bool)

    ##### Initialize a distributed arrays of JuMP models
	## Start pre-solve timer
     
	subproblem_generation_time = time()

    subproblems_all = distribute([Dict() for i in 1:length(system_decomp)]);

    @sync for p in workers()
        @async @spawnat p begin
            W_local = localindices(subproblems_all)[1];
            system_local = [system_decomp[k] for k in W_local];
            optimizer = create_optimizer(opt[:solver], opt_env(opt[:solver]), opt[:attributes])
            initialize_local_subproblems!(system_local,localpart(subproblems_all),W_local,optimizer,case_settings,include_subproblem_slacks);
        end
    end

	p_id = workers();
    np_id = length(p_id);

    linking_variables_sub = [Dict() for k in 1:np_id];

    @sync for k in 1:np_id
        @async linking_variables_sub[k]= @fetchfrom p_id[k] get_local_linking_variables(localpart(subproblems_all))
    end

	linking_variables_sub = merge(linking_variables_sub...);

    ## Record pre-solver time
	subproblem_generation_time = time() - subproblem_generation_time
	@info("Distributed operational subproblems generation took $(round(subproblem_generation_time, digits=3)) seconds")

    return subproblems_all,linking_variables_sub

end

function initialize_serial_subproblems!(system_decomp::Vector,opt::Dict,case_settings::NamedTuple,include_subproblem_slacks::Bool)

    ##### Initialize a array of JuMP models
	## Start pre-solve timer

    optimizer = create_optimizer(opt[:solver], opt_env(opt[:solver]), opt[:attributes])

	subproblem_generation_time = time()

    subproblems_all = [Dict() for i in 1:length(system_decomp)];

    initialize_local_subproblems!(system_decomp,subproblems_all, 1:length(system_decomp),optimizer,case_settings,include_subproblem_slacks);

    linking_variables_sub = [get_local_linking_variables([subproblems_all[k]]) for k in 1:length(system_decomp)];
    linking_variables_sub = merge(linking_variables_sub...);

    ## Record pre-solver time
	subproblem_generation_time = time() - subproblem_generation_time
	@info("Serial subproblems generation took $subproblem_generation_time seconds")

    return subproblems_all,linking_variables_sub

end

function get_local_linking_variables(subproblems_local::Vector{Dict{Any,Any}})

    local_variables=Dict();

    for sp in subproblems_local
		w = sp[:subproblem_index];
        local_variables[w] = sp[:linking_variables_sub]
    end

    return local_variables


end

function add_slack_variables!(model::Model,
                            slack_penalty::Float64, 
                            eq_cons::Vector,
                            less_ineq_cons::Vector,
                            greater_ineq_cons::Vector)

    @variable(model, myslack_max >= 0)

    if !isempty(less_ineq_cons)
        for c in less_ineq_cons
            set_normalized_coefficient(c, myslack_max, -1)
        end
    end

    if !isempty(greater_ineq_cons)
        for c in greater_ineq_cons
            set_normalized_coefficient(c, myslack_max, 1)
        end
    end

    if !isempty(eq_cons)
        n = length(eq_cons)
        @variable(model, myslack_eq[1:n])
        for i in 1:n
            set_normalized_coefficient(eq_cons[i], myslack_eq[i], -1)
        end
        @constraint(model, [i in 1:n], myslack_eq[i] <= myslack_max)
        @constraint(model, [i in 1:n], -myslack_eq[i] <= myslack_max)
    end

    model[:eVariableCost] += slack_penalty * myslack_max

    return nothing
end

function compute_slack_penalty_value(system::System)
    x = 0.0;
    for n in system.locations
        if isa(n,Node) && !isempty(non_served_demand(n))
            w = subperiod_indices(n)[1]
            y = subperiod_weight(n, w) * maximum(price_non_served_demand(n,s) for s in segments_non_served_demand(n))
            if y>x
                x = y
            end
        end
    end 

    
    if x==0.0
        penalty = 1e3;
    else
        penalty = 2*x
    end

    @info ("Slack penalty value: $penalty")

    return penalty

end

function get_all_balance_constraints(system::System)
    balance_constraints = Vector{JuMPConstraint}();
    for n in system.locations
        ### Add slacks also when non-served demand is modeled to cover cases where supply is greater than demand
        if isa(n,Node) #### && isempty(non_served_demand(n)) 
            for c in n.constraints
                if isa(c, BalanceConstraint)
                    for i in balance_ids(n)
                        for t in time_interval(n)
                            push!(balance_constraints, c.constraint_ref[i,t])
                        end
                    end
                end
            end
        end
    end 

    for a in system.assets
        for t in fieldnames(typeof(a))
            g = getfield(a,t);
            if isa(g,LongDurationStorage)
                for c in g.constraints
                    if isa(c, BalanceConstraint)
                        STARTS = [first(sp) for sp in subperiods(g)];
                        for i in balance_ids(g)
                            for t in STARTS
                                push!(balance_constraints, c.constraint_ref[i,t])
                            end
                        end
                    end
                    if isa(c, LongDurationStorageChangeConstraint)
                        for w in subperiod_indices(g)
                            push!(balance_constraints, c.constraint_ref[w])
                        end
                    end
                end
            end
        end
    end
    return balance_constraints
end


function get_all_policy_constraints(system::System)
    policy_constraints = Vector{JuMPConstraint}();
    for n in system.locations
        if isa(n,Node) && isempty(n.price_unmet_policy)
            for c in n.constraints
                if isa(c, PolicyConstraint)
                    for w in subperiod_indices(n)
                        push!(policy_constraints, c.constraint_ref[w])
                    end
                end
            end
        end
    end 
    return policy_constraints
end

function update_with_subproblem_solutions!(subproblems::Union{Vector{Dict{Any, Any}},DistributedArrays.DArray}, results::NamedTuple)

    subop_sol = MacroEnergySolvers.solve_subproblems(subproblems, results.planning_sol, true)

    results = (; results..., subop_sol = subop_sol)

    return nothing
    
end