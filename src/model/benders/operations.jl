function generate_operation_subproblem(system::System)

    model = Model()

    @variable(model, vREF == 1)

    model[:eVariableCost] = AffExpr(0.0)
    
    add_linking_variables!(system, model)

    linking_variables = name.(setdiff(all_variables(model), model[:vREF]))

    define_available_capacity!(system, model)

    operation_model!(system, model)

    @objective(model, Min, model[:eVariableCost])

    slack_penalty_value = compute_slack_penalty_value(system);

    return model, linking_variables, slack_penalty_value


end

function initialize_subproblem(system::Any,optimizer::Optimizer)
    
    subproblem,linking_variables_sub, slack_penalty_value = generate_operation_subproblem(system);

    set_optimizer(subproblem, optimizer)

    set_silent(subproblem)

    if system.settings.ConstraintScaling
        @info "Scaling constraints and RHS"
        scale_constraints!(subproblem)
    end

    return subproblem,linking_variables_sub, slack_penalty_value
end

function initialize_local_subproblems!(system_local::Vector,subproblems_local::Vector{Dict{Any,Any}},local_indices::UnitRange{Int64},optimizer::Optimizer)

    nW = length(system_local)

    for i=1:nW
		subproblem,linking_variables_sub, slack_penalty_value = initialize_subproblem(system_local[i],optimizer);
        subproblems_local[i][:model] = subproblem;
        subproblems_local[i][:linking_variables_sub] = linking_variables_sub;
        subproblems_local[i][:subproblem_index] = local_indices[i];
        subproblems_local[i][:slack_penalty_value] = slack_penalty_value;
    end
end

function initialize_subproblems!(system_decomp::Vector,optimizer::Optimizer,distributed_bool::Bool)
    
    if distributed_bool
        subproblems, linking_variables_sub =  initialize_dist_subproblems!(system_decomp,optimizer)
    else
        subproblems, linking_variables_sub = initialize_serial_subproblems!(system_decomp,optimizer)
    end

    return subproblems, linking_variables_sub
end

function initialize_dist_subproblems!(system_decomp::Vector,optimizer::Optimizer)

    ##### Initialize a distributed arrays of JuMP models
	## Start pre-solve timer
     
	subproblem_generation_time = time()

    subproblems_all = distribute([Dict() for i in 1:length(system_decomp)]);

    @sync for p in workers()
        @async @spawnat p begin
            W_local = localindices(subproblems_all)[1];
            system_local = [system_decomp[k] for k in W_local];
            initialize_local_subproblems!(system_local,localpart(subproblems_all),W_local,optimizer);
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
	println("Distributed operational subproblems generation took $subproblem_generation_time seconds")

    return subproblems_all,linking_variables_sub

end

function initialize_serial_subproblems!(system_decomp::Vector,optimizer::Optimizer)

    ##### Initialize a array of JuMP models
	## Start pre-solve timer
     
	subproblem_generation_time = time()

    subproblems_all = [Dict() for i in 1:length(system_decomp)];

    initialize_local_subproblems!(system_decomp,subproblems_all, 1:length(system_decomp),optimizer);

    linking_variables_sub = [get_local_linking_variables([subproblems_all[k]]) for k in 1:length(system_decomp)];
    linking_variables_sub = merge(linking_variables_sub...);

    ## Record pre-solver time
	subproblem_generation_time = time() - subproblem_generation_time
	println("Serial subproblems generation took $subproblem_generation_time seconds")

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

function compute_slack_penalty_value(system::System)
    x = 0.0;
    for n in system.locations
        if isa(n,Node)
            w = subperiod_indices(n)[1]
            y = subperiod_weight(n, w) * maximum(price_non_served_demand(n,s) for s in segments_non_served_demand(n))
            if y>x
                x = y
            end
        end
    end 
    return 2*x
end