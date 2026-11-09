"""Validate and discover each System once, before any input files are changed."""
function tdr_prepare_inputs(case_root::String, settings_by_system::Vector{TDRSettings};
    definition=tdr_system_entries(case_root))
    root, systems = definition
    length(settings_by_system) == length(systems) || throw(ArgumentError(
        "TDR received $(length(settings_by_system)) settings objects for a Case with $(length(systems)) Systems.",
    ))
    isempty(systems) && throw(ArgumentError("TDR requires at least one System."))
    input_cache = Dict{String,Any}()
    csv_tables = Dict{String,DataFrame}()
    read_input(path) = get!(input_cache, path) do
        tdr_read_input_data(path, csv_tables)
    end
    case_settings = any(settings -> !isnothing(settings.output_features), settings_by_system) ?
        tdr_read_case_settings(case_root, root) : nothing
    case_definition = haskey(root, "case") ? Dict(key => value for (key, value) in root if key != "case") : Dict()
    cache_dependencies = Dict{String,TDRTrackedInput}()
    if any(settings -> !isnothing(settings.output_features) &&
            (settings.output_features.save_features || settings.output_features.reuse_saved_features), settings_by_system)
        tdr_collect_manifest_references!(cache_dependencies, case_root, case_definition, Set{String}();
            recursive_directories=false, read_input)
        implicit_settings = joinpath(case_root, "settings", "case_settings.json")
        isfile(implicit_settings) && tdr_collect_manifest_paths!(cache_dependencies, case_root, implicit_settings; read_input)
        additions = user_additions_path(case_root)
        isdir(additions) && tdr_collect_manifest_paths!(cache_dependencies, case_root, additions; read_input)
    end
    file_hashes = Dict{String,String}()
    prepared = map(enumerate(settings_by_system)) do (index, settings)
        system = systems[index]
        system_scope = tdr_system_input_scope(case_root, root, index)
        manifest = tdr_system_input_manifest(case_root, system; read_input)
        input_data = Dict{String,Any}()
        for path in keys(manifest)
            isfile(path) && (isjson(path) || haskey(input_cache, path)) || continue
            data = read_input(path)
            isnothing(data) || (input_data[path] = data)
        end
        tables = Dict(path => csv_tables[path] for path in keys(input_data) if haskey(csv_tables, path))
        # Every System has one canonical inline tree, independent of the file's outer shape.
        input_data[system_scope.file] = system
        time_data_path = tdr_system_time_data_path(case_root, system; system_index=index)
        time_data = get!(input_data, time_data_path) do
            read_input(time_data_path)
        end
        full_length, total_hours, _ = tdr_full_length(time_data_path, time_data)
        candidates = tdr_build_candidate_periods(time_data, case_root, settings)
        time_grid = (; full_length, total_hours, time_data_path, time_data, candidates)
        discovered = tdr_sources(case_root, settings, time_grid, input_data, system_scope)
        isolated_settings = isnothing(settings.output_features) ? nothing :
            tdr_single_system_case_settings(case_settings, index)
        cache_inputs = (; system, case_definition, manifest=merge(manifest, cache_dependencies))
        output_settings = settings.output_features
        cache_fingerprint = !isnothing(output_settings) &&
            (output_settings.save_features || output_settings.reuse_saved_features) ?
            tdr_output_cache_fingerprint(case_root, settings, tdr_candidate_length(candidates);
                system_index=length(systems) > 1 ? index : nothing, file_hashes, prepared=cache_inputs) : nothing
        (; source_root=case_root, system_index=index, system, system_scope, manifest, input_data, csv_tables=tables,
            time_grid..., discovered..., case_settings=isolated_settings, cache_fingerprint)
    end
    return (; source_root=case_root, root, systems=prepared)
end

"""Build the shared destination rule for a System's snapshots and dependencies.

Rebase its configured asset directory to `inputs/system_N/assets` when no outside
dependency occupies that subtree; otherwise preserve the original directory layout.
"""
function tdr_input_destination(inputs, destination_root::String, private_index::Union{Nothing,Int})
    source_root = inputs.source_root
    assets = get(inputs.system, "assets", nothing)
    asset_path = assets isa AbstractDict ? get(assets, "path", nothing) : nothing
    asset_root = asset_path isa AbstractString ? abspath(joinpath(source_root, asset_path)) : nothing
    if isnothing(private_index) || isnothing(asset_root) || !isdir(asset_root)
        asset_root = nothing
    else
        canonical = joinpath(destination_root, "inputs", "system_$private_index", "assets")
        for path in keys(inputs.manifest)
            tdr_path_within_case(asset_root, path) && continue
            relocated = joinpath(destination_root, relpath(path, source_root))
            target = tdr_system_input_path(destination_root, private_index, relocated)
            if tdr_path_within_case(canonical, target)
                asset_root = nothing
                break
            end
        end
    end
    destination_asset_root = isnothing(asset_root) ? nothing :
        joinpath(destination_root, relpath(asset_root, source_root))
    return function (path)
        path == inputs.system_scope.file && return joinpath(destination_root, "system_data.json")
        relocated = joinpath(destination_root, relpath(path, source_root))
        return isnothing(private_index) ? relocated : tdr_system_input_path(
            destination_root, private_index, relocated; asset_root=destination_asset_root)
    end
end

"""Relocate canonical input snapshots without rediscovering their series.

Preserve the System's containing path for a full Case, or pass `system_path=Any[]`
when materializing a standalone System for an isolated candidate solve.
"""
function tdr_relocate_inputs(inputs, destination_root::String;
    private_index::Union{Nothing,Int}=nothing, system_path::Vector{Any}=inputs.system_scope.path)
    source_root = inputs.source_root
    system_scope = TDRInputScope(joinpath(destination_root, "system_data.json"), copy(system_path))
    destination = tdr_input_destination(inputs, destination_root, private_index)
    copies = Dict(path => TDRTrackedInput(path, destination(path), input.columns)
        for (path, input) in inputs.manifest)
    input_data = Dict{String,Any}()
    for (path, source_data) in inputs.input_data
        data = deepcopy(source_data)
        tdr_rewrite_input_paths!(data, source_root, destination_root, copies)
        input_data[destination(path)] = data
    end
    csv_tables = Dict(destination(path) => table for (path, table) in inputs.csv_tables)
    system = input_data[system_scope.file]
    sources = [tdr_relocate_source(source, destination, inputs.system_scope, system_scope) for source in inputs.sources]
    manifest = Dict(input.destination_path => TDRTrackedInput(input.destination_path,
        input.destination_path, input.columns) for input in values(copies))
    time_data_path = destination(inputs.time_data_path)
    return merge(inputs, (; source_root=destination_root, system, system_scope, manifest, input_data, csv_tables,
        sources, time_data_path, time_data=input_data[time_data_path]))
end

"""Write dependency snapshots; the caller assembles the containing System document."""
function tdr_write_dependency_snapshots!(inputs)
    for (path, data) in inputs.input_data
        path == inputs.system_scope.file && continue
        mkpath(dirname(path))
        tdr_write_input_data(path, data, inputs.csv_tables)
    end
    return nothing
end

"""Rebase a System-owned input path when its containing document changes shape."""
function tdr_rebase_input_path(path::Vector{Any}, original::TDRInputScope, relocated::TDRInputScope)
    prefix_length = length(original.path)
    length(path) >= prefix_length && path[1:prefix_length] == original.path || throw(ArgumentError(
        "Input path $path is outside its System scope $(original.path)",
    ))
    return [relocated.path; path[prefix_length+1:end]]
end

function tdr_relocate_source(source::TimeSeriesSource, destination::Function,
    original::TDRInputScope, relocated::TDRInputScope)
    csv_path = isnothing(source.csv_path) ? nothing : destination(source.csv_path)
    inline_file = isnothing(source.inline_file) ? nothing : destination(source.inline_file)
    inline_path = source.inline_file == original.file ?
        tdr_rebase_input_path(source.inline_path, original, relocated) : copy(source.inline_path)
    key = isnothing(csv_path) ? "inline:" * inline_file * ":" * join(string.(inline_path), "/") :
        "csv:" * csv_path * ":" * String(source.header)
    references = NamedTuple[merge(reference, (;
        json_file=isnothing(reference.json_file) ? nothing : destination(reference.json_file),
        input_path=reference.json_file == original.file ?
            tdr_rebase_input_path(reference.input_path, original, relocated) : copy(reference.input_path),
    )) for reference in source.references]
    return TimeSeriesSource(key, csv_path, source.header, inline_file, inline_path,
        source.values, source.timestep_hours, references, source.occurrences,
        source.user_weight, source.weight, source.include_in_clustering)
end
