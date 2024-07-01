Base.@kwdef mutable struct RampingLimitConstraint <:OperationConstraint
    value::Union{Missing,Vector{Float64}} = missing
    lagrangian_multiplier::Union{Missing,Vector{Float64}} = missing
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

function add_model_constraint!(
    ct::RampingLimitConstraint,
    e::AbstractTransformationEdge,
    model::Model,
    )
    
        #### For now these are set to zero because we are not modeling reserves
        reserves_term = @expression(model,[t in timesteps(e)],0 * model[:vREF])
        regulation_term = @expression(model,[t in timesteps(e)],0 * model[:vREF])
    
        eRampUp=@expression(model, 
        [t in timesteps(e)], 
        flow(e,t) - flow(e,timestepbefore(t,1,subperiods(e))) + regulation_term[t] + reserves_term[t] - ramp_up_fraction(e)*capacity(e)
        )
    
        eRampDown=@expression(model, 
        [t in timesteps(e)], 
        flow(e,timestepbefore(t,1,subperiods(e))) - flow(e,t) - regulation_term[t] + reserves_term[timestepbefore(t,1,subperiods(e))] - ramp_down_fraction(e)*capacity(e)
        )
    
        ramp_expr_dict = Dict(:RampUp=>eRampUp,:RampDown=>eRampDown)
    
        ct.constraint_ref = @constraint(
            model,
            [s in [:RampUp,:RampDown], t in timesteps(e)],
            ramp_expr_dict[s][t] <= 0
        )
    
        return nothing
end


function add_model_constraint!(
    ct::RampingLimitConstraint,
    e::AbstractTransformationEdgeWithUC,
    model::Model,
    )
    
        #### For now these are set to zero because we are not modeling reserves
        reserves_term=@expression(model,[t in timesteps(e)],0 * model[:vREF])
        regulation_term=@expression(model,[t in timesteps(e)],0 * model[:vREF])
          
        eRampUp=@expression(model, 
        [t in timesteps(e)],
        flow(e,t) - flow(e,timestepbefore(t,1,subperiods(e))) + regulation_term[t] + reserves_term[t] 
        -(ramp_up_fraction(e)*capacity_size(e)*(ucommit(e,t)-ustart(e,t))
        + min(capacity_factor(e,t),max(min_flow_fraction(e),ramp_up_fraction(e)))*capacity_size(e)*ustart(e,t)
        - min_flow_fraction(e)*capacity_size(e)*ushut(e,t))
        )

        eRampDown=@expression(model,
        [t in timesteps(e)],
        flow(e,timestepbefore(t,1,subperiods(e))) - flow(e,t) - regulation_term[t] + reserves_term[timestepbefore(t,1,subperiods(e))]
        -(ramp_down_fraction(e)*capacity_size(e)*(ucommit(e,t)-ustart(e,t))
            - min_flow_fraction(e)*capacity_size(e)*ustart(e,t)
            + min(capacity_factor(e,t),max(min_flow_fraction(e),ramp_down_fraction(e)))*capacity_size(e)*ushut(e,t)
            )
        )
    
        ramp_expr_dict = Dict(:RampUp=>eRampUp,:RampDown=>eRampDown)
    
        ct.constraint_ref = @constraint(
            model,
            [s in [:RampUp,:RampDown], t in timesteps(e)],
            ramp_expr_dict[s][t] <= 0
        )
        return nothing
end