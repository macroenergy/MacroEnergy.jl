# Utility function to get the optimal capacity by macro object field
function get_optimal_capacity_by_field(system::System, capacity_func::Function, scaling::Float64=1.0)
    @debug " -- Getting optimal values for $(Symbol(capacity_func)) for the system."
    edges, edge_asset_idmap = edges_with_capacity_variables(system, return_ids_map=true)
    asset_capacity = get_optimal_vars(edges, capacity_func, scaling, edge_asset_idmap)
    df = convert_to_dataframe(asset_capacity)
    df[!, (!isa).(eachcol(df), Vector{Missing})] # remove missing columns
end

function get_optimal_capacity_by_field(asset::AbstractAsset, capacity_func::Function, scaling::Float64=1.0)
    @debug " -- Getting optimal values for $(Symbol(capacity_func)) for the asset $(id(asset))."
    edges, edge_asset_idmap = edges_with_capacity_variables(asset, return_ids_map=true)
    asset_capacity = get_optimal_vars(edges, capacity_func, scaling, edge_asset_idmap)
    df = convert_to_dataframe(asset_capacity)
    df[!, (!isa).(eachcol(df), Vector{Missing})] # remove missing columns
end

# Wrapper functions
"""
    get_optimal_capacity(system::System)

Get the optimal capacity values for all assets/edges in a system.

# Arguments
- `system::System`: The system containing the assets/edges to analyze

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
get_optimal_capacity(system::System) = get_optimal_capacity_by_field(system, capacity)

"""
    get_optimal_new_capacity(system::System)

Get the optimal new capacity values for all assets/edges in a system.

# Arguments
- `system::System`: The system containing the assets/edges to analyze

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
get_optimal_new_capacity(system::System) = get_optimal_capacity_by_field(system, new_capacity)

"""
    get_optimal_retired_capacity(system::System)

Get the optimal retired capacity values for all assets/edges in a system.

# Arguments
- `system::System`: The system containing the assets/edges to analyze

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
get_optimal_retired_capacity(system::System) = get_optimal_capacity_by_field(system, retired_capacity)

get_existing_capacity(system::System) = get_optimal_capacity_by_field(system, existing_capacity)

get_optimal_capacity(asset::AbstractAsset; scaling::Float64=1.0) = get_optimal_capacity_by_field(asset, capacity, scaling)
get_optimal_new_capacity(asset::AbstractAsset; scaling::Float64=1.0) = get_optimal_capacity_by_field(asset, new_capacity, scaling)
get_optimal_retired_capacity(asset::AbstractAsset; scaling::Float64=1.0) = get_optimal_capacity_by_field(asset, retired_capacity, scaling)
get_existing_capacity(asset::AbstractAsset; scaling::Float64=1.0) = get_optimal_capacity_by_field(asset, existing_capacity, scaling)

"""
    write_capacity_results(file_path::AbstractString, system::System)

Write the optimal capacity results for all assets/edges in a system to a file. 
The extension of the file determines the format of the file.
`Capacity`, `NewCapacity`, and `RetiredCapacity` are first concatenated and then written to the file.

# Arguments
- `file_path::AbstractString`: The path to the file where the results will be written
- `system::System`: The system containing the assets/edges to analyze

# Returns
- `nothing`: The function returns nothing, but writes the results to the file

# Example
```julia
write_capacity_results(joinpath(results_dir, "all_capacity.csv"), system)
```
"""
function write_capacity_results(file_path::AbstractString, system::System)
    @info "Writing capacity results to $file_path"
    capacity_results = get_optimal_capacity(system)
    new_capacity_results = get_optimal_new_capacity(system)
    retired_capacity_results = get_optimal_retired_capacity(system)
    exsiting_capacity_results = get_existing_capacity(system)
    all_capacity_results = vcat(capacity_results, exsiting_capacity_results, new_capacity_results, retired_capacity_results)
    write_dataframe(file_path, all_capacity_results)
    return nothing
end


