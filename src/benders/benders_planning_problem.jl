function generate_planning_problem(system::System,subperiod_indices::Vector{Int64})

    model = Model()

    @variable(model, vREF == 1)

    model[:eFixedCost] = AffExpr(0.0)

    add_planning_variables!(system, model)

    add_planning_constraints!(system, model)

    @variable(model,vTHETA[w in subperiod_indices].>=0)

    @objective(model, Min, model[:eFixedCost] + sum(vTHETA))

    return model


end


function add_planning_constraints!(
    y::Union{AbstractEdge,AbstractVertex},
    model::Model,
)

    for ct in all_constraints(y)
        if isa(ct,PlanningConstraint)
            add_model_constraint!(ct, y, model)
        end
    end

    return nothing
end


function add_planning_constraints!(system::System,model::Model)

    add_planning_constraints!.(system.locations, Ref(model))

    add_planning_constraints!.(system.assets, Ref(model))

end

function add_planning_constraints!(a::AbstractAsset, model::Model)
    for t in fieldnames(typeof(a))
        add_planning_constraints!(getfield(a,t), model)
    end
    return nothing
end

function init_planning_problem(system::System,subperiod_indices::Vector{Int64})

    planning_problem = generate_planning_problem(system,subperiod_indices)

    planning_variables = name.(setdiff(all_variables(planning_problem),[planning_problem[:vREF];planning_problem[:vTHETA]]));

    planning_optimizer = optimizer_with_attributes(()->Main.Gurobi.Optimizer(Main.GRB_ENV),"Method"=>2,"BarConvTol"=>1e-3,"Crossover"=>0,"MIPGap"=>1e-3)

    set_optimizer(planning_problem,planning_optimizer)

    set_silent(planning_problem)

	return planning_problem, planning_variables
end

function solve_planning_problem(m::Model,planning_variables::Vector{String})
	
	
		optimize!(m)

        if has_values(m) #
            planning_sol =  (LB = objective_value(m), inv_cost =value(m[:eFixedCost]), values =Dict([s=>value.(variable_by_name(m,s)) for s in planning_variables]), theta = value.(m[:vTHETA])) 
        else
            compute_conflict!(m)
            list_of_conflicting_constraints = ConstraintRef[];
            for (F, S) in list_of_constraint_types(m)
                for con in all_constraints(m, F, S)
                    if get_attribute(con, MOI.ConstraintConflictStatus()) == MOI.IN_CONFLICT
                        push!(list_of_conflicting_constraints, con)
                    end
                end
            end
            display(list_of_conflicting_constraints)
            @error "The planning solution failed. This should not happen"
        end

        return planning_sol
end




