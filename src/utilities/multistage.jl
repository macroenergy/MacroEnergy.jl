function initialize_stage_capacities!(system::System, system_prev::System)

    for a in system.assets
        a_prev_index = findfirst(id.(system_prev.assets).==id(a))
        if isnothing(a_prev_index)
            @info("Skipping asset $(id(a)) as it was not present in the previous stage")
        else
            a_prev = system_prev.assets[a_prev_index];
            initialize_stage_capacities!(a, a_prev)
        end
    end

end

function initialize_stage_capacities!(a::AbstractAsset, a_prev::AbstractAsset)

    for t in fieldnames(typeof(a))
        initialize_stage_capacities!(getfield(a,t), getfield(a_prev,t))
    end

end

function initialize_stage_capacities!(y::Union{AbstractEdge,AbstractStorage},y_prev::Union{AbstractEdge,AbstractStorage})
    if has_capacity(y_prev)
        y.existing_capacity = capacity(y_prev)
        for prev_stage in keys(new_capacity_track(y_prev))
            y.new_capacity_track[prev_stage] = new_capacity_track(y_prev,prev_stage)
            y.retired_capacity_track[prev_stage] = retired_capacity_track(y_prev,prev_stage)
        end
    end
end
function initialize_stage_capacities!(g::Transformation,g_prev::Transformation)
    return nothing
end
function initialize_stage_capacities!(n::Node,n_prev::Node)
    return nothing
end

function discount_fixed_costs!(system::System)
    for a in system.assets
        discount_fixed_costs!(a, system.settings)
    end
end

function discount_fixed_costs!(a::AbstractAsset,settings::NamedTuple)
    for t in fieldnames(typeof(a))
        discount_fixed_costs!(getfield(a, t), settings)
    end
end

function discount_fixed_costs!(y::Union{AbstractEdge,AbstractStorage},settings::NamedTuple)
    
    # Number of years of payments that are remaining
    model_years_remaining = sum(settings.StageLengths[stage_index(y):end]; init = 0);
    payment_years_remaining = min(capital_recovery_period(y), model_years_remaining);

    y.investment_cost = investment_cost(y) * sum(1 / (1 + wacc(y))^s for s in 1:payment_years_remaining; init=0);

    opexmult = sum([1 / (1 + settings.WACC)^(i - 1) for i in 1:settings.StageLengths[stage_index(y)]])

    y.fixed_om_cost = fixed_om_cost(y) * opexmult

end
function discount_fixed_costs!(g::Transformation,settings::NamedTuple)
    return nothing
end
function discount_fixed_costs!(n::Node,settings::NamedTuple)
    return nothing
end

function add_age_based_retirements!(a::AbstractAsset,model::Model)

    for t in fieldnames(typeof(a))
        y = getfield(a, t)
        if isa(y,AbstractEdge) || isa(y,Storage)
            if y.retirement_stage > 0
                push!(y.constraints, AgeBasedRetirementConstraint())
                add_model_constraint!(y.constraints[end], y, model)
            end
        end
    end

end

#### All new capacity built up to the retirement stage must retire in the current stage
function get_retirement_stage(cur_stage::Int,lifetime::Int,stage_lengths::Vector{Int})

    return maximum(filter(r -> sum(stage_lengths[t] for t in r+1:cur_stage; init=0) >= lifetime,1:cur_stage-1);init=0)

end

function compute_retirement_stage!(system::System)
    
    for a in system.assets
        compute_retirement_stage!(a,collect(system.settings.StageLengths))
    end

    return nothing
end

function compute_retirement_stage!(a::AbstractAsset, stage_lengths::Vector{Int})

    for t in fieldnames(typeof(a))
        y = getfield(a, t)
        
        if :retirement_stage ∈ Base.fieldnames(typeof(y))
            if can_retire(y)
                y.retirement_stage = get_retirement_stage(stage_index(y),lifetime(y),stage_lengths)
            end
        end
    end

    return nothing
end

