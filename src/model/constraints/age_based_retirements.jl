Base.@kwdef mutable struct AgeBasedRetirementConstraint <: PlanningConstraint
    value::Union{Missing,Vector{Float64}} = missing
    constraint_dual::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

function add_model_constraint!(ct::AgeBasedRetirementConstraint, y::Union{AbstractEdge,AbstractStorage}, model::Model)
    
    curr_period = period_index(y);
    ret_period = retirement_period(y);

    if ret_period==0
        #### None of the capacity built in previous case reaches its end of life before the current period
        return nothing
    else
        #### All new capacity built up to the retirement period must either retire or be retrofitted in the current period
        ct.constraint_ref = @constraint(
            model, 
            sum(new_capacity_track(y,k) for k=1:ret_period) <= sum(retired_capacity_track(y,k) for k=1:curr_period) + sum(retrofitted_capacity_track(y,k) for k=1:curr_period)
        )
        
    end

    return nothing
end
