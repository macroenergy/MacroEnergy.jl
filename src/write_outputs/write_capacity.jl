"""
Capacity outputs - everything related to capacity data extraction and output.
"""

## Write capacity outputs ##
# This is the main function to write the capacity outputs to a file.
"""
    write_capacity(
        file_path::AbstractString, 
        system::System,
        scaling::Float64; 
        drop_cols::Vector{AbstractString}=String[], 
        commodity::Union{AbstractString,Vector{AbstractString},Nothing}=nothing, 
        asset_type::Union{AbstractString,Vector{AbstractString},Nothing}=nothing
    )

Write the optimal capacity results for all assets/edges in a system to a file. 
The extension of the file determines the format of the file.
`Capacity`, `NewCapacity`, and `RetiredCapacity` are first concatenated and then written to the file.

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
- `system::System`: The system containing the assets/edges to analyze as well as the settings for the output
- `scaling::Float64`: The scaling factor for the results
- `drop_cols::Vector{AbstractString}`: Columns to drop from the DataFrame
- `commodity::Union{AbstractString,Vector{AbstractString},Nothing}`: The commodity to filter by
- `asset_type::Union{AbstractString,Vector{AbstractString},Nothing}`: The asset type to filter by

# Returns
- `DataFrame`: the full, unfiltered, long-format capacity results that were computed for this
  system (capacity, new/retired/retrofitted capacity, existing capacity), regardless of the
  `drop_cols`/`commodity`/`asset_type`/layout options applied to what was actually written to
  `file_path`. Callers that need the same data again (e.g. the cross-period capacity summary,
  see [`write_capacity_summary`](@ref)) should reuse this return value instead of recomputing it.

# Example
```julia
write_capacity("capacity.csv", system, 1.0)
# Filter by commodity
write_capacity("capacity.csv", system, 1.0, commodity="Electricity")
# Filter by commodity and asset type using parameter-free matching
write_capacity("capacity.csv", system, 1.0, asset_type="ThermalPower")
# Filter by asset type using wildcard matching
write_capacity("capacity.csv", system, 1.0, asset_type="ThermalPower*")
# Filter by commodity and asset type
write_capacity("capacity.csv", system, 1.0, commodity="Electricity", asset_type=["ThermalPower", "Battery"])
```
"""
function write_capacity(
    file_path::AbstractString,
    system::System,
    scaling::Float64;
    drop_cols::Vector{<:AbstractString}=String[],
    commodity::Union{AbstractString,Vector{<:AbstractString},Nothing}=nothing,
    asset_type::Union{AbstractString,Vector{<:AbstractString},Nothing}=nothing
)
    @info "Writing capacity results to $file_path"
    capacity_results = get_optimal_capacity(system, scaling)
    new_capacity_results = get_optimal_new_capacity(system, scaling)
    retired_capacity_results = get_optimal_retired_capacity(system, scaling)
    existing_capacity_results = get_existing_capacity(system, scaling)
    if system.settings.Retrofitting
        retrofitted_capacity_results = get_optimal_retrofitted_capacity(system, scaling)
        all_capacity_results = vcat(capacity_results, new_capacity_results, retired_capacity_results, retrofitted_capacity_results, existing_capacity_results)
    else
        all_capacity_results = vcat(capacity_results, new_capacity_results, retired_capacity_results, existing_capacity_results)
    end

    # Reshape a copy for the file being written; `all_capacity_results` itself stays pristine
    # (full detail, long format) so it can be returned and reused as-is by callers.
    layout = get_output_layout(system, :Capacity)
    results_to_write = layout == "wide" ? reshape_wide(all_capacity_results) : copy(all_capacity_results)

    commodities_in_df = string.(collect(Set(results_to_write.commodity)))
    asset_types_in_df = string.(collect(Set(results_to_write.resource_type)))
    ## filter the dataframe based on the requested commodity and asset type
    # filter by commodity if specified
    if !isnothing(commodity)
        @debug "Filtering by commodity $commodity"
        (matched_commodity, missed_commodites) = search_commodities(commodity, commodities_in_df)

        # Report any commodities that were not found
        if !isempty(missed_commodites)
            @warn("The following commodities were not found in your results: $missed_commodites\nThe missed outputs will omitted from the output file\nYour results include the following commodities $commodities_in_df.")
        end
        filter!(:commodity => in(matched_commodity), results_to_write)
        if isempty(results_to_write)
            @warn "No results found after filtering by commodity $commodity"
            write_dataframe(file_path, results_to_write, drop_cols)
            return all_capacity_results
        end
    end

    # filter by asset type if specified
    if !isnothing(asset_type)
        @debug "Filtering by asset type $asset_type"
        # Get the asset types after filtering by commodity
        all_assets = string.(collect(Set(results_to_write.resource_type)))
        (matched_asset_type, missed_asset_types) = search_assets(asset_type, all_assets)

        # Report any asset types that were not found
        # If no assets were found, the output will be empty,
        # but it shouldn't crash
        if !isempty(missed_asset_types)
            s = "The following assets were not found in your results: $missed_asset_types.\n" *
                "The missed outputs will omitted from the output file.\n" *
                "Your results include the following assets $asset_types_in_df."
            @warn(s)
            # Warn the user that the specified asset type may be absent after filtering by commodity
            if !isnothing(commodity)
                s = "Please check also your commodity filter ($commodity) to ensure that it is correct."
                @warn(s)
            end
        end
        @debug "Writing capacity results for asset type $asset_type"
        filter!(:resource_type => in(matched_asset_type), results_to_write)
        if isempty(results_to_write)
            @warn "No results found after filtering by asset type $asset_type"
        end
    end

    write_dataframe(file_path, results_to_write, drop_cols)
    return all_capacity_results
end

## Capacity extraction functions ##
"""
    get_optimal_capacity(system::System, scaling::Float64)

Get the optimal capacity values for all assets/edges in a system.

# Arguments
- `system::System`: The system containing the assets/edges to analyze
- `scaling::Float64`: The scaling factor for the results.

# Returns
- `DataFrame`: A dataframe containing the optimal capacity values for all assets/edges, with missing columns removed

# Example
```julia
get_optimal_capacity(system, 1.0)
153×8 DataFrame
 Row │ commodity    zone     resource_id        component_id            resource_type  component_type      variable   value    
     │ Symbol       Symbol   Symbol             Symbol                  String         String              Symbol     Float64 
─────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │ Electricity  elec_SE  existing_solar_SE  existing_solar_SE_edge  VRE            Edge{Electricity}   capacity   8.5022
   2 │ Electricity  elec_NE  existing_solar_NE  existing_solar_NE_edge  VRE            Edge{Electricity}   capacity   0.0   
   3 │ Electricity  elec_NE  existing_wind_NE   existing_wind_NE_edge   VRE            Edge{Electricity}   capacity   3.6545
```
"""
get_optimal_capacity(system::System, scaling::Float64) = get_optimal_capacity_by_field(system, capacity, scaling)
get_optimal_capacity(asset::AbstractAsset, scaling::Float64) = get_optimal_capacity_by_field(asset, capacity, scaling)

"""
    get_optimal_new_capacity(system::System, scaling::Float64)

Get the optimal new capacity values for all assets/edges in a system.

# Arguments
- `system::System`: The system containing the assets/edges to analyze
- `scaling::Float64`: The scaling factor for the results.
# Returns
- `DataFrame`: A dataframe containing the optimal new capacity values for all assets/edges, with missing columns removed

# Example
```julia
get_optimal_new_capacity(system, 1.0)
153×7 DataFrame
 Row │ commodity  zone           resource_id                   component_id                       resource_type     component_type     variable       value  
     │ Symbol     Symbol         Symbol                        Symbol                             String            String             Symbol         Float64
─────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │ Biomass    bioherb_SE     SE_BECCS_Electricity_Herb     SE_BECCS_Electricity_Herb_biomas…  BECCSElectricity  Edge{Electricity}  new_capacity   0.0
   2 │ Biomass    bioherb_MIDAT  MIDAT_BECCS_Electricity_Herb  MIDAT_BECCS_Electricity_Herb_bio…  BECCSElectricity  Edge{Electricity}  new_capacity   0.0
   3 │ Biomass    bioherb_NE     NE_BECCS_Electricity_Herb     NE_BECCS_Electricity_Herb_biomas…  BECCSElectricity  Edge{Electricity}  new_capacity   0.0
```
"""
get_optimal_new_capacity(system::System, scaling::Float64) = get_optimal_capacity_by_field(system, new_capacity, scaling)
get_optimal_new_capacity(asset::AbstractAsset, scaling::Float64) = get_optimal_capacity_by_field(asset, new_capacity, scaling)

"""
    get_optimal_retired_capacity(system::System, scaling::Float64)

Get the optimal retired capacity values for all assets/edges in a system.

# Arguments
- `system::System`: The system containing the assets/edges to analyze
- `scaling::Float64`: The scaling factor for the results.
# Returns
- `DataFrame`: A dataframe containing the optimal retired capacity values for all assets/edges, with missing columns removed

# Example
```julia
get_optimal_retired_capacity(system, 1.0)
153×7 DataFrame
 Row │ commodity  zone           resource_id                   component_id                       resource_type     component_type     variable          value    
     │ Symbol     Symbol         Symbol                        Symbol                             String            String             Symbol            Float64  
─────┼──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │ Biomass    bioherb_SE     SE_BECCS_Electricity_Herb     SE_BECCS_Electricity_Herb_biomas…  BECCSElectricity  Edge{Electricity}  retired_capacity  0.0
   2 │ Biomass    bioherb_MIDAT  MIDAT_BECCS_Electricity_Herb  MIDAT_BECCS_Electricity_Herb_bio…  BECCSElectricity  Edge{Electricity}  retired_capacity  0.0
   3 │ Biomass    bioherb_NE     NE_BECCS_Electricity_Herb     NE_BECCS_Electricity_Herb_biomas…  BECCSElectricity  Edge{Electricity}  retired_capacity  0.0
```
"""
get_optimal_retired_capacity(system::System, scaling::Float64) = get_optimal_capacity_by_field(system, retired_capacity, scaling)
get_optimal_retired_capacity(asset::AbstractAsset, scaling::Float64) = get_optimal_capacity_by_field(asset, retired_capacity, scaling)

get_optimal_retrofitted_capacity(system::System, scaling::Float64) = get_optimal_capacity_by_field(system, retrofitted_capacity, scaling)
get_optimal_retrofitted_capacity(asset::AbstractAsset, scaling::Float64) = get_optimal_capacity_by_field(asset, retrofitted_capacity, scaling)

get_existing_capacity(system::System, scaling::Float64) = get_optimal_capacity_by_field(system, existing_capacity, scaling)
get_existing_capacity(asset::AbstractAsset, scaling::Float64) = get_optimal_capacity_by_field(asset, existing_capacity, scaling)

# Learning
get_endog_costs(system::System; scaling::Float64=1.0) = get_optimal_capacity_by_field(system, endog_annualized_cost, scaling)

# Utility function to get the optimal capacity by macro object field
function get_optimal_capacity_by_field(system::System, capacity_func::Function, scaling::Float64)
    @debug " -- Getting optimal values for $(Symbol(capacity_func)) for the system."
    edges, edge_asset_idmap = edges_with_capacity_variables(system, return_ids_map=true)
    storages, storage_asset_idmap = storages_with_capacity_variables(system, return_ids_map=true)
    edges_capacity = get_optimal_capacity_by_field(edges, capacity_func, scaling; obj_asset_map=edge_asset_idmap, year=year(system))
    storages_capacity = get_optimal_capacity_by_field(storages, capacity_func, scaling; obj_asset_map=storage_asset_idmap, year=year(system))
    asset_capacity = vcat(edges_capacity, storages_capacity)
    asset_capacity[!, (!isa).(eachcol(asset_capacity), Vector{Missing})] # remove missing columns
end

function get_optimal_capacity_by_field(asset::AbstractAsset, capacity_func::Function, scaling::Float64)
    @debug " -- Getting optimal values for $(Symbol(capacity_func)) for the asset $(id(asset))."
    edges, edge_asset_idmap = edges_with_capacity_variables(asset, return_ids_map=true)
    storages, storage_asset_idmap = storages_with_capacity_variables(asset, return_ids_map=true)
    asset_capacity = vcat(get_optimal_capacity_by_field(edges, capacity_func, scaling; obj_asset_map=edge_asset_idmap), get_optimal_capacity_by_field(storages, capacity_func, scaling; obj_asset_map=storage_asset_idmap))
    asset_capacity[!, (!isa).(eachcol(asset_capacity), Vector{Missing})] # remove missing columns
end

## Cross-period capacity summary ##

# Canonical variable order for the wide-format summary
const CAPACITY_SUMMARY_VARIABLE_ORDER = [:existing_capacity, :new_capacity, :retired_capacity, :capacity, :retrofitted_capacity]

capacity_summary_column_name(variable::Symbol, label::Int) = "$(variable)_$(label)"

"""
    write_capacity_summary(path::AbstractString, period_results::Vector{DataFrame}, layout::String)

Write a cross-period capacity summary (`capacity_summary.csv`) to `path`, combining the
per-period `DataFrame`s returned by [`write_capacity`](@ref) (Note for developers: `period_results` must be in
chronological order, earliest period first).

When the case has a `StartYear` configured, each period's `DataFrame` carries a real `year`
column (from the system's `TimeData`), and the summary is labeled by calendar year. Otherwise
`write_capacity`'s `year` column is entirely absent, and the summary
falls back to a `period` column — each period's 1-based position in `period_results`.

`:existing_capacity` is dropped from every period except the first (earliest) one, since for
later periods it is always equal to the previous period's final `:capacity` and so is redundant.

- `layout == "long"`: the per-period `capacity.csv` schema stacked across periods with a `year`
  or `period` column (see above).
- `layout == "wide"`: each period is reshaped with [`reshape_wide`](@ref) exactly like the
  per-period `capacity.csv` (one row per component, one column per variable), the variable
  columns are renamed with a `_<year>` or `_<period>` suffix, and periods are then outer-joined
  together on the shared identifying columns (commodity, zone, resource_id, component_id,
  resource_type, component_type).
"""
function write_capacity_summary(path::AbstractString, period_results::Vector{DataFrame}, layout::String)
    all(isempty, period_results) && return nothing

    file_path = joinpath(path, "capacity_summary.csv")
    @info "Writing cross-period capacity summary to $file_path"

    # No StartYear configured: `year` column was dropped. Fall back to a `period` column instead.
    has_year = hasproperty(period_results[1], :year)
    label_col = has_year ? :year : :period
    if !has_year
        period_results = [insertcols(df, :value, :period => period_idx) for (period_idx, df) in enumerate(period_results)]
    end

    # Only the first (earliest) period's existing_capacity is informative; later periods'
    # existing_capacity always equals the previous period's final capacity.
    first_label = only(unique(period_results[1][!, label_col]))
    period_results = map(period_results) do df
        only(unique(df[!, label_col])) == first_label ? df : filter(:variable => !=(:existing_capacity), df)
    end

    if layout == "wide"
        id_cols = names(select(first(period_results), Not([:variable, :value, label_col])))

        period_wide_dfs = map(period_results) do df
            label = only(unique(df[!, label_col]))
            wide = reshape_wide(select(df, Not(label_col)))
            present_vars = [v for v in CAPACITY_SUMMARY_VARIABLE_ORDER if string(v) in names(wide)]
            select!(wide, [id_cols; string.(present_vars)])
            rename!(wide, [string(v) => capacity_summary_column_name(v, label) for v in present_vars]...)
            return wide
        end

        wide = reduce((a, b) -> outerjoin(a, b, on=id_cols), period_wide_dfs)
        for col in setdiff(names(wide), id_cols)
            wide[!, col] = coalesce.(wide[!, col], 0.0)
        end
        write_dataframe(file_path, wide)
    else
        write_dataframe(file_path, reduce(vcat, period_results))
    end
    return nothing
end

# The following functions are used to extract capacity values after the model has been solved
# from a list of MacroObjects (e.g., edges, and storage) and a list of fields (e.g., capacity, new_capacity, retired_capacity)

get_optimal_capacity_by_field(objs::Vector{T}, field::Function, scaling::Float64; obj_asset_map::Dict{Symbol,Base.RefValue{<:AbstractAsset}}=Dict{Symbol,Base.RefValue{<:AbstractAsset}}(), year::Union{Int,Missing}=missing) where {T<:MacroObject} =
    get_optimal_capacity_by_field(objs, (field,), scaling; obj_asset_map, year)

function get_optimal_capacity_by_field(
    objs::Vector{T},
    field_list::Tuple,
    scaling::Float64;
    obj_asset_map::Dict{Symbol,Base.RefValue{<:AbstractAsset}}=Dict{Symbol,Base.RefValue{<:AbstractAsset}}(),
    year::Union{Int,Missing}=missing
) where {T<:MacroObject}
    # Check if the objects is empty
    isempty(objs) && return DataFrame()

    # Calculate total number of rows needed
    total_rows = length(objs) * length(field_list)

    if isempty(obj_asset_map)
        return DataFrame(
            case_name = fill(missing, total_rows),
            commodity = [get_commodity_name(obj) for obj in objs for f in field_list],
            zone = [get_zone_name(obj) for obj in objs for f in field_list],
            resource_id = [get_component_id(obj) for obj in objs for f in field_list],  # component id is same as resource id
            component_id = [get_component_id(obj) for obj in objs for f in field_list],
            component_type = [get_type(obj) for obj in objs for f in field_list],
            variable = [Symbol(f) for obj in objs for f in field_list],
            year = fill(year, total_rows),
            value = [Float64(value(f(obj))) * scaling for obj in objs for f in field_list]
        )
    else
        return DataFrame(
            case_name = fill(missing, total_rows),
            commodity = [get_commodity_name(obj) for obj in objs for f in field_list],
            zone = [get_zone_name(obj) for obj in objs for f in field_list],
            resource_id = [get_resource_id(obj, obj_asset_map) for obj in objs for f in field_list],
            component_id = [get_component_id(obj) for obj in objs for f in field_list],
            resource_type = [get_type(obj_asset_map[id(obj)]) for obj in objs for f in field_list],
            component_type = [get_type(obj) for obj in objs for f in field_list],
            variable = [Symbol(f) for obj in objs for f in field_list],
            year = fill(year, total_rows),
            value = [Float64(value(f(obj))) * scaling for obj in objs for f in field_list]
        )
    end
end

function write_capacity_all_periods(
    file_path::AbstractString, 
    case::Case; 
    scaling::Float64=1.0, 
    drop_cols::Vector{<:AbstractString}=String[],
    commodity::Union{AbstractString,Vector{<:AbstractString},Nothing}=nothing,
    asset_type::Union{AbstractString,Vector{<:AbstractString},Nothing}=nothing
)

    if get_output_layout(case.systems[1], :Capacity) == "long"

        @info "Writing all capacity results to $file_path"
        results_all_periods = DataFrame[]

        for system in case.systems
            capacity_results = get_optimal_capacity(system; scaling)
            new_capacity_results = get_optimal_new_capacity(system; scaling)
            retired_capacity_results = get_optimal_retired_capacity(system; scaling)
            # Learning
            endog_costs = get_endog_costs(system; scaling)
            # Shadow
            new_de_capacity_results = get_new_de_capacity(system; scaling)
            new_af_capacity_results = get_new_af_capacity(system; scaling)
            new_cc_capacity_results = get_new_cc_capacity(system; scaling)
            de_capacity_results = get_de_capacity(system; scaling)
            af_capacity_results = get_af_capacity(system; scaling)
            cc_capacity_results = get_cc_capacity(system; scaling)
            # Capital spend
            new_capital_results = get_optimal_new_capital(system; scaling)
            new_de_capital_results = get_optimal_new_capital_de(system; scaling)
            new_af_capital_results = get_optimal_new_capital_af(system; scaling)
            new_cc_capital_results = get_optimal_new_capital_cc(system; scaling)


            all_capacity_results = vcat(capacity_results, new_capacity_results, retired_capacity_results, endog_costs, new_de_capacity_results, new_af_capacity_results, new_cc_capacity_results, de_capacity_results, af_capacity_results, cc_capacity_results, new_capital_results, new_de_capital_results, new_af_capital_results, new_cc_capital_results)

            system_number = findfirst(==(system), case.systems)
            period_number_vector = fill(system_number, nrow(all_capacity_results))
            insertcols!(all_capacity_results, ncol(all_capacity_results), :period => period_number_vector)

            push!(results_all_periods, all_capacity_results)
            global capacity_results_all_periods = vcat(results_all_periods...)

        end
    
        write_dataframe(string(file_path,"capacity_all_periods.csv"), capacity_results_all_periods, drop_cols)
    end
    
    return nothing
end