Base.@kwdef mutable struct MaxCapacityGrowthConstraint <: PlanningConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end


function add_model_constraint!(ct::MaxCapacityGrowthConstraint, y::Union{AbstractEdge,AbstractStorage}, model::Model)

    curr_stage = period_index(y)
    prev_stage = curr_stage - 1
    # Rate of increase
    CAGR = 0.15
    # Rate of decline
    CADR = 0.1 + CAGR
    
    # Limit rate of increase
    if curr_stage >= 2
        ct.constraint_ref = @constraint(model, new_capacity_track(y,curr_stage) <= (1+CAGR)*new_capacity_track(y, prev_stage))
    end

    # Limit rate of decrease
    if curr_stage >= 2
        ct.constraint_ref = @constraint(model, new_capacity_track(y,curr_stage) >= (1-CADR)*new_capacity_track(y, prev_stage))
    end

    return nothing

end