"""
    write_costs(
        file_path::AbstractString, 
        system::System, 
        model::Union{Model,NamedTuple}; 
        scaling::Float64=1.0, 
        drop_cols::Vector{<:AbstractString}=String[]
    )

Write the optimal costs for the system to a file.
The extension of the file determines the format of the file.

# Arguments
- `file_path::AbstractString`: The path to the file where the results will be written
- `system::System`: The system containing the assets/edges to analyze as well as the settings for the output
- `model::Union{Model,NamedTuple}`: The optimal model after the optimization
- `scaling::Float64`: The scaling factor for the results
- `drop_cols::Vector{<:AbstractString}`: Columns to drop from the DataFrame

# Returns
- `nothing`: The function returns nothing, but writes the results to the file
"""
function write_costs(
    file_path::AbstractString, 
    system::System, 
    model::Union{Model,NamedTuple};
    period_index::Int64=1,
    scaling::Float64=1.0, 
    drop_cols::Vector{<:AbstractString}=String[]
)
    @info "Writing discounted costs to $file_path"

    # Get costs and determine layout (wide or long)
    costs = get_optimal_discounted_costs(model,period_index; scaling)
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

function write_undiscounted_costs(
    file_path::AbstractString, 
    system::System, 
    model::Union{Model,NamedTuple};
    period_index::Int64=1,
    scaling::Float64=1.0, 
    drop_cols::Vector{<:AbstractString}=String[]
)
    @info "Writing undiscounted costs to $file_path"

    # Get costs and determine layout (wide or long)
    costs = get_optimal_undiscounted_costs(model,period_index; scaling)
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

function compute_fixed_costs!(g::Union{Node,Transformation},model::Model)
    return nothing
end

function compute_investment_costs!(system::System, model::Model)
    for a in system.assets
        compute_investment_costs!(a, model)
    end
end

function compute_investment_costs!(a::AbstractAsset, model::Model)
    for t in fieldnames(typeof(a))
        compute_investment_costs!(getfield(a, t), model)
    end
end

function compute_investment_costs!(g::Union{Node,Transformation},model::Model)
    return nothing
end