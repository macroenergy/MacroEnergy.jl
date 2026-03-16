"""
Flow outputs - everything related to flow data extraction and output.
"""

## Write flow outputs ##
# This is the main function to write the flow outputs to a file.

"""
    write_flow(
        file_path::AbstractString, 
        system::System; 
        scaling::Float64=1.0, 
        drop_cols::Vector{<:AbstractString}=String[],
        commodity::Union{AbstractString,Vector{<:AbstractString},Nothing}=nothing,
        asset_type::Union{AbstractString,Vector{<:AbstractString},Nothing}=nothing
    )

Write the optimal flow results for the system to a file.
The extension of the file determines the format of the file.

## Filtering
Results can be filtered by:
- `commodity`: Specific commodity type(s)
- `asset_type`: Specific asset type(s)

## Pattern Matching
Two types of pattern matching are supported:

1. Parameter-free matching:
   - `"ThermalPower"` matches any `ThermalPower{...}` type (i.e. no need to specify parameters inside `{}`)

2. Wildcards using "*":
   - `"ThermalPower*"` matches `ThermalPower{Fuel}`, `ThermalPowerCCS{Fuel}`, etc.
   - `"CO2*"` matches `CO2`, `CO2Captured`, etc.

# Arguments
- `file_path::AbstractString`: The path to the file where the results will be written
- `system::System`: The system containing the edges to analyze as well as the settings for the output
- `scaling::Float64`: The scaling factor for the results
- `drop_cols::Vector{<:AbstractString}`: Columns to drop from the DataFrame
- `commodity::Union{AbstractString,Vector{<:AbstractString},Nothing}`: The commodity to filter by
- `asset_type::Union{AbstractString,Vector{<:AbstractString},Nothing}`: The asset type to filter by

# Returns
- `nothing`: The function returns nothing, but writes the results to the file

# Example
```julia
write_flow("flow.csv", system)
# Filter by commodity
write_flow("flow.csv", system, commodity="Electricity")
# Filter by commodity and asset type using parameter-free matching
write_flow("flow.csv", system, commodity="Electricity", asset_type="ThermalPower")
# Filter by commodity and asset type using wildcard matching
write_flow("flow.csv", system, commodity="Electricity", asset_type="ThermalPower*")
```
"""
function write_flow(
    file_path::AbstractString, 
    system::System; 
    scaling::Float64=1.0, 
    drop_cols::Vector{<:AbstractString}=String[],
    commodity::Union{AbstractString,Vector{<:AbstractString},Nothing}=nothing,
    asset_type::Union{AbstractString,Vector{<:AbstractString},Nothing}=nothing
)
    @info "Writing flow results to $file_path"

    # Get flow results and determine layout (wide or long)
    flow_results = get_optimal_flow(system; scaling, commodity, asset_type)
    layout = get_output_layout(system, :Flow)

    if layout == "wide"
        # df will be of size (time_steps, component_ids)
        flow_results = reshape_wide(flow_results, :time, :component_id, :value)
    end
    write_dataframe(file_path, flow_results, drop_cols)
    return nothing
end

# Function to write flow results from multiple dataframes
# This function is used when the results are distributed across multiple processes
function write_flows(file_path::AbstractString, 
    system::System, 
    flow_dfs::Vector{DataFrame}
)
    @info("Writing flow results to $file_path")

    # Concatenate flow results from subproblems belonging to the same period
    flow_results = reduce(vcat, flow_dfs)
    
    # Reshape if wide layout requested
    layout = get_output_layout(system, :Flow)
    if layout == "wide"
        flow_results = reshape_wide(flow_results, :time, :component_id, :value)
    end
    write_dataframe(file_path, flow_results)
end

## Flow extraction functions ##
"""
    get_optimal_flow(
        system::System; 
        scaling::Float64=1.0, 
        commodity::Union{AbstractString,Vector{<:AbstractString},Nothing}=nothing, 
        asset_type::Union{AbstractString,Vector{<:AbstractString},Nothing}=nothing
    )

Get the optimal flow values for all edges in a system.

## Filtering
Results can be filtered by:
- `commodity`: Specific commodity type(s)
- `asset_type`: Specific asset type(s)

## Pattern Matching
Two types of pattern matching are supported:

1. Parameter-free matching:
   - `"ThermalPower"` matches any `ThermalPower{...}` type (i.e. no need to specify parameters inside `{}`)

2. Wildcards using "*":
   - `"ThermalPower*"` matches `ThermalPower{Fuel}`, `ThermalPowerCCS{Fuel}`, etc.
   - `"CO2*"` matches `CO2`, `CO2Captured`, etc.

# Arguments
- `system::System`: The system containing the all edges to output   
- `scaling::Float64`: The scaling factor for the results.
- `commodity::Union{AbstractString,Vector{<:AbstractString},Nothing}`: The commodity to filter by
- `asset_type::Union{AbstractString,Vector{<:AbstractString},Nothing}`: The asset type to filter by

# Returns
- `DataFrame`: A dataframe containing the optimal flow values for all edges, with missing columns removed

# Example
```julia
get_optimal_flow(system)
186984×10 DataFrame
    Row │ commodity  zone        resource_id                component_id                       resource_type     component_type     variable  segment  time   value     
        │ Symbol     Symbol      Symbol                     Symbol                             String            String             Symbol    Int64    Int64  Float64
────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
      1 │ Biomass    bioherb_SE  SE_BECCS_Electricity_Herb  SE_BECCS_Electricity_Herb_biomas…  BECCSElectricity  Edge{Electricity}  flow      1        1      0.0    
      2 │ Biomass    bioherb_SE  SE_BECCS_Electricity_Herb  SE_BECCS_Electricity_Herb_biomas…  BECCSElectricity  Edge{Electricity}  flow      1        2      0.0    
      3 │ Biomass    bioherb_SE  SE_BECCS_Electricity_Herb  SE_BECCS_Electricity_Herb_biomas…  BECCSElectricity  Edge{Electricity}  flow      1        3      0.0    
      ...
# Filter by commodity
get_optimal_flow(system, commodity="Electricity")
# Filter by commodity and asset type using parameter-free matching
get_optimal_flow(system, commodity="Electricity", asset_type="ThermalPower") # only ThermalPower{Fuel} will be returned
# Filter by commodity and asset type using wildcard matching
get_optimal_flow(system, commodity="Electricity", asset_type="ThermalPower*") # all types starting with ThermalPower (e.g., ThermalPower{Fuel}, ThermalPowerCCS{Fuel}) will be returned)
```
"""
function get_optimal_flow(
    system::System; 
    scaling::Float64=1.0, 
    commodity::Union{AbstractString,Vector{<:AbstractString},Nothing}=nothing,
    asset_type::Union{AbstractString,Vector{<:AbstractString},Nothing}=nothing
)
    @debug " -- Getting optimal flow values for the system"
    edges, edge_asset_map = get_edges(system, return_ids_map=true)

    # filter edges by commodity
    if !isnothing(commodity)
        (commodity, missed_commodites) = search_commodities(commodity, string.(collect(Set(MacroEnergy.commodity_type.(edges)))))
        if !isempty(missed_commodites)
            @warn "Commodities not found: $(missed_commodites) when printing flow results"
        end
        filter_edges_by_commodity!(edges, commodity, edge_asset_map)
    end
    # filter edges by asset type
    if !isnothing(asset_type)
        (asset_type, missed_asset_type) = search_assets(asset_type, string.(unique(get_type(asset) for asset in values(edge_asset_map))))
        if !isempty(missed_asset_type)
            @warn "Asset type(s) not found: $(missed_asset_type) when printing flow results"
        end
        @debug("Writing flow results for asset type $asset_type")
        filter_edges_by_asset_type!(edges, asset_type, edge_asset_map)
    end
    if isempty(edges)
        @warn "No edges found after filtering"
        return DataFrame()
    end
    eflow = get_optimal_flow(edges, scaling, edge_asset_map)
    eflow[!, (!isa).(eachcol(eflow), Vector{Missing})] # remove missing columns
end

"""
    get_optimal_flow(asset::AbstractAsset, scaling::Float64=1.0)

Get the optimal flow values for all edges in an asset.

# Arguments
- `asset::AbstractAsset`: The asset containing the edges to analyze
- `scaling::Float64`: The scaling factor for the results.

# Returns
- `DataFrame`: A dataframe containing the optimal flow values for all edges, with missing columns removed

# Example
```julia
asset = get_asset_by_id(system, :elec_SE)
get_optimal_flow(asset)
```
"""
function get_optimal_flow(asset::AbstractAsset; scaling::Float64=1.0)
    @debug " -- Getting optimal flow values for the asset $(id(asset))"
    edges, edge_asset_map = get_edges(asset, return_ids_map=true)
    eflow = get_optimal_flow(edges, scaling, edge_asset_map)
    eflow[!, (!isa).(eachcol(eflow), Vector{Missing})] # remove missing columns
end

## Timeseries flow extraction functions ##
# The following functions are used to extract flow values after the model has been solved
# from a list of MacroObjects (e.g., edges, and storage) 
function get_optimal_flow(
    objs::Vector{<:AbstractEdge},
    scaling::Float64=1.0,
    obj_asset_map::Dict{Symbol,Base.RefValue{<:AbstractAsset}}=Dict{Symbol,Base.RefValue{<:AbstractAsset}}()
)
    reduce(vcat, [get_optimal_flow(o, scaling, obj_asset_map) for o in objs])
end

function get_optimal_flow(
    obj::AbstractEdge,
    scaling::Float64=1.0,
    obj_asset_map::Dict{Symbol,Base.RefValue{<:AbstractAsset}}=Dict{Symbol,Base.RefValue{<:AbstractAsset}}()
)
    time_axis = time_interval(obj)
    # Apply sign based on edge direction (negative for Node → Transformation/Storage)
    flow_sign = isa(obj, AbstractEdge) ? get_flow_sign(obj) : 1.0
    if isempty(obj_asset_map)
        return DataFrame(
            case_name = fill(missing, length(time_axis)),
            commodity = fill(get_commodity_name(obj), length(time_axis)),
            node_in = fill(get_node_in(obj), length(time_axis)),
            node_out = fill(get_node_out(obj), length(time_axis)),
            resource_id = fill(get_component_id(obj), length(time_axis)),
            component_id = fill(get_component_id(obj), length(time_axis)),
            component_type = fill(get_type(obj), length(time_axis)),
            variable = :flow,
            year = fill(missing, length(time_axis)),
            time = [t for t in time_axis],
            value = [value(flow(obj, t)) * scaling * flow_sign for t in time_axis]
        )
    else
        return DataFrame(
            case_name = fill(missing, length(time_axis)),
            commodity = fill(get_commodity_name(obj), length(time_axis)),
            node_in = fill(get_node_in(obj), length(time_axis)),
            node_out = fill(get_node_out(obj), length(time_axis)),
            resource_id = fill(isa(obj, Node) ? get_resource_id(obj) : get_resource_id(obj, obj_asset_map), length(time_axis)),
            component_id = fill(get_component_id(obj), length(time_axis)),
            resource_type = fill(isa(obj, Node) ? get_type(obj) : get_type(obj_asset_map[id(obj)]), length(time_axis)),
            component_type = fill(get_type(obj), length(time_axis)),
            variable = :flow,
            year = fill(missing, length(time_axis)),
            time = [t for t in time_axis],
            value = [value(flow(obj, t)) * scaling * flow_sign for t in time_axis]
        )
    end
end