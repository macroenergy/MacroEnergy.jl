"""
Capacity outputs - everything related to capacity data extraction and output.
"""

## Write capacity outputs ##
# This is the main function to write the capacity outputs to a file.
"""
    write_capacity(
        file_path::AbstractString, 
        system::System; 
        scaling::Float64=1.0, 
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
- `nothing`: The function returns nothing, but writes the results to the file

# Example
```julia
write_capacity("capacity.csv", system)
# Filter by commodity
write_capacity("capacity.csv", system, commodity="Electricity")
# Filter by commodity and asset type using parameter-free matching
write_capacity("capacity.csv", system, asset_type="ThermalPower")
# Filter by asset type using wildcard matching
write_capacity("capacity.csv", system, asset_type="ThermalPower*")
# Filter by commodity and asset type
write_capacity("capacity.csv", system, commodity="Electricity", asset_type=["ThermalPower", "Battery"])
```
"""
function write_capacity(
    file_path::AbstractString,
    system::System;
    scaling::Float64=1.0,
    drop_cols::Vector{<:AbstractString}=String[],
    commodity::Union{AbstractString,Vector{<:AbstractString},Nothing}=nothing,
    asset_type::Union{AbstractString,Vector{<:AbstractString},Nothing}=nothing
)
    @info "Writing capacity results to $file_path"
    capacity_results = get_optimal_capacity(system; scaling)
    new_capacity_results = get_optimal_new_capacity(system; scaling)
    retired_capacity_results = get_optimal_retired_capacity(system; scaling)
    if system.settings.Retrofitting
        retrofitted_capacity_results = get_optimal_retrofitted_capacity(system; scaling)
        all_capacity_results = vcat(capacity_results, new_capacity_results, retired_capacity_results, retrofitted_capacity_results)
    else
        all_capacity_results = vcat(capacity_results, new_capacity_results, retired_capacity_results)
    end

    # Reshape the dataframe based on the requested format
    layout = get_output_layout(system, :Capacity)
    all_capacity_results = layout == "wide" ? reshape_wide(all_capacity_results) : all_capacity_results

    commodities_in_df = string.(collect(Set(all_capacity_results.commodity)))
    asset_types_in_df = string.(collect(Set(all_capacity_results.type)))
    ## filter the dataframe based on the requested commodity and asset type
    # filter by commodity if specified
    if !isnothing(commodity)
        @debug "Filtering by commodity $commodity"
        (matched_commodity, missed_commodites) = search_commodities(commodity, commodities_in_df)

        # Report any commodities that were not found
        if !isempty(missed_commodites)
            @warn("The following commodities were not found in your results: $missed_commodites\nThe missed outputs will omitted from the output file\nYour results include the following commodities $commodities_in_df.")
        end
        filter!(:commodity => in(matched_commodity), all_capacity_results)
        if isempty(all_capacity_results)
            @warn "No results found after filtering by commodity $commodity"
            return write_dataframe(file_path, all_capacity_results, drop_cols)
        end
    end

    # filter by asset type if specified
    if !isnothing(asset_type)
        @debug "Filtering by asset type $asset_type"
        # Get the asset types after filtering by commodity
        all_assets = string.(collect(Set(all_capacity_results.type)))
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
        filter!(:type => in(matched_asset_type), all_capacity_results)
        if isempty(all_capacity_results)
            @warn "No results found after filtering by asset type $asset_type"
        end
    end

    write_dataframe(file_path, all_capacity_results, drop_cols)
    return nothing
end

## Capacity extraction functions ##
"""
    get_optimal_capacity(system::System; scaling::Float64=1.0)

Get the optimal capacity values for all assets/edges in a system.

# Arguments
- `system::System`: The system containing the assets/edges to analyze
- `scaling::Float64`: The scaling factor for the results.

# Returns
- `DataFrame`: A dataframe containing the optimal capacity values for all assets/edges, with missing columns removed

# Example
```julia
get_optimal_capacity(system)
153×8 DataFrame
 Row │ commodity    commodity_subtype  zone           resource_id                        component_id                       type              variable  value    
     │ Symbol       Symbol             Symbol         Symbol                             Symbol                             Symbol            Symbol    Float64 
─────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │ Electricity  capacity           elec_SE        existing_solar_SE                  existing_solar_SE_edge             VRE               capacity   8.5022
   2 │ Electricity  capacity           elec_NE        existing_solar_NE                  existing_solar_NE_edge             VRE               capacity   0.0   
   3 │ Electricity  capacity           elec_NE        existing_wind_NE                   existing_wind_NE_edge              VRE               capacity   3.6545
```
"""
get_optimal_capacity(system::System; scaling::Float64=1.0) = get_optimal_capacity_by_field(system, capacity, scaling)
get_optimal_capacity(asset::AbstractAsset; scaling::Float64=1.0) = get_optimal_capacity_by_field(asset, capacity, scaling)

"""
    get_optimal_new_capacity(system::System; scaling::Float64=1.0)

Get the optimal new capacity values for all assets/edges in a system.

# Arguments
- `system::System`: The system containing the assets/edges to analyze
- `scaling::Float64`: The scaling factor for the results.
# Returns
- `DataFrame`: A dataframe containing the optimal new capacity values for all assets/edges, with missing columns removed

# Example
```julia
get_optimal_new_capacity(system)
153×8 DataFrame
 Row │ commodity    commodity_subtype  zone           resource_id                        component_id                       type              variable      value  
     │ Symbol       Symbol             Symbol         Symbol                             Symbol                             Symbol            Symbol        Float64
─────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │ Biomass      capacity           bioherb_SE     SE_BECCS_Electricity_Herb          SE_BECCS_Electricity_Herb_biomas…  BECCSElectricity  new_capacity      0.0
   2 │ Biomass      capacity           bioherb_MIDAT  MIDAT_BECCS_Electricity_Herb       MIDAT_BECCS_Electricity_Herb_bio…  BECCSElectricity  new_capacity      0.0
   3 │ Biomass      capacity           bioherb_NE     NE_BECCS_Electricity_Herb          NE_BECCS_Electricity_Herb_biomas…  BECCSElectricity  new_capacity      0.0
```
"""
get_optimal_new_capacity(system::System; scaling::Float64=1.0) = get_optimal_capacity_by_field(system, new_capacity, scaling)
get_optimal_new_capacity(asset::AbstractAsset; scaling::Float64=1.0) = get_optimal_capacity_by_field(asset, new_capacity, scaling)

"""
    get_optimal_retired_capacity(system::System; scaling::Float64=1.0)

Get the optimal retired capacity values for all assets/edges in a system.

# Arguments
- `system::System`: The system containing the assets/edges to analyze
- `scaling::Float64`: The scaling factor for the results.
# Returns
- `DataFrame`: A dataframe containing the optimal retired capacity values for all assets/edges, with missing columns removed

# Example
```julia
get_optimal_retired_capacity(system)
153×8 DataFrame
 Row │ commodity    commodity_subtype  zone           resource_id                        component_id                       type              variable      value    
     │ Symbol       Symbol             Symbol         Symbol                             Symbol                             Symbol            Symbol        Float64  
─────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │ Biomass      capacity           bioherb_SE     SE_BECCS_Electricity_Herb          SE_BECCS_Electricity_Herb_biomas…  BECCSElectricity  retired_capacity  0.0
   2 │ Biomass      capacity           bioherb_MIDAT  MIDAT_BECCS_Electricity_Herb       MIDAT_BECCS_Electricity_Herb_bio…  BECCSElectricity  retired_capacity  0.0
   3 │ Biomass      capacity           bioherb_NE     NE_BECCS_Electricity_Herb          NE_BECCS_Electricity_Herb_biomas…  BECCSElectricity  retired_capacity  0.0
```
"""
get_optimal_retired_capacity(system::System; scaling::Float64=1.0) = get_optimal_capacity_by_field(system, retired_capacity, scaling)
get_optimal_retired_capacity(asset::AbstractAsset; scaling::Float64=1.0) = get_optimal_capacity_by_field(asset, retired_capacity, scaling)

get_optimal_retrofitted_capacity(system::System; scaling::Float64=1.0) = get_optimal_capacity_by_field(system, retrofitted_capacity, scaling)
get_optimal_retrofitted_capacity(asset::AbstractAsset; scaling::Float64=1.0) = get_optimal_capacity_by_field(asset, retrofitted_capacity, scaling)

get_existing_capacity(system::System) = get_optimal_capacity_by_field(system, existing_capacity)
get_existing_capacity(asset::AbstractAsset; scaling::Float64=1.0) = get_optimal_capacity_by_field(asset, existing_capacity, scaling)

# Utility function to get the optimal capacity by macro object field
function get_optimal_capacity_by_field(system::System, capacity_func::Function, scaling::Float64=1.0)
    @debug " -- Getting optimal values for $(Symbol(capacity_func)) for the system."
    edges, edge_asset_idmap = edges_with_capacity_variables(system, return_ids_map=true)
    asset_capacity = get_optimal_capacity_by_field(edges, capacity_func, scaling, edge_asset_idmap)
    asset_capacity[!, (!isa).(eachcol(asset_capacity), Vector{Missing})] # remove missing columns
end

function get_optimal_capacity_by_field(asset::AbstractAsset, capacity_func::Function, scaling::Float64=1.0)
    @debug " -- Getting optimal values for $(Symbol(capacity_func)) for the asset $(id(asset))."
    edges, edge_asset_idmap = edges_with_capacity_variables(asset, return_ids_map=true)
    asset_capacity = get_optimal_capacity_by_field(edges, capacity_func, scaling, edge_asset_idmap)
    asset_capacity[!, (!isa).(eachcol(asset_capacity), Vector{Missing})] # remove missing columns
end

# The following functions are used to extract capacity values after the model has been solved
# from a list of MacroObjects (e.g., edges, and storage) and a list of fields (e.g., capacity, new_capacity, retired_capacity)

get_optimal_capacity_by_field(objs::Vector{T}, field::Function, scaling::Float64=1.0, obj_asset_map::Dict{Symbol,Base.RefValue{<:AbstractAsset}}=Dict{Symbol,Base.RefValue{<:AbstractAsset}}()) where {T<:Union{AbstractEdge,Storage}} =
    get_optimal_capacity_by_field(objs, (field,), scaling, obj_asset_map)

function get_optimal_capacity_by_field(
    objs::Vector{T},
    field_list::Tuple,
    scaling::Float64=1.0,
    obj_asset_map::Dict{Symbol,Base.RefValue{<:AbstractAsset}}=Dict{Symbol,Base.RefValue{<:AbstractAsset}}()
) where {T<:Union{AbstractEdge,Storage}}
    # Calculate total number of rows needed
    total_rows = length(objs) * length(field_list)
    
    if isempty(obj_asset_map)
        return DataFrame(
            case_name = fill(missing, total_rows),
            commodity = [get_commodity_name(obj) for obj in objs for f in field_list],
            commodity_subtype = [get_commodity_subtype(f) for obj in objs for f in field_list],
            zone = [get_zone_name(obj) for obj in objs for f in field_list],
            resource_id = [get_component_id(obj) for obj in objs for f in field_list],  # component id is same as resource id
            component_id = [get_component_id(obj) for obj in objs for f in field_list],
            type = [get_type(obj) for obj in objs for f in field_list],
            variable = [Symbol(f) for obj in objs for f in field_list],
            year = fill(missing, total_rows),
            value = [Float64(value(f(obj))) * scaling for obj in objs for f in field_list]
        )
    else
        return DataFrame(
            case_name = fill(missing, total_rows),
            commodity = [get_commodity_name(obj) for obj in objs for f in field_list],
            commodity_subtype = [get_commodity_subtype(f) for obj in objs for f in field_list],
            zone = [get_zone_name(obj) for obj in objs for f in field_list],
            resource_id = [get_resource_id(obj, obj_asset_map) for obj in objs for f in field_list],
            component_id = [get_component_id(obj) for obj in objs for f in field_list],
            type = [get_type(obj_asset_map[id(obj)]) for obj in objs for f in field_list],
            variable = [Symbol(f) for obj in objs for f in field_list],
            year = fill(missing, total_rows),
            value = [Float64(value(f(obj))) * scaling for obj in objs for f in field_list]
        )
    end
end
