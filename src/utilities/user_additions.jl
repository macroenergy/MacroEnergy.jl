const USER_ADDITIONS_PATH = joinpath("user_additions")
const USER_COMMODITIES_FILE = "usercommodities.jl"
const USER_ASSETS_FILE = "userassets.jl"
const USER_ASSETS_DIR = "assets"

user_additions_path(path::AbstractString) = joinpath(path, USER_ADDITIONS_PATH)
user_additions_commodities_path(path::AbstractString) = joinpath(user_additions_path(path), USER_COMMODITIES_FILE)
user_additions_subcommodities_path(path::AbstractString) = user_additions_commodities_path(path)
user_additions_assets_path(path::AbstractString) = joinpath(user_additions_path(path), USER_ASSETS_FILE)
user_additions_assets_dir(path::AbstractString) = joinpath(user_additions_path(path), USER_ASSETS_DIR)

function list_asset_definition_files(assets_dir::AbstractString)
    if !isdir(assets_dir)
        return String[]
    end
    return sort(collect(joinpath(assets_dir, file) for file in readdir(assets_dir) if endswith(file, ".jl")))
end

function parse_asset_type_definitions(file_path::AbstractString)
    asset_names = Symbol[]
    if !isfile(file_path)
        return asset_names
    end

    pattern = r"^\s*(?:mutable\s+)?struct\s+([A-Za-z_][A-Za-z0-9_]*)\s*<:\s*(?:MacroEnergy\.)?AbstractAsset\b"
    for line in eachline(file_path)
        m = match(pattern, line)
        if !isnothing(m)
            push!(asset_names, Symbol(m.captures[1]))
        end
    end
    return asset_names
end

function is_capitalized_type_name(type_name::Symbol)
    name = String(type_name)
    return !isempty(name) && isuppercase(first(name))
end

function warn_if_noncapitalized_user_asset_names(file_path::AbstractString, asset_names::AbstractVector{Symbol})
    noncapitalized = sort!(unique!([name for name in asset_names if !is_capitalized_type_name(name)]))
    if !isempty(noncapitalized)
        @info(" ++ WARNING: Asset names should be capitalized (e.g., `MyAsset`). Found uncapitalized names in $(relpath(file_path)): $(noncapitalized). This may be required in a future version.")
    end
    return nothing
end

function load_asset_definition_files!(asset_paths::AbstractVector{<:AbstractString})
    loaded_any = false
    for asset_path in asset_paths
        try
            Base.include(MacroEnergy, asset_path)
            loaded_any = true
        catch e
            @warn("Could not load user asset file $(relpath(asset_path)): $e")
        end
    end
    return loaded_any
end

function load_user_additions(case_path::AbstractString)
    """
    Load user additions from the case `user_additions` folder into `MacroEnergy`.

    Supported files are `usercommodities.jl`, `userassets.jl`, and `assets/*.jl`.
    The `case_path` argument points to the case directory.
    """
    additions_dir = user_additions_path(case_path)
    commodities_path = user_additions_commodities_path(case_path)
    assets_path = user_additions_assets_path(case_path)
    asset_files = list_asset_definition_files(user_additions_assets_dir(case_path))

    if !isdir(additions_dir)
        @warn("User additions directory not found at $(relpath(additions_dir))")
        return nothing
    end

    @info(" ++ Loading user additions from $(relpath(additions_dir))")

    loaded_any = false
    existing_asset_types = Set(keys(all_subtypes(MacroEnergy, :AbstractAsset)))
    declared_asset_types = Symbol[]

    if isfile(commodities_path)
        try
            Base.include(MacroEnergy, commodities_path)
            loaded_any = true
        catch e
            @warn("Could not load user commodities from $(relpath(commodities_path)): $e")
        end
    end

    if isfile(assets_path)
        parsed_asset_types = parse_asset_type_definitions(assets_path)
        append!(declared_asset_types, parsed_asset_types)
        warn_if_noncapitalized_user_asset_names(assets_path, parsed_asset_types)
        try
            Base.include(MacroEnergy, assets_path)
            loaded_any = true
        catch e
            @warn("Could not load user assets from $(relpath(assets_path)): $e")
        end
    end

    for asset_file in asset_files
        parsed_asset_types = parse_asset_type_definitions(asset_file)
        append!(declared_asset_types, parsed_asset_types)
        warn_if_noncapitalized_user_asset_names(asset_file, parsed_asset_types)
    end

    loaded_any = load_asset_definition_files!(asset_files) || loaded_any

    if loaded_any
        @info(" ++ Successfully loaded user additions.")
    else
        @debug("No user additions files found in $(relpath(additions_dir))")
    end

    updated_asset_types = Set(keys(all_subtypes(MacroEnergy, :AbstractAsset)))
    added_asset_types = sort(collect(setdiff(updated_asset_types, existing_asset_types)))
    declared_asset_types = sort!(unique!(declared_asset_types))
    @info(" ++ Added user assets: $(length(declared_asset_types))")
    !isempty(declared_asset_types) && @debug(" -- Declared user assets from files: $(declared_asset_types)")
    !isempty(added_asset_types) && @debug(" -- Newly added user assets in this session: $(added_asset_types)")

    return nothing
end

function create_user_additions_module(case_path::AbstractString=pwd())
    """
    Setup user additions by loading the user additions module.
    This function is called to ensure that the user additions are loaded before running any cases.
    """
    mkpath(user_additions_path(case_path))
    mkpath(user_additions_assets_dir(case_path))
    return nothing
end

function read_unique_nonempty_lines(file_path::AbstractString)
    lines = String[]
    seen = Set{String}()
    if isfile(file_path)
        for line in eachline(file_path)
            clean = strip(line)
            if !isempty(clean) && !(clean in seen)
                push!(lines, clean)
                push!(seen, clean)
            end
        end
    end
    return lines
end

function append_unique_lines(
    base_lines::AbstractVector{<:AbstractString},
    new_lines::AbstractVector{<:AbstractString},
)
    merged_lines = String[strip(line) for line in base_lines if !isempty(strip(line))]
    merged_set = Set{String}(merged_lines)
    for line in new_lines
        clean = strip(line)
        if !isempty(clean) && !(clean in merged_set)
            push!(merged_lines, clean)
            push!(merged_set, clean)
        end
    end
    return merged_lines
end

function parse_subcommodity_definition(line::AbstractString)
    m = match(r"^abstract\s+type\s+([A-Za-z_][A-Za-z0-9_]*)\s*<:\s*([A-Za-z_][A-Za-z0-9_\.]*)\s+end$", strip(line))
    if isnothing(m)
        return nothing
    end
    name = Symbol(m.captures[1])
    parent_expr = m.captures[2]
    parent_name = Symbol(split(parent_expr, ".")[end])
    return (name=name, parent_name=parent_name)
end

function order_subcommodity_lines(lines::AbstractVector{<:AbstractString})
    remaining = collect(lines)
    ordered = String[]
    resolved_names = Set{Symbol}()

    parsed_lines = Dict{String,NamedTuple{(:name, :parent_name),Tuple{Symbol,Symbol}}}()
    for line in lines
        parsed = parse_subcommodity_definition(line)
        if !isnothing(parsed)
            parsed_lines[String(line)] = parsed
        end
    end
    names_defined_in_file = Set(info.name for info in values(parsed_lines))

    while !isempty(remaining)
        progress = false
        next_remaining = String[]

        for line in remaining
            parsed = get(parsed_lines, String(line), nothing)
            if isnothing(parsed)
                push!(ordered, String(line))
                progress = true
                continue
            end

            parent_is_file_defined = parsed.parent_name in names_defined_in_file
            if !parent_is_file_defined || (parsed.parent_name in resolved_names)
                push!(ordered, String(line))
                push!(resolved_names, parsed.name)
                progress = true
            else
                push!(next_remaining, String(line))
            end
        end

        if !progress
            append!(ordered, next_remaining)
            @warn("Could not fully order user subcommodity definitions by dependency; keeping remaining lines in original order")
            break
        end

        remaining = next_remaining
    end

    return ordered
end

function write_lines(file_path::AbstractString, lines::AbstractVector{<:AbstractString})
    open(file_path, "w") do io
        for line in lines
            println(io, line)
        end
    end
    return nothing
end

function write_user_commodities(case_path::AbstractString, subcommodities_lines::AbstractVector{<:AbstractString})
    user_commodities_path = user_additions_commodities_path(case_path)
    @debug(" -- Writing user commodities to file $(user_commodities_path)")
    mkpath(dirname(user_commodities_path))
    existing_lines = read_unique_nonempty_lines(user_commodities_path)
    merged_lines = append_unique_lines(existing_lines, subcommodities_lines)
    ordered_lines = order_subcommodity_lines(merged_lines)
    write_lines(user_commodities_path, ordered_lines)
end

write_user_subcommodities(case_path::AbstractString, subcommodities_lines::AbstractVector{<:AbstractString}) =
    write_user_commodities(case_path, subcommodities_lines)