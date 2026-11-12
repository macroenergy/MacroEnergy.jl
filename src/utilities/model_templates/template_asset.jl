function check_parametric_type(type::UnionAll)
    return (type = type, parameter = nothing,)
end

function check_parametric_type(type::Union{Type, UnionAll})
    if type == type.name.wrapper
        # Non-parametric type
        return (type = type, parameter = nothing,)
    else
        # Parametric type
        return (type = type.name.wrapper, parameter = type.parameters[1],)
    end
    error("Unsupported type: $type")
end

function template_asset(assets_dir::AbstractString, asset_type::Type{T}; asset_name::AbstractString=string(asset_type), existing_asset_ids::Union{AbstractSet{Symbol}, AbstractVector{Symbol}}=asset_ids_from_dir(assets_dir), style::AbstractString="full", format::AbstractString="json") where T<:AbstractAsset
    asset_type_info = check_parametric_type(asset_type)
    asset_type = asset_type_info.type
    asset_symbol = typesymbol(asset_type)
    asset_id = unique_id(Symbol(asset_name), existing_asset_ids)
    asset_data = Dict{Symbol, Any}(
        :type => asset_symbol,
        :instance_data => [default_data(asset_type, asset_id, style)],
    )
    if !isnothing(asset_type_info.parameter)
        asset_commodity = asset_type_info.parameter
        set_commodity!(asset_type, asset_commodity, asset_data[:instance_data][1])
    end
    if lowercase(format) == "json"
        filepath = find_available_filepath(joinpath(assets_dir, "$asset_name.json"))
        write_json(filepath, Dict{Symbol,Any}(Symbol(asset_name) => asset_data))
    elseif lowercase(format) == "csv"
        filepath = find_available_filepath(joinpath(assets_dir, "$asset_name.csv"))
        csv_data = json_to_csv(Dict{Symbol,Any}(Symbol(asset_name) => asset_data))
        for (_, data) in csv_data.asset_data
            write_csv(filepath, DataFrame(data))
        end
    else
        error("Unsupported format: $format. Supported formats are $(@input_formats())")
    end
    return nothing
end

function template_asset(system::AbstractSystem, asset_type::Type{T}; asset_name::AbstractString=string(asset_type), existing_asset_ids::Union{AbstractSet{Symbol}, AbstractVector{Symbol}}=asset_ids_from_dir(system), style::AbstractString="full", format::AbstractString="json") where T<:AbstractAsset
    system_data = load_system_data(joinpath(system.data_dirpath, "system_data.json"); lazy_load = true)
    assets_dir = joinpath(system.data_dirpath, system_data[:assets][:path])
    return template_asset(assets_dir, asset_type; asset_name=asset_name, existing_asset_ids=existing_asset_ids, style=style, format=format)
end

function template_asset(assets_dir::AbstractString, asset_types::Vector{T}; asset_names::Vector{String}=string.(asset_types), existing_asset_ids::Union{AbstractSet{Symbol}, AbstractVector{Symbol}}=asset_ids_from_dir(assets_dir), style::AbstractString="full", format::AbstractString="json") where T <: Union{Type, UnionAll}
    for (idx, asset_type) in enumerate(asset_types)
        template_asset(assets_dir, asset_type; asset_name=asset_names[idx], existing_asset_ids=existing_asset_ids, style=style, format=format)
    end
    return nothing
end

function template_asset(system::AbstractSystem, asset_types::Vector{T}; asset_names::Vector{String}=string.(asset_types), existing_asset_ids::Union{AbstractSet{Symbol}, AbstractVector{Symbol}}=asset_ids_from_dir(system), style::AbstractString="full", format::AbstractString="json") where T <: Union{Type, UnionAll}
    system_data = load_system_data(joinpath(system.data_dirpath, "system_data.json"); lazy_load = true)
    assets_dir = joinpath(system.data_dirpath, system_data[:assets][:path])
    return template_asset(assets_dir, asset_types; asset_names=asset_names, existing_asset_ids=existing_asset_ids, style=style, format=format)
end