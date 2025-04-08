
function generate_decomposed_system(system_full::System)

    subperiod_indices = system_full.time_data[:Electricity].subperiod_indices;
    subperiods = system_full.time_data[:Electricity].subperiods;
    subperiod_weights = system_full.time_data[:Electricity].subperiod_weights;

    number_of_subperiods = length(subperiod_indices);

    system_decomp = Vector{System}(undef,number_of_subperiods)

    for i in 1:number_of_subperiods
        system_decomp[i] = deepcopy(system_full)
        w = subperiod_indices[i];

        for c in keys(system_full.time_data)
            system_decomp[i].time_data[c].time_interval = subperiods[i]
            system_decomp[i].time_data[c].subperiod_weights = Dict(w => subperiod_weights[w])
            system_decomp[i].time_data[c].subperiods = [subperiods[i]]
            system_decomp[i].time_data[c].subperiod_indices = [w]
            system_decomp[i].time_data[c].period_map = Dict(w => w)
        end
    end

    return system_decomp
end

function generate_operation_subproblem(system::System)

    model = Model()

    @variable(model, vREF == 1)

    model[:eVariableCost] = AffExpr(0.0)
    
    add_linking_variables!(system, model)

    linking_variables = name.(setdiff(all_variables(model), model[:vREF]))

    define_available_capacity!(system, model)

    operation_model!(system, model)

    @objective(model, Min, model[:eVariableCost])

    return model, linking_variables


end

function initialize_subproblem(system::Any,optimizer::Optimizer)
    
    subproblem,linking_variables_sub = generate_operation_subproblem(system);
 
    subproblem_index = get_subproblem_index(system);

    set_optimizer(subproblem, optimizer)

    set_silent(subproblem)

    return subproblem,linking_variables_sub,subproblem_index
end

function initialize_local_subproblems!(system_local::Vector,subproblems_local::Vector{Dict{Any,Any}},optimizer::Optimizer)

    nW = length(system_local)

    for i=1:nW
		subproblem,linking_variables_sub,subproblem_index = initialize_subproblem(system_local[i],optimizer);
        subproblems_local[i][:model] = subproblem;
        subproblems_local[i][:linking_variables_sub] = linking_variables_sub;
        subproblems_local[i][:subproblem_index] = subproblem_index;
    end
end

function initialize_subproblems!(system_decomp::Vector,optimizer::Optimizer,distributed_bool::Bool)
    if distributed_bool
        subproblems_dict, linking_variables_sub =  initialize_dist_subproblems!(system_decomp,optimizer)
    else
        subproblems_dict, linking_variables_sub = initialize_serial_subproblems!(system_decomp,optimizer)
    end
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
            initialize_local_subproblems!(system_local,localpart(subproblems_all),optimizer);
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

    initialize_local_subproblems!(system_decomp,subproblems_all,optimizer);

    linking_variables_sub = [get_local_linking_variables([subproblems_all[k]]) for k in 1:length(system_decomp)];

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

function get_subproblem_index(system::System)

    return system.time_data[:Electricity].subperiod_indices[1]

end