function generate_decomposed_system(system_full::Vector{Any},w::StepRange{Int64,Int64})

    system = deepcopy(system_full)
    for y in system
        restrict_to_subperiod!(y,w);
    end
    
    return system
end

function restrict_to_subperiod!(y::Union{AbstractNode,AbstractTransform,AbstractTransformationEdge,AbstractEdge},w::StepRange{Int64,Int64})

    y.timedata.timesteps = w;
    y.timedata.subperiod_weights = Dict(w => y.timedata.subperiod_weights[w]);
    y.timedata.subperiods = [w];

end

function generate_operational_subproblems(system_vec::Vector{Vector{Any}})

    subproblem_vec = generate_subproblem.(system_vec);
    
    return subproblem_vec

end

function generate_subproblem(system::Vector{Any})
    model = Model()

    @variable(model, vREF == 1)

    @expression(model, eVariableCost, 0 * model[:vREF])

    add_subproblem_planning_variables!.(system,Ref(model))

    add_operation_variables!.(system, Ref(model))

    add_operation_constraints!.(system, Ref(model))

    @objective(model, Min, model[:eVariableCost])

    return model

end

function generate_master(system::Vector{Any},subperiods::Vector{StepRange{Int64,Int64}})
    model = Model()

    @variable(model, vREF == 1)

    @expression(model, eFixedCost, 0 * model[:vREF])

    add_planning_variables!.(system,Ref(model))

    add_planning_constraints!.(system, Ref(model))

    @variable(model,theta[w in subperiods].>=0)

    @objective(model, Min, model[:eFixedCost] + sum(theta))

    return model

end

function add_subproblem_planning_variables!(e::AbstractEdge,model::Model)

    e.planning_vars[:capacity] = @variable(
        model,
        lower_bound = 0.0,
        base_name = "vCAPEDGE_$(start_node_id(e))_$(end_node_id(e))"
    )
    
    return nothing
end

function add_subproblem_planning_variables!(n::AbstractNode,model::Model)

    if in(PolicyConstraint,supertype.(typeof.(n.constraints)))
        ct_all = findall(PolicyConstraint.==supertype.(typeof.(n.constraints)));
        for ct in ct_all
            
            ct_type = typeof(n.constraints[ct]);
            
            n.planning_vars[Symbol(string(ct_type)*"_Budget")] = @variable(
            model,
            [w in subperiods(n)],
            base_name = "v"*string(ct_type)*"_Budget_$(get_id(n))"
            )
        end
    end
    return nothing
end

function add_subproblem_planning_variables!(g::AbstractTransform,model::Model)

    edges_vec = collect(values(edges(g)));

    add_subproblem_planning_variables!.(edges_vec,model)
    if has_storage(g)
        g.planning_vars[:capacity_storage] = @variable(
            model,
            lower_bound = 0.0,
            base_name = "vCAPSTOR_$(g.id)"
        )
    end
end

function add_subproblem_planning_variables!(e::AbstractTransformationEdge,model::Model)

    if has_planning_variables(e)
        e.planning_vars[:capacity] = @variable(
            model,
            lower_bound = 0.0,
            base_name = "vCAP_$(get_transformation_id(e))_$(get_id(e))"
        )
    end

end


function add_operation_constraints!(
    y::Union{AbstractEdge,AbstractNode,AbstractTransformationEdge},
    model::Model,
)

    for ct in all_constraints(y)
        if supertype(typeof(ct))==OperationConstraint
            add_model_constraint!(ct, y, model)
        end
    end

    return nothing
end

function add_operation_constraints!(y::AbstractTransform, model::Model)

    for ct in all_constraints(y)
        if supertype(typeof(ct)) == OperationConstraint
            add_model_constraint!(ct, y, model)
        end
    end

    edges_vec = collect(values(edges(y)));

    add_operation_constraints!.(edges_vec,model)

    return nothing
end


function add_planning_constraints!(
    y::Union{AbstractEdge,AbstractNode,AbstractTransformationEdge},
    model::Model,
)

    for ct in all_constraints(y)
        if supertype(typeof(ct))==PlanningConstraint
            add_model_constraint!(ct, y, model)
        end
    end

    return nothing
end

function add_planning_constraints!(y::AbstractTransform, model::Model)

    for ct in all_constraints(y)
        if supertype(typeof(ct)) == PlanningConstraint
            add_model_constraint!(ct, y, model)
        end
    end

    edges_vec = collect(values(edges(y)));

    add_planning_constraints!.(edges_vec,model)

    return nothing
end