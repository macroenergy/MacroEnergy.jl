# function restrict_to_subperiod!(y::Union{AbstractNode,AbstractEdge,AbstractTransform,AbstractTransformationEdge},w::Int64)
    
#     y.timedata.time_interval = get_subperiod(y,w);
#     y.timedata.subperiod_weights = Dict(w => subperiod_weight(y,w));
#     y.timedata.subperiods = [get_subperiod(y,w)];
#     y.timedata.subperiod_indices = [w];
# end
# function restrict_to_subperiod!(a::AbstractAsset,w::Int64)
#     for y in fieldnames(a)
#         restrict_to_subperiod!(getfield(a,y),w)
#     end
# end

function generate_decomposed_system(system_full::System,subperiod_indices::Vector{Int64})

    system_decomp = Dict{Int64,System}();
    
    for w in subperiod_indices
        system_decomp[w] = deepcopy(system_full)
        for c in keys(system_full.time_data)
            system_decomp[w].time_data[c].time_interval = system_full.time_data[c].subperiods[w];
            system_decomp[w].time_data[c].subperiod_weights = Dict(w => system_full.time_data[c].subperiod_weights[w]);
            system_decomp[w].time_data[c].subperiods = [system_full.time_data[c].subperiods[w]];
            system_decomp[w].time_data[c].subperiod_indices = [w];
        end
    end

    return system_decomp
end

function generate_benders_models(system::System)

    subperiod_indices = collect(eachindex(system.time_data[:Electricity].subperiods));

    planning_problem,planning_variables = init_planning_problem(system,subperiod_indices)

    system_decomp = generate_decomposed_system(system,subperiod_indices);

    #subproblems_dist,planning_variables_sub =init_dist_subproblems(system_decomp,planning_variables);

    benders_data = Dict();
	benders_data[:planning_problem] = planning_problem;
	benders_data[:planning_variables] = planning_variables;
    benders_data[:system_decomp] = system_decomp;
    #benders_data[:subproblems] = subproblems_dist;
	#benders_data[:planning_variables_sub] = planning_variables_sub;

    return benders_data


end

function check_negative_capacities(m::Model)

	neg_cap_bool = false;
	tol = -1e-8;
	if any(value.(m[:eTotalCap]).< tol) 
			neg_cap_bool = true;
	elseif haskey(m,:eTotalCapEnergy)
		if any(value.(m[:eTotalCapEnergy]).< tol)
			neg_cap_bool = true;
		end
	elseif haskey(m,:eTotalCapCharge)
		if any(value.(m[:eTotalCapCharge]).< tol)
			neg_cap_bool = true;
		end
	elseif haskey(m,:eAvail_Trans_Cap)
		if any(value.(m[:eAvail_Trans_Cap]).< tol)
			neg_cap_bool = true;
		end
	end
	return neg_cap_bool
	
end