"""
Storage level outputs - extraction and output of storage level data from storage units.
"""

"""
    write_storage_level(
        file_path::AbstractString, 
        system::System; 
        scaling::Float64=1.0, 
        drop_cols::Vector{<:AbstractString}=String[],
        commodity::Union{AbstractString,Vector{<:AbstractString},Nothing}=nothing,
        asset_type::Union{AbstractString,Vector{<:AbstractString},Nothing}=nothing
    )

Write the optimal storage level results for all storage units in a system to a file.
The extension of the file determines the format of the file (CSV, CSV.GZ, or Parquet).

## Filtering
Results can be filtered by:
- `commodity`: Specific commodity type(s)
- `asset_type`: Specific asset type(s)

## Pattern Matching
Two types of pattern matching are supported:

1. Parameter-free matching:
   - `"Battery"` matches any `Battery` type

2. Wildcards using "*":
   - `"*Storage"` matches types ending with Storage

# Arguments
- `file_path::AbstractString`: The path to the file where the results will be written
- `system::System`: The system containing the storage units to analyze
- `scaling::Float64`: The scaling factor for the results (default: 1.0)
- `drop_cols::Vector{<:AbstractString}`: Columns to drop from the DataFrame (default: empty)
- `commodity::Union{AbstractString,Vector{<:AbstractString},Nothing}`: The commodity to filter by
- `asset_type::Union{AbstractString,Vector{<:AbstractString},Nothing}`: The asset type to filter by

# Returns
- `nothing`: The function returns nothing, but writes the results to the file

# Example
```julia
write_storage_level("storage_level.csv", system)
write_storage_level("storage_level.csv", system, commodity="Electricity")
write_storage_level("storage_level.csv", system, asset_type="Battery")
```
"""
function write_storage_level(
    file_path::AbstractString, 
    system::System; 
    scaling::Float64=1.0, 
    drop_cols::Vector{<:AbstractString}=String[],
    commodity::Union{AbstractString,Vector{<:AbstractString},Nothing}=nothing,
    asset_type::Union{AbstractString,Vector{<:AbstractString},Nothing}=nothing
)
    @info "Writing storage level results to $file_path"

    # Get storage level results
    storage_level_results = get_optimal_storage_level(system; scaling, commodity, asset_type)
    
    if isempty(storage_level_results)
        @debug "No storage level results found (no storages have storage level variables)"
        return nothing
    end

    # Get output layout preference
    layout = get_output_layout(system, :StorageLevel)
    
    if layout == "wide"
        storage_level_results = reshape_wide(storage_level_results, :time, :component_id, :value)
    end
    
    write_dataframe(file_path, storage_level_results, drop_cols)
    return nothing
end

# Function to write storage level results from multiple dataframes
# This function is used when the results are distributed across multiple processes (Benders)
function write_storage_level(
    file_path::AbstractString, 
    system::System, 
    storage_level_dfs::Vector{DataFrame}
)
    @info "Writing storage level results to $file_path"

    # Filter out empty DataFrames and concatenate
    non_empty_dfs = filter(!isempty, storage_level_dfs)
    if isempty(non_empty_dfs)
        @debug "No storage level results found (no storages have storage level variables)"
        return nothing
    end
    
    storage_level_results = reduce(vcat, non_empty_dfs)
    
    # Reshape if wide layout requested
    layout = get_output_layout(system, :StorageLevel)
    if layout == "wide"
        storage_level_results = reshape_wide(storage_level_results, :time, :component_id, :value)
    end
    
    write_dataframe(file_path, storage_level_results)
    return nothing
end

## Storage level extraction functions ##

"""
    get_optimal_storage_level(
        system::System; 
        scaling::Float64=1.0,
        commodity::Union{AbstractString,Vector{<:AbstractString},Nothing}=nothing,
        asset_type::Union{AbstractString,Vector{<:AbstractString},Nothing}=nothing
    )

Get the optimal storage level values for all storage units in a system.

## Filtering
Results can be filtered by:
- `commodity`: Specific commodity type(s)
- `asset_type`: Specific asset type(s)

# Arguments
- `system::System`: The system containing the storage units to analyze
- `scaling::Float64`: The scaling factor for the results (default: 1.0)
- `commodity::Union{AbstractString,Vector{<:AbstractString},Nothing}`: The commodity to filter by
- `asset_type::Union{AbstractString,Vector{<:AbstractString},Nothing}`: The asset type to filter by

# Returns
- `DataFrame`: A dataframe containing the optimal storage level values, 
  with columns for commodity, zone, resource_id, component_id, resource_type, 
  component_type, variable, time, and value.

# Example
```julia
get_optimal_storage_level(system)
get_optimal_storage_level(system, commodity="Electricity")
get_optimal_storage_level(system, asset_type="Battery")
```
"""
function get_optimal_storage_level(
    system::System; 
    scaling::Float64=1.0,
    commodity::Union{AbstractString,Vector{<:AbstractString},Nothing}=nothing,
    asset_type::Union{AbstractString,Vector{<:AbstractString},Nothing}=nothing
)
    @debug " -- Getting optimal storage level values for the system"
    
    # Get all storages with their asset map
    storages, storage_asset_map = get_storages(system, return_ids_map=true)
    
    if isempty(storages)
        return DataFrame()
    end
    
    # Filter by commodity if specified
    if !isnothing(commodity)
        available_commodities = string.(collect(Set(typesymbol(commodity_type(s)) for s in storages)))
        (matched_commodity, missed_commodites) = search_commodities(commodity, available_commodities)
        if !isempty(missed_commodites)
            @warn "Commodities not found: $(missed_commodites) when printing storage level results"
        end
        filter!(s -> typesymbol(commodity_type(s)) in matched_commodity, storages)
        # Update storage_asset_map to match filtered storages
        storage_ids = Set(id.(storages))
        filter!(pair -> pair[1] in storage_ids, storage_asset_map)
    end
    
    # Filter by asset type if specified
    if !isnothing(asset_type)
        available_types = unique(get_type(asset) for asset in values(storage_asset_map))
        (matched_asset_type, missed_asset_types) = search_assets(asset_type, available_types)
        if !isempty(missed_asset_types)
            @warn "Asset type(s) not found: $(missed_asset_types) when printing storage level results"
        end
        # Filter storage_asset_map by type
        filter!(pair -> get_type(pair[2]) in matched_asset_type, storage_asset_map)
        # Filter storages to match
        filter!(s -> id(s) in keys(storage_asset_map), storages)
    end
    
    if isempty(storages)
        @warn "No storages found after filtering"
        return DataFrame()
    end
    
    storage_levels = get_optimal_storage_level(storages, scaling, storage_asset_map)
    storage_levels[!, (!isa).(eachcol(storage_levels), Vector{Missing})] # remove missing columns
end

"""
    get_optimal_storage_level(asset::AbstractAsset; scaling::Float64=1.0)

Get the optimal storage level values for all storage units in an asset.

# Arguments
- `asset::AbstractAsset`: The asset containing the storage units to analyze
- `scaling::Float64`: The scaling factor for the results

# Returns
- `DataFrame`: A dataframe containing the optimal storage level values

# Example
```julia
asset = get_asset_by_id(system, :battery_1)
get_optimal_storage_level(asset)
```
"""
function get_optimal_storage_level(asset::AbstractAsset; scaling::Float64=1.0)
    @debug " -- Getting optimal storage level values for the asset $(id(asset))"
    storages, storage_asset_map = get_storages(asset, return_ids_map=true)
    if isempty(storages)
        return DataFrame()
    end
    storage_levels = get_optimal_storage_level(storages, scaling, storage_asset_map)
    storage_levels[!, (!isa).(eachcol(storage_levels), Vector{Missing})] # remove missing columns
end

"""
    get_optimal_storage_level(
        storages::Vector{<:AbstractStorage}, 
        scaling::Float64=1.0,
        storage_asset_map::Dict{Symbol,Base.RefValue{<:AbstractAsset}}=Dict{Symbol,Base.RefValue{<:AbstractAsset}}()
    )

Get the optimal storage level values for a list of storage units.

# Arguments
- `storages::Vector{<:AbstractStorage}`: The storage units to extract values from
- `scaling::Float64`: The scaling factor for the results
- `storage_asset_map::Dict{Symbol,Base.RefValue{<:AbstractAsset}}`: Mapping of storage IDs to assets

# Returns
- `DataFrame`: A dataframe containing the optimal storage level values
"""
function get_optimal_storage_level(
    storages::Vector{<:AbstractStorage}, 
    scaling::Float64=1.0,
    storage_asset_map::Dict{Symbol,Base.RefValue{<:AbstractAsset}}=Dict{Symbol,Base.RefValue{<:AbstractAsset}}()
)
    if isempty(storages)
        return DataFrame()
    end
    reduce(vcat, [get_optimal_storage_level(s, scaling, storage_asset_map) for s in storages])
end

"""
    get_optimal_storage_level(
        storage::AbstractStorage, 
        scaling::Float64=1.0,
        storage_asset_map::Dict{Symbol,Base.RefValue{<:AbstractAsset}}=Dict{Symbol,Base.RefValue{<:AbstractAsset}}()
    )

Get the optimal storage level values for a single storage unit.

# Arguments
- `storage::AbstractStorage`: The storage unit to extract values from
- `scaling::Float64`: The scaling factor for the results
- `storage_asset_map::Dict{Symbol,Base.RefValue{<:AbstractAsset}}`: Mapping of storage IDs to assets

# Returns
- `DataFrame`: A dataframe containing the optimal storage level values for the storage unit
"""
function get_optimal_storage_level(
    storage::AbstractStorage, 
    scaling::Float64=1.0,
    storage_asset_map::Dict{Symbol,Base.RefValue{<:AbstractAsset}}=Dict{Symbol,Base.RefValue{<:AbstractAsset}}()
)
    time_axis = time_interval(storage)
    total_rows = length(time_axis)
    
    if isempty(storage_asset_map)
        return DataFrame(
            case_name = fill(missing, total_rows),
            commodity = fill(get_commodity_name(storage), total_rows),
            zone = fill(get_zone_name(storage), total_rows),
            resource_id = fill(id(storage), total_rows),
            component_id = fill(id(storage), total_rows),
            component_type = fill(get_type(storage), total_rows),
            variable = fill(:storage_level, total_rows),
            year = fill(missing, total_rows),
            time = Int[t for t in time_axis],
            value = Float64[value(storage_level(storage, t)) * scaling for t in time_axis]
        )
    else
        return DataFrame(
            case_name = fill(missing, total_rows),
            commodity = fill(get_commodity_name(storage), total_rows),
            zone = fill(get_zone_name(storage), total_rows),
            resource_id = fill(get_resource_id(storage, storage_asset_map), total_rows),
            component_id = fill(id(storage), total_rows),
            resource_type = fill(get_type(storage_asset_map[id(storage)]), total_rows),
            component_type = fill(get_type(storage), total_rows),
            variable = fill(:storage_level, total_rows),
            year = fill(missing, total_rows),
            time = Int[t for t in time_axis],
            value = Float64[value(storage_level(storage, t)) * scaling for t in time_axis]
        )
    end
end
