
function solve_int_level_set_problem(m::Model,planning_variables::Vector{String},planning_sol::NamedTuple,LB,UB,γ)
	
	@constraint(m,cLevel_set,m[:eFixedCost] + sum(m[:vTHETA])<=LB+γ*(UB-LB))

	@objective(m,Min, 0*sum(m[:vTHETA]))

    optimize!(m)

	if has_values(m)
		
		planning_sol = (;planning_sol..., inv_cost=value(m[:eFixedCost]), values=Dict([s=>value(variable_by_name(m,s)) for s in planning_variables]), theta = value.(m[:vTHETA]))

	else

		if !has_values(m)
			@warn  "the interior level set problem solution failed"
		else
			planning_sol = (;planning_sol..., inv_cost=value(m[:eFixedCost]), values=Dict([s=>value(variable_by_name(m,s)) for s in planning_variables]), theta = value.(m[:vTHETA]))
		end
	end


	delete(m,m[:cLevel_set])
	unregister(m,:cLevel_set)
	@objective(m,Min, m[:eFixedCost] + sum(m[:vTHETA]))
	
	return planning_sol

end
