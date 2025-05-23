function scaling!(y::Union{AbstractVertex,AbstractEdge})
    atts_vec = attributes_to_scale(y)
    ScalingFactor = 1e3
    for f in atts_vec
        setfield!(y, f, getfield(y, f) / ScalingFactor)
    end

end

function scaling!(a::AbstractAsset)
    for t in fieldnames(typeof(a))
        scaling!(getfield(a, t))
    end
    return nothing
end

function scaling!(system::System)

    @info("Scaling system data to GWh | ktons | M\$")

    scaling!.(system.locations)

    scaling!.(system.assets)

    return nothing
end

function attributes_to_scale(n::Node)
    return [:demand, :max_supply, :price, :price_nsd, :price_supply, :price_unmet_policy, :rhs_policy]
end

function attributes_to_scale(e::Edge)
    return [:capacity_size, :existing_capacity, :fixed_om_cost, :investment_cost, :investment_cost_init, :capacity_initial, :max_capacity, :min_capacity, :variable_om_cost]
end

function attributes_to_scale(e::EdgeWithUC)
    return [:capacity_size, :existing_capacity, :fixed_om_cost, :investment_cost, :investment_cost_init, :capacity_initial, :max_capacity, :min_capacity, :variable_om_cost, :startup_cost]
end

function attributes_to_scale(g::AbstractStorage)
    return [:capacity_size,:existing_capacity,:fixed_om_cost,:investment_cost, :investment_cost_init, :capacity_initial, :max_capacity, :min_capacity]
end

function attributes_to_scale(t::Transformation)
    return Symbol[]
end


function /(d::Dict, factor::Float64)
    for (k, v) in d
        d[k] = v / factor
    end
    return d
end

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