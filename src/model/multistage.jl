function carry_over_capacities!(system::System, system_prev::System; perfect_foresight::Bool = true)

    for a in system.assets
        a_prev_index = findfirst(id.(system_prev.assets).==id(a))
        if isnothing(a_prev_index)
            @info("Skipping asset $(id(a)) as it was not present in the previous stage")
        else
            a_prev = system_prev.assets[a_prev_index];
            carry_over_capacities!(a, a_prev ; perfect_foresight)
        end
    end

end

function carry_over_capacities!(a::AbstractAsset, a_prev::AbstractAsset; perfect_foresight::Bool = true)

    for t in fieldnames(typeof(a))
        carry_over_capacities!(getfield(a,t), getfield(a_prev,t); perfect_foresight)
    end

end

function carry_over_capacities!(y::Union{AbstractEdge,AbstractStorage},y_prev::Union{AbstractEdge,AbstractStorage}; perfect_foresight::Bool = true)
    if has_capacity(y_prev)
        
        if perfect_foresight
            y.existing_capacity = capacity(y_prev)
        else
            y.existing_capacity = value(capacity(y_prev))
        end
        
        for prev_stage in keys(new_capacity_track(y_prev))
            if perfect_foresight
                y.new_capacity_track[prev_stage] = new_capacity_track(y_prev,prev_stage)
                y.retired_capacity_track[prev_stage] = retired_capacity_track(y_prev,prev_stage)
            else
                y.new_capacity_track[prev_stage] = value(new_capacity_track(y_prev,prev_stage))
                y.retired_capacity_track[prev_stage] = value(retired_capacity_track(y_prev,prev_stage))
            end
        end
        
    end
end
function carry_over_capacities!(g::Transformation,g_prev::Transformation; perfect_foresight::Bool = true)
    return nothing
end
function carry_over_capacities!(n::Node,n_prev::Node; perfect_foresight::Bool = true)
    return nothing
end

function discount_fixed_costs!(system::System, settings::NamedTuple)
    for a in system.assets
        discount_fixed_costs!(a, settings)
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

function undo_discount_fixed_costs!(system::System, settings::NamedTuple)
    for a in system.assets
        undo_discount_fixed_costs!(a, settings)
    end
end

function undo_discount_fixed_costs!(a::AbstractAsset,settings::NamedTuple)
    for t in fieldnames(typeof(a))
        undo_discount_fixed_costs!(getfield(a, t), settings)
    end
end

function undo_discount_fixed_costs!(y::Union{AbstractEdge,AbstractStorage},settings::NamedTuple)
    # Number of years of payments that are remaining
    model_years_remaining = sum(settings.StageLengths[stage_index(y):end]; init = 0);
    payment_years_remaining = min(capital_recovery_period(y), model_years_remaining);
    y.investment_cost = investment_cost(y) / sum(1 / (1 + wacc(y))^s for s in 1:payment_years_remaining; init=0);
    opexmult = sum([1 / (1 + settings.WACC)^(i - 1) for i in 1:settings.StageLengths[stage_index(y)]])
    y.fixed_om_cost = fixed_om_cost(y) / opexmult
end
function undo_discount_fixed_costs!(g::Transformation,settings::NamedTuple)
    return nothing
end
function undo_discount_fixed_costs!(n::Node,settings::NamedTuple)
    return nothing
end

function compute_real_costs!(model::Model, system::System, settings::NamedTuple)
    
    undo_discount_fixed_costs!(system, settings)

    unregister(model,:eFixedCost)
    model[:eFixedCost] = AffExpr(0.0)
    compute_fixed_costs!(system, model)

    stage_lengths = collect(settings.StageLengths)
    wacc = settings.WACC
    stage_index = system.time_data[:Electricity].stage_index;

    cum_years = sum(stage_lengths[i] for i in 1:stage_index-1; init=0);
    discount_factor = 1/( (1 + wacc)^cum_years)
    opexmult = sum([1 / (1 + wacc)^(i - 1) for i in 1:stage_lengths[stage_index]])

    unregister(model,:eVariableCost)
    model[:eVariableCost] = model[:eDiscountedVariableCost][stage_index]/(discount_factor * opexmult);

end

function compute_fixed_costs!(system::System, model::Model)
    for a in system.assets
        compute_fixed_costs!(a, model)
    end
end
function compute_fixed_costs!(a::AbstractAsset, model::Model)
    for t in fieldnames(typeof(a))
        compute_fixed_costs!(getfield(a, t), model)
    end
end
function compute_fixed_costs!(y::Union{AbstractEdge,AbstractStorage}, model::Model)
    if has_capacity(y)
        if can_expand(y)
            add_to_expression!(
                    model[:eFixedCost],
                    investment_cost(y),
                    new_capacity(y),
                )
        end
        add_to_expression!(
            model[:eFixedCost],
            fixed_om_cost(y),
            capacity(y),
        )
    end
end

function compute_fixed_costs!(g::Union{Node,Transformation},model::Model)
    return nothing
end

function write_discounted_costs(
    file_path::AbstractString, 
    system::System, 
    model::Model; 
    scaling::Float64=1.0, 
    drop_cols::Vector{<:AbstractString}=String[]
)
    @info "Writing discounted costs to $file_path"

    # Get costs and determine layout (wide or long)
    costs = get_optimal_discounted_costs(model, system.time_data[:Electricity].stage_index; scaling)
    layout = get_output_layout(system, :Costs)

    if layout == "wide"
        default_drop_cols = ["commodity", "commodity_subtype", "zone", "resource_id", "component_id", "type"]
        # Only use default_drop_cols if user didn't specify any
        drop_cols = isempty(drop_cols) ? default_drop_cols : drop_cols
        costs = reshape_wide(costs)
    end

    write_dataframe(file_path, costs, drop_cols)
    return nothing
end

function get_optimal_discounted_costs(model::Model,stage_index::Int64; scaling::Float64=1.0)
    @debug " -- Getting optimal discounted costs for the system."
    costs = prepare_discounted_costs(model, stage_index, scaling)
    df = convert_to_dataframe(costs)
    df[!, (!isa).(eachcol(df), Vector{Missing})] # remove missing columns
end

function prepare_discounted_costs(model::Model, stage_index::Int64, scaling::Float64=1.0)
    fixed_cost = value(model[:eDiscountedFixedCost][stage_index])
    variable_cost = value(model[:eDiscountedVariableCost][stage_index])
    total_cost = fixed_cost + variable_cost
    OutputRow[
        OutputRow(
            :all,
            :cost,
            :all,
            :all,
            :all,
            :Cost,
            :DiscountedFixedCost,
            missing,
            missing,
            missing,
            fixed_cost * scaling^2,
            # :USD,
        ),
        OutputRow(
            :all,
            :cost,
            :all,
            :all,
            :all,
            :Cost,
            :DiscountedVariableCost,
            missing,
            missing,
            missing,
            variable_cost * scaling^2,
            # :USD,
        ),
        OutputRow(
            :all,
            :cost,
            :all,
            :all,
            :all,
            :Cost,
            :DiscountedTotalCost,
            missing,
            missing,
            missing,
            total_cost * scaling^2,
            # :USD,
        )
    ]
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

function compute_retirement_stage!(system::System, stage_lengths::Vector{Int})
    
    for a in system.assets
        compute_retirement_stage!(a, stage_lengths)
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

