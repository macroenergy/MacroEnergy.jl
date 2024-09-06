
function generate_operation_subproblem(system)
    
    model = Model()

    @variable(model, vREF == 1)

    model[:eVariableCost] = AffExpr(0.0)

    add_subproblem_planning_variables!(system,model)

    add_operation_variables!(system,model)

    add_operation_constraints!(system, model)

    @objective(model, Min, model[:eVariableCost])

    return model


end
function add_subproblem_planning_variables!(system::System,model::Model)

    add_subproblem_planning_variables!.(system.locations, Ref(model))

    add_subproblem_planning_variables!.(system.assets, Ref(model))

end

function add_subproblem_planning_variables!(e::AbstractEdge,model::Model)

    e.planning_vars[:capacity] = @variable(
        model,
        lower_bound = 0.0,
        base_name = "vCAPEDGE_$(start_node_id(e))_$(end_node_id(e))"
    )
    
    return nothing
end

function add_subproblem_planning_variables!(n::Node,model::Model)

    if in(PolicyConstraint,supertype.(typeof.(n.constraints)))
        ct_all = findall(PolicyConstraint.==supertype.(typeof.(n.constraints)));
        for ct in ct_all
            
            ct_type = typeof(n.constraints[ct]);
            
            n.planning_vars[Symbol(string(ct_type)*"_Budget")] = @variable(
            model,
            [w in subperiod_indices(n)],
            base_name = "v"*string(ct_type)*"_Budget_$(get_id(n))"
            )
        end
    end
    return nothing
end

function add_subproblem_planning_variables!(g::Storage,model::Model)
        
    g.planning_vars[:capacity_storage] = @variable(
        model,
        lower_bound = 0.0,
        base_name = "vCAPSTOR_$(g.id)"
    )
end


function add_subproblem_planning_variables!(a::AbstractAsset, model::Model)
    for t in fieldnames(typeof(a))
        add_subproblem_planning_variables!(getfield(a,t), model)
    end
    return nothing
end



function add_operation_constraints!(
    y::Union{AbstractEdge,AbstractVertex},
    model::Model,
)

    for ct in all_constraints(y)
        if isa(ct,OperationConstraint)
            add_model_constraint!(ct, y, model)
        end
    end

    return nothing
end


function add_operation_constraints!(system::System,model::Model)

    add_operation_constraints!.(system.locations, Ref(model))

    add_operation_constraints!.(system.assets, Ref(model))

end

function add_operation_constraints!(a::AbstractAsset, model::Model)
    for t in fieldnames(typeof(a))
        add_operation_constraints!(getfield(a,t), model)
    end
    return nothing
end



function init_subproblem(system::Vector{Union{AbstractAsset, Edge, Node}}, planning_variables::Vector{String})

    subproblem = generate_operation_subproblem(system)

    set_silent(subproblem)

    subproblem_optimizer = optimizer_with_attributes(()->Main.Gurobi.Optimizer(Main.GRB_ENV),"Method"=>2,"BarConvTol"=>1e-3,"Crossover"=>1)

    set_optimizer(subproblem,subproblem_optimizer)

    planning_variables_sub = intersect(name.(all_variables(subproblem)),planning_variables);

	for sv in planning_variables_sub
		if has_lower_bound(variable_by_name(subproblem,sv))
			delete_lower_bound(variable_by_name(subproblem,sv))
		end
		if has_upper_bound(variable_by_name(subproblem,sv))
			delete_upper_bound(variable_by_name(subproblem,sv))
		end
		set_objective_coefficient(subproblem,variable_by_name(subproblem,sv),0)
	end

    return subproblem, planning_variables_sub
end

function init_local_subproblems!(system_local::Vector{Vector{Union{AbstractAsset, Edge, Node}}},subproblems_local::Vector{Dict{Any,Any}},planning_variables::Vector{String})

    nW = length(system_local)

    for i=1:nW
		subproblem, planning_variables_sub = init_subproblem(system_local[i],planning_variables);
        subproblems_local[i][:model] = subproblem;
        subproblems_local[i][:planning_variables_sub] = planning_variables_sub
        subproblems_local[i][:subperiod_index] = subperiod_indices(system_local[i][1])[1]
    end
end

function init_dist_subproblems(system_decomp::Dict,planning_variables::Vector{String})

    ##### Initialize a distributed arrays of JuMP models
	## Start pre-solve timer
	subproblem_generation_time = time()
    
    subproblems_all = distribute([Dict() for i in 1:length(system_decomp)]);

    @sync for p in workers()
        @async @spawnat p begin
            W_local = localindices(subproblems_all)[1];
            system_local = [system_decomp[k] for k in W_local];
            init_local_subproblems!(system_local,localpart(subproblems_all),planning_variables);
        end
    end

	p_id = workers();
    np_id = length(p_id);

    planning_variables_sub = [Dict() for k in 1:np_id];

    @sync for k in 1:np_id
              @async planning_variables_sub[k]= @fetchfrom p_id[k] get_local_planning_variables(localpart(subproblems_all))
    end

	planning_variables_sub = merge(planning_variables_sub...);

    ## Record pre-solver time
	subproblem_generation_time = time() - subproblem_generation_time
	println("Distributed operational subproblems generation took $subproblem_generation_time seconds")

    return subproblems_all,planning_variables_sub

end

function get_local_planning_variables(subproblems_local::Vector{Dict{Any,Any}})

    local_variables=Dict();

    for sp in subproblems_local
		w = sp[:subperiod_index];
        local_variables[w] = sp[:planning_variables_sub]
    end

    return local_variables


end

function solve_dist_subproblems(m_subproblems::DArray{Dict{Any, Any}, 1, Vector{Dict{Any, Any}}},planning_sol::NamedTuple)

    p_id = workers();
    np_id = length(p_id);

    sub_results = [Dict() for k in 1:np_id];

    @sync for k in 1:np_id
              @async sub_results[k]= @fetchfrom p_id[k] solve_local_subproblem(localpart(m_subproblems),planning_sol); ### This is equivalent to fetch(@spawnat p .....)
    end

	sub_results = merge(sub_results...);

    return sub_results
end

function solve_local_subproblem(subproblem_local::Vector{Dict{Any,Any}},planning_sol::NamedTuple)

    local_sol=Dict();
    for sp in subproblem_local
        m = sp[:model];
        planning_variables_sub = sp[:planning_variables_sub]
        w = sp[:subperiod_index];
		local_sol[w] = solve_subproblem(m,planning_sol,planning_variables_sub);
    end
    return local_sol
end

function solve_subproblem(m::Model,planning_sol::NamedTuple,planning_variables_sub::Vector{String})

	
	fix_planning_variables!(m,planning_sol,planning_variables_sub)

	optimize!(m)
	
	if has_values(m)
		op_cost = objective_value(m);
		lambda = [dual(FixRef(variable_by_name(m,y))) for y in planning_variables_sub];
		theta_coeff = 1;	
	else
		op_cost = 0;
		lambda = zeros(length(planning_variables_sub));
		theta_coeff = 0;
        # compute_conflict!(m)
		# 		list_of_conflicting_constraints = ConstraintRef[];
		# 		for (F, S) in list_of_constraint_types(m)
		# 			for con in all_constraints(m, F, S)
		# 				if get_attribute(con, MOI.ConstraintConflictStatus()) == MOI.IN_CONFLICT
		# 					push!(list_of_conflicting_constraints, con)
		# 				end
		# 			end
		# 		end
        #         display(list_of_conflicting_constraints)
		@warn "The subproblem solution failed. This should not happen, double check the input files"
	end
    
	return (op_cost=op_cost,lambda = lambda,theta_coeff=theta_coeff)

end

function fix_planning_variables!(m::Model,planning_sol::NamedTuple,planning_variables_sub::Vector{String})
	for y in planning_variables_sub
		vy = variable_by_name(m,y);
		fix(vy,planning_sol.values[y];force=true)
		if is_integer(vy)
			unset_integer(vy)
		elseif is_binary(vy)
			unset_binary(vy)
		end
	end
end

 