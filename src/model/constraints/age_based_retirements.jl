Base.@kwdef mutable struct AgeBasedRetirementConstraint <: PlanningConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

function add_model_constraint!(ct::AgeBasedRetirementConstraint, e::AbstractEdge, model::Model)
    
    curr_stage = stage_index(e);
    ret_stage = retirement_stage(e);

    if ret_stage==0
        #### None of the capacity built in previous stages reaches its end of life before the current stage
        return nothing
    else
        #### All new capacity built up to the retirement stage must retire in the current stage
        ct.constraint_ref = @constraint(
            model, 
            sum(new_capacity_track(e,k) for k=1:ret_stage) <= sum(retired_capacity_track(e,k) for k=1:curr_stage)
        )
        
    end

    return nothing
end

function add_model_constraint!(ct::AgeBasedRetirementConstraint, g::Storage, model::Model)
    
    curr_stage = stage_index(g);
    ret_stage = retirement_stage(g);

    if ret_stage==0
        #### None of the capacity built in previous stages reaches its end of life before the current stage
        return nothing
    else
        #### All new capacity built up to the retirement stage must retire in the current stage

        ct.constraint_ref = @constraint(
            model, 
            sum(new_storage_capacity_track(g,k) for k=1:ret_stage) <= sum(retired_storage_capacity_track(g,k) for k=1:curr_stage)
        )
        
    end

    return nothing
end