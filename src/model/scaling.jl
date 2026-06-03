parameter_scaling_factor(settings::NamedTuple) = settings.ParameterScaling ? settings.ParameterScalingFactor : 1.0

# MacroEnergyScaling.scale_constraints!
function scale_constraints!(system::System, model::Model)
    if system.settings.ConstraintScaling
        @info "Scaling constraints and RHS"
        scale_constraints!(model)
    end
    return nothing
end

# MacroEnergyScaling.scale_constraints!
function scale_constraints!(systems::Vector{System}, models::Vector{Model})
    @assert length(systems) == length(models)
    for (system, model) in zip(systems, models)
        scale_constraints!(system, model)
    end
    return nothing
end

# MacroEnergyScaling.scale_constraints!
function scale_constraints!(case::Case, models::Vector{Model})
    scale_constraints!(case.systems, models)
    return nothing
end
