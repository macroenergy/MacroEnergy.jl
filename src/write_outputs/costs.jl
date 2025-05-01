"""
    get_optimal_costs(model::Union{Model,NamedTuple}; scaling::Float64=1.0)

Get the total, fixed, and variable costs for the system.

# Arguments
- `model::Union{Model,NamedTuple}`: The optimal model after the optimization
- `scaling::Float64`: The scaling factor for the results
# Returns
- `DataFrame`: A dataframe containing the total, fixed, and variable costs for the system, with missing columns removed

# Example
```julia
get_optimal_costs(model)
3×8 DataFrame
 Row │ commodity  commodity_subtype  zone    resource_id  component_id  type    variable      value   
     │ Symbol     Symbol             Symbol  Symbol       Symbol        Symbol  Symbol        Float64 
─────┼───────────────────────────────────────────────────────────────────────────────────────────────
   1 │ all        cost               all     all          all           Cost    FixedCost     22471.1
   2 │ all        cost               all     all          all           Cost    VariableCost  14316.2
   3 │ all        cost               all     all          all           Cost    TotalCost     36787.3
```
"""
function get_optimal_costs(model::Union{Model,NamedTuple}; scaling::Float64=1.0)
    @debug " -- Getting optimal costs for the system."
    costs = prepare_costs(model, scaling)
    df = convert_to_dataframe(costs)
    df[!, (!isa).(eachcol(df), Vector{Missing})] # remove missing columns
end

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
    scaling::Float64=1.0, 
    drop_cols::Vector{<:AbstractString}=String[]
)
    @info "Writing costs to $file_path"

    # Get costs and determine layout (wide or long)
    costs = get_optimal_costs(model; scaling)
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
