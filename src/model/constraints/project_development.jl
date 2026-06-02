Base.@kwdef mutable struct DevelopmentConstraint <: PlanningConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end


function add_model_constraint!(ct::DevelopmentConstraint, y::Union{AbstractEdge,AbstractStorage}, model::Model, settings::NamedTuple)

    if settings[:ProjectDevelopment]
        
        curr_period = period_index(y)
        prev_period = curr_period - 1
        prev_period_de = curr_period - de_duration(y) + 1
        prev_period_af = af_duration(y) > 0 ? curr_period - af_duration(y) + 1 : curr_period
        prev_period_cc = curr_period - cc_duration(y) + 1

        model[:DECapacity] = AffExpr(0.0)
        model[:AFCapacity] = AffExpr(0.0)
        model[:CCCapacity] = AffExpr(0.0)

    
        if curr_period > 1
            # Carry over capacity from previous period
            add_to_expression!(model[:DECapacity], de_capacity_track(y, prev_period), 1.0)
            add_to_expression!(model[:AFCapacity], af_capacity_track(y, prev_period), 1.0)
            add_to_expression!(model[:CCCapacity], cc_capacity_track(y, prev_period), 1.0)

            # Subtract used capacity
            if af_duration(y) > 0
                add_to_expression!(model[:DECapacity], new_af_capacity_track(y, curr_period), -1.0)
            else
                add_to_expression!(model[:DECapacity], new_cc_capacity_track(y, curr_period), -1.0)
            end
            add_to_expression!(model[:AFCapacity], new_cc_capacity_track(y, curr_period), -1.0)
            add_to_expression!(model[:CCCapacity], new_capacity_track(y, curr_period), -1.0)

            # Constrain how much can be developed
            ct.constraint_ref = @constraint(model, new_capacity_track(y, curr_period) <= cc_capacity_track(y, prev_period))
            ct.constraint_ref = @constraint(model, new_cc_capacity_track(y, curr_period) <= af_capacity_track(y, prev_period))
            ct.constraint_ref = @constraint(model, new_af_capacity_track(y, curr_period) <= de_capacity_track(y, prev_period))
        else
            # Boundary condition for beginning of model horizon
            ct.constraint_ref = @constraint(model, new_capacity_track(y, curr_period) <= capacity_in_progress_init(y))
            ct.constraint_ref = @constraint(model, new_cc_capacity_track(y, curr_period) <= capacity_in_progress_init(y))
            ct.constraint_ref = @constraint(model, new_af_capacity_track(y, curr_period) <= capacity_in_progress_init(y))
            # New DE capacity is not constrained
        end

        # Add to cumulative capacity depending on length from start of model horizon
        if curr_period >= de_duration(y) 
            add_to_expression!(model[:DECapacity], new_de_capacity_track(y, prev_period_de), 1.0)
        else
            # Boundary condition for beginning of model horizon
            add_to_expression!(model[:DECapacity], capacity_in_progress_init(y), 1.0)
        end                 
        if curr_period >= af_duration(y) 
            add_to_expression!(model[:AFCapacity], new_af_capacity_track(y, prev_period_af), 1.0)
        else
            # Boundary condition for beginning of model horizon
            add_to_expression!(model[:AFCapacity], capacity_in_progress_init(y), 1.0)
        end                 
        if curr_period >= cc_duration(y) 
            add_to_expression!(model[:CCCapacity], new_cc_capacity_track(y, prev_period_cc), 1.0)
        else
            # Boundary condition for beginning of model horizon
            add_to_expression!(model[:CCCapacity], capacity_in_progress_init(y), 1.0)
        end

                         
        # Constrain cumulative capacity
        ct.constraint_ref = @constraint(model, de_capacity_track(y, curr_period) == model[:DECapacity])
        if af_duration(y) > 0
            ct.constraint_ref = @constraint(model, af_capacity_track(y, curr_period) == model[:AFCapacity])
        else
            ct.constraint_ref = @constraint(model, af_capacity_track(y, curr_period) == model[:DECapacity])
        end
        ct.constraint_ref = @constraint(model, cc_capacity_track(y, curr_period) == model[:CCCapacity])

        
    end

    return nothing

end
