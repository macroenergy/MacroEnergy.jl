"""
    mkpath_for_period(case_path::AbstractString, num_periods::Int, period_idx::Int)

Return the results directory path for the given period and create it (mkpath).
Single-period cases use `results`, multi-period use `results_period_(period_idx)`.
"""
function mkpath_for_period(case_path::AbstractString, num_periods::Int, period_idx::Int)
    results_dir = num_periods > 1 ? joinpath(case_path, "results_period_$period_idx") : joinpath(case_path, "results")
    mkpath(results_dir)
    return results_dir
end

"""
    create_output_path(system::System, path::String=system.data_dirpath)

Create and return the path to the output directory for storing results based on system settings.

# Arguments
- `system::System`: The system object containing settings and configuration
- `path::String`: Base path for the output directory (defaults to system.data_dirpath)

# Returns
- `String`: Path to the created output directory

The function creates an output directory based on system settings. If `OverwriteResults` 
is false, it will avoid overwriting existing directories by appending incremental numbers 
(e.g., "_001", "_002") to the directory name. The directory is created if it doesn't exist.

# Example
```julia
julia> system.settings
(..., OverwriteResults = true, OutputDir = "result_dir")
julia> output_path = create_output_path(system)
# Returns "path/to/system.data_dirpath/result_dir" or "path/to/system.data_dirpath/result_dir_001" if original exists
julia> output_path = create_output_path(system, "path/to/output")
# Returns "path/to/output/result_dir" or "path/to/output/result_dir_001" if original exists
```
"""
function create_output_path(system::System, path::String=system.data_dirpath)
    if system.settings.OverwriteResults
        path = joinpath(path, system.settings.OutputDir)
    else
        # Find closest unused ouput directory name and create it
        path = find_available_path(path, system.settings.OutputDir)
    end
    @debug "Writing results to $path"
    mkpath(path)
    return path
end

"""
    find_available_path(path::String, basename::String="results"; max_attempts::Int=999)

Choose an available output directory with the name "basename_<number>" by appending incremental numbers to the base path.

# Arguments
- `path::String`: Base path for the output directory.
- `basename::String`: Base name of the output directory.
- `max_attempts::Int`: Maximum number of attempts to find an available directory (default is 999).

# Returns
- `String`: Full path to the chosen output directory.

The function first expands the given path to its full path and then attempts to find an available directory
by appending incremental numbers (e.g., "basename_001", "basename_002") up to `max_attempts` times.
If an available directory is found, it returns the full path to that directory. If no available
directory is found after `max_attempts` attempts, it raises an error.

# Example
```julia
julia> path = "path/to/output"
julia> output_path = find_available_path(path)
# Returns "path/to/output/results_001" or "path/to/output/results_002" etc.
```
"""
function find_available_path(path::String, basename::String="results"; max_attempts::Int=999)
    path = abspath(path) # expand path to the full path

    for i in 1:max_attempts
        dir_name = "$(basename)_$(lpad(i, 3, '0'))"
        full_path = joinpath(path, dir_name)

        if !isdir(full_path)
            return full_path
        end
    end

    error("Could not find available directory after $max_attempts attempts")
end

"""
    get_output_layout(system::System, variable::Union{Nothing,Symbol}=nothing)::String

Get the output layout ("wide" or "long") for a specific variable from system settings.

# Arguments
- `system::System`: System containing output layout settings
- `variable::Union{Nothing,Symbol}=nothing`: Variable to get layout for (e.g., :Cost, :Flow)

# Returns
String indicating layout format: "wide" or "long"

# Settings Format
The `OutputLayout` setting can be specified in three ways:

1. Global string setting:
   ```julia
   settings = (OutputLayout="wide",)  # Same layout for all variables
   ```

2. Per-variable settings using NamedTuple:
   ```julia
   settings = (OutputLayout=(Cost="wide", Flow="long"),)
   ```

3. Default behavior:
   - Returns "long" if setting is missing or invalid
   - Logs warning for unsupported types or missing variables

# Examples
```julia
# Global layout
system = System(settings=(OutputLayout="wide",))
get_output_layout(system, :Cost)  # Returns "wide"

# Per-variable layout
system = System(settings=(OutputLayout=(Cost="wide", Flow="long"),))
get_output_layout(system, :Cost)  # Returns "wide"
get_output_layout(system, :Flow)  # Returns "long"
get_output_layout(system, :Other) # Returns "long" with warning
```
"""
function get_output_layout(system::System, variable::Union{Nothing,Symbol}=nothing)::String
    output_layout = system.settings.OutputLayout

    # String layouts supported are "wide" and "long"
    if isa(output_layout, String)
        @debug "Using output layout $output_layout"
        return output_layout
    end

    if isnothing(variable)
        @warn "OutputLayout in settings does not have a variable key. Using 'long' as default."
        return "long"
    end

    # Handle NamedTuple case (per-file settings)
    if isa(output_layout, NamedTuple)
        if !haskey(output_layout, variable)
            @warn "OutputLayout in settings does not have a $variable key. Using 'long' as default."
        end
        layout = get(output_layout, variable, "long")
        @debug "Using output layout $layout for variable $variable"
        return layout
    end

    # Handle unknown types
    @warn "OutputLayout type $(typeof(output_layout)) not supported. Using 'long' as default."
    return "long"
end

"""
    filter_edges_by_commodity!(edges::Vector{AbstractEdge}, commodity::Union{Symbol,Vector{Symbol}}, edge_asset_map::Dict{Symbol,Base.RefValue{<:AbstractAsset}}=Dict{Symbol,Base.RefValue{<:AbstractAsset}}())

Filter the edges by commodity and update the edge_asset_map to match the filtered edges (optional).

# Arguments
- `edges::Vector{AbstractEdge}`: The edges to filter
- `commodity::Union{Symbol,Vector{Symbol}}`: The commodity to filter by
- `edge_asset_map::Dict{Symbol,Base.RefValue{<:AbstractAsset}}`: The edge_asset_map to update (optional)

# Effects
- Modifies `edges` in-place to keep only edges matching the commodity type
- If `edge_asset_map` is provided, filters it to match remaining edges

# Example
```julia
filter_edges_by_commodity!(edges, :Electricity)
filter_edges_by_commodity!(edges, [:Electricity, :NaturalGas], edge_asset_map)
```

"""
function filter_edges_by_commodity!(
    edges::Vector{AbstractEdge},
    commodity::Union{Symbol,Vector{Symbol}},
    edge_asset_map::Dict{Symbol,Base.RefValue{<:AbstractAsset}}=Dict{Symbol,Base.RefValue{<:AbstractAsset}}()
)
    @debug "Filtering edges by commodity $commodity"

    # convert commodity to vector if it is a symbol
    commodity = isa(commodity, Symbol) ? [commodity] : commodity

    # convert commodity from a Vector{Symbol} to a Vector{DataType}
    macro_commodities = commodity_types()
    if !all(c -> c ∈ keys(macro_commodities), commodity)
        throw(ArgumentError("Commodity $commodity not found in the system.\n" *
                            "Available commodities are $macro_commodities"))
    end
    commodities = Set(macro_commodities[c] for c in commodity)

    # filter edges by commodity
    filter!(e -> commodity_type(e) in commodities, edges)

    # filter edge_asset_map to match the filtered edges
    if !isempty(edge_asset_map)
        edge_ids = Set(id.(edges)) # caching for performance
        filter!(pair -> pair[1] in edge_ids, edge_asset_map)
    end

    return nothing
end

"""
    filter_edges_by_asset_type!(edges::Vector{AbstractEdge}, asset_type::Union{Symbol,String,Vector{Symbol},Vector{String}}, edge_asset_map::Dict{Symbol,Base.RefValue{<:AbstractAsset}})

Filter edges and their associated assets by asset type.

# Arguments
- `edges::Vector{AbstractEdge}`: Edges to filter
- `asset_type::Union{Symbol,String,Vector{Symbol},Vector{String}}`: Target asset type(s)
- `edge_asset_map::Dict{Symbol,Base.RefValue{<:AbstractAsset}}`: Mapping of edges to assets

# Effects
- Modifies `edges` in-place to keep only edges matching the asset type
- Modifies `edge_asset_map` to keep only matching assets

# Throws
- `ArgumentError`: If none of the requested asset types are found in the system

# Example
```julia
filter_edges_by_asset_type!(edges, :Battery, edge_asset_map)
filter_edges_by_asset_type!(edges, "Battery", edge_asset_map)
```
"""
function filter_edges_by_asset_type!(
    edges::Vector{AbstractEdge},
    asset_type::Union{Symbol,String,Vector{Symbol},Vector{String}},
    edge_asset_map::Dict{Symbol,Base.RefValue{<:AbstractAsset}}
)
    @debug "Filtering edges by asset type $asset_type"

    # convert asset_type to vector of strings for comparison with get_type (which returns String)
    asset_type_strings = isa(asset_type, Union{Symbol,String}) ? [string(asset_type)] : string.(asset_type)

    # check if the asset_type is available in the system
    available_types = unique(get_type(asset) for asset in values(edge_asset_map))
    if !any(t -> t ∈ available_types, asset_type_strings)
        throw(ArgumentError(
            "Asset type(s) $asset_type_strings not found in the system.\n" *
            "Available types are $available_types"
        ))
    end

    # filter asset map by type (done first as it's used for edge filtering)
    filter!(pair -> get_type(pair[2]) in asset_type_strings, edge_asset_map)

    # filter edges according to new edge_asset_map
    filter!(e -> id(e) in keys(edge_asset_map), edges)

    return nothing
end

function has_wildcard(s::AbstractString)
    return endswith(s, "*")
end

function has_wildcard(s::Symbol)
    return endswith(string(s), "*")
end

"""
    search_commodities(commodities, available_commodities)

Search for commodity types in a list of available commodities, supporting wildcards and subtypes.

# Arguments
- `commodities::Union{AbstractString,Vector{<:AbstractString}}`: Commodity type(s) to search for
- `available_commodities::Vector{<:AbstractString}`: Available commodity types to search from

# Returns
Tuple of two vectors:
1. `Vector{Symbol}`: Found commodity types
2. `Vector{Symbol}`: Missing commodity types (only if no matches found)

# Pattern Matching
Supports two types of matches:
1. Exact match: `"Electricity"` matches only `"Electricity"`
2. Wildcard match: `"CO2*"` matches both `CO2` and its subtypes (e.g., `CO2Captured`)

# Examples
```julia
# Available commodities
commodities = ["Electricity", "CO2", "CO2Captured"]

# Exact match
found, missing = search_commodities("Electricity", commodities)
# found = [:Electricity], missing = []

# Wildcard match
found, missing = search_commodities("CO2*", commodities)
# found = [:CO2, :CO2Captured], missing = []

# Multiple types
found, missing = search_commodities(["Electricity", "Heat"], commodities)
# found = [:Electricity], missing = [:Heat]
```

!!! note 
    Wildcard searches check against registered commodity types in MacroEnergy.jl.
"""
function search_commodities(
    commodities::Union{AbstractString,Vector{<:AbstractString}},
    available_commodities::Vector{<:AbstractString}
)
    commodities = isa(commodities, AbstractString) ? [commodities] : commodities
    macro_commodity_types = commodity_types()
    final_commodities = Set{Symbol}()
    missed_commodites = Set{Symbol}()
    for c in commodities
        wildcard_search = has_wildcard(c)
        if wildcard_search
            c = c[1:end-1]
            c_sym = Symbol(c)
            if !haskey(macro_commodity_types, c_sym)
                continue
            end
            c_datatype = macro_commodity_types[c_sym]
            # Find all commodities which start with the part before the wildcard
            union!(final_commodities, typesymbol.(Set{DataType}([c_datatype, subtypes(c_datatype)...])))
        end
        # Add the commodity itself, if it's in the dataframe
        if c in available_commodities
            push!(final_commodities, Symbol(c))
        elseif !wildcard_search
            push!(missed_commodites, Symbol(c))
        end
    end
    # Final check to make sure the commodities are in the system
    final_commodities = intersect(final_commodities, Set(Symbol.(available_commodities)))
    return collect(final_commodities), collect(missed_commodites)
end

"""
    search_assets(asset_type, available_types)

Search for asset types in a list of available assets, supporting wildcards and parametric types.

# Arguments
- `asset_type::Union{AbstractString,Vector{<:AbstractString}}`: Type(s) to search for
- `available_types::Vector{<:AbstractString}`: Available asset types to search from

# Returns
Tuple of two vectors:
1. `Vector{String}`: Found asset types
2. `Vector{String}`: Missing asset types (only if no matches found)

# Pattern Matching
Supports three types of matches:
1. Exact match: `"Battery"` matches `"Battery"`
2. Parametric match: `"ThermalPower"` matches `"ThermalPower{Fuel}"`
3. Wildcard match: `"ThermalPower*"` matches both `"ThermalPower{Fuel}"` and `"ThermalPowerCCS{Fuel}"`

# Examples
```julia
# Available assets
assets = ["Battery", "ThermalPower{Coal}", "ThermalPower{Gas}"]

# Exact match
found, missing = search_assets("Battery", assets)
# found = ["Battery"], missing = []

# Parametric match
found, missing = search_assets("ThermalPower", assets)
# found = ["ThermalPower{Coal}", "ThermalPower{Gas}"], missing = []

# Wildcard match
found, missing = search_assets("ThermalPower*", assets)
# found = ["ThermalPower{Coal}", "ThermalPower{Gas}"], missing = []

# Multiple types
found, missing = search_assets(["Battery", "Solar"], assets)
# found = ["Battery"], missing = ["Solar"]
```
"""
function search_assets(
    asset_type::Union{AbstractString,Vector{<:AbstractString}},
    available_types::Vector{<:AbstractString}
)
    asset_type = isa(asset_type, AbstractString) ? [asset_type] : asset_type
    final_asset_types = Set{String}()
    missed_asset_types = Set{String}()
    
    for a in asset_type
        found_any = false
        wildcard_search = has_wildcard(a)
        
        if wildcard_search
            a = a[1:end-1]
            # Find all asset types which start with the part before the wildcard
            matches = available_types[startswith.(available_types, Ref(a))]
            # Add the asset types, accounting for parametric commodities
            union!(final_asset_types, matches)
            found_any = !isempty(matches)
        end
        
        # Add the parametric types
        parametric_matches = available_types[startswith.(available_types, Ref(a * "{"))]
        union!(final_asset_types, parametric_matches)
        found_any = found_any || !isempty(parametric_matches)
        
        # Add the asset types itself, if they're in the dataframe
        if a in available_types
            push!(final_asset_types, a)
            found_any = true
        end
        
        # Only add to missed if we found no matches at all
        if !found_any && !wildcard_search
            push!(missed_asset_types, a)
        end
    end
    
    return collect(final_asset_types), collect(missed_asset_types)
end

function find_available_filepath(path::AbstractString, filename::AbstractString; max_attempts::Int=999)
    path = abspath(path) # expand path to the full path

    # Split filename on the last "."
    basename, ext = splitext(filename) 
    
    for i in 1:max_attempts
        full_path = joinpath(path, filename)
        if !isfile(full_path)
            return full_path
        end
        filename = "$(basename)_$(lpad(i, 3, '0'))$(ext)"
    end
    return filename
    error("Could not find available file after $max_attempts attempts")
end

function find_available_filepath(filepath::AbstractString; max_attempts::Int=999)
    path = dirname(filepath)
    filename = basename(filepath)
    return find_available_filepath(path, filename; max_attempts=max_attempts)
end

function get_local_expressions(optimal_getter::Function, subproblems_local::Vector{Dict{Any,Any}})
    @assert isdefined(MacroEnergy, Symbol(optimal_getter))
    n_local_subprob = length(subproblems_local)
    expr_df = Vector{DataFrame}(undef, n_local_subprob)
    for s in eachindex(subproblems_local)
        expr_df[s] = optimal_getter(subproblems_local[s][:system_local])
    end
    return expr_df
end