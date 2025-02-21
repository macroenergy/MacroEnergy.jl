Base.@kwdef mutable struct AgeBasedRetirementConstraint <: PlanningConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

function add_model_constraint!(ct::AgeBasedRetirementConstraint, y::Union{AbstractEdge,AbstractStorage}, model::Model)
    
    curr_stage = stage_index(y);
    ret_stage = retirement_stage(y);

    if ret_stage==0
        #### None of the capacity built in previous stages reaches its end of life before the current stage
        return nothing
    else
        #### All new capacity built up to the retirement stage must retire in the current stage
        ct.constraint_ref = @constraint(
            model, 
            sum(new_capacity_track(y,k) for k=1:ret_stage) <= sum(retired_capacity_track(y,k) for k=1:curr_stage)
        )
        
    end

    return nothing
end
