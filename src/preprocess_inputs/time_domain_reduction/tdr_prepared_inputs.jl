"""Validate and discover each System once, before any input files are changed."""
function tdr_prepare_inputs(case_root::String, settings_by_system::Vector{TDRSettings};
    definition=tdr_system_entries(case_root))
    root, systems = definition
    length(settings_by_system) == length(systems) || throw(ArgumentError(
        "TDR received $(length(settings_by_system)) settings objects for a Case with $(length(systems)) Systems.",
    ))
    isempty(systems) && throw(ArgumentError("TDR requires at least one System."))
    json_cache = Dict{String,Any}()
    read_input(path) = get!(json_cache, path) do
        mutable_json_data(read_json(path))
    end
    case_settings = any(settings -> !isnothing(settings.output_features), settings_by_system) ?
        tdr_read_case_settings(case_root, root) : nothing
    case_definition = haskey(root, "case") ? Dict(key => value for (key, value) in root if key != "case") : Dict()
    cache_dependencies = Dict{String,TDRTrackedInput}()
    if any(settings -> !isnothing(settings.output_features) &&
            (settings.output_features.save_features || settings.output_features.reuse_saved_features), settings_by_system)
        tdr_collect_manifest_references!(cache_dependencies, case_root, case_definition, Set{String}();
            recursive_directories=false)
        implicit_settings = joinpath(case_root, "settings", "case_settings.json")
        isfile(implicit_settings) && tdr_collect_manifest_paths!(cache_dependencies, case_root, implicit_settings)
        additions = user_additions_path(case_root)
        isdir(additions) && tdr_collect_manifest_paths!(cache_dependencies, case_root, additions)
    end
    file_hashes = Dict{String,String}()
    prepared = map(enumerate(settings_by_system)) do (index, settings)
        system = systems[index]
        manifest = tdr_system_input_manifest(case_root, system)
        json_data = Dict{String,Any}(path => read_input(path) for path in keys(manifest) if isfile(path) && isjson(path))
        # A bare System can contain inline profiles in system_data.json itself.
        if !haskey(root, "case")
            json_data[joinpath(case_root, "system_data.json")] = root
        end
        time_data_path = tdr_system_time_data_path(case_root, system; system_index=index)
        time_data = get!(json_data, time_data_path) do
            read_input(time_data_path)
        end
        full_length, total_hours, _ = tdr_full_length(time_data_path, time_data)
        candidates = tdr_build_candidate_periods(time_data, case_root, settings)
        time_grid = (; full_length, total_hours, time_data_path, time_data, candidates)
        discovered = tdr_sources(case_root, settings, time_grid, json_data)
        isolated_settings = isnothing(settings.output_features) ? nothing :
            tdr_single_system_case_settings(case_settings, index)
        cache_inputs = (; system, case_definition, manifest=merge(manifest, cache_dependencies))
        output_settings = settings.output_features
        cache_fingerprint = !isnothing(output_settings) &&
            (output_settings.save_features || output_settings.reuse_saved_features) ?
            tdr_output_cache_fingerprint(case_root, settings, tdr_candidate_length(candidates);
                system_index=length(systems) > 1 ? index : nothing, file_hashes, prepared=cache_inputs) : nothing
        (; source_root=case_root, system_index=index, system, manifest, json_data,
            time_grid..., discovered..., case_settings=isolated_settings, cache_fingerprint)
    end
    return (; source_root=case_root, root, systems=prepared)
end

"""Translate a prepared System to copied paths without rediscovering its inputs."""
function tdr_relocate_inputs(inputs, destination_root::String; private_index::Union{Nothing,Int}=nothing)
    source_root = inputs.source_root
    destination(path) = isnothing(private_index) ? joinpath(destination_root, relpath(path, source_root)) :
        tdr_system_input_path(destination_root, private_index, joinpath(destination_root, relpath(path, source_root)))
    copies = Dict(path => TDRTrackedInput(path, destination(path), input.columns)
        for (path, input) in inputs.manifest)
    json_data = Dict{String,Any}()
    for (path, source_data) in inputs.json_data
        data = deepcopy(source_data)
        tdr_rewrite_input_paths!(data, source_root, destination_root, copies)
        json_data[destination(path)] = data
    end
    system = deepcopy(inputs.system)
    tdr_rewrite_input_paths!(system, source_root, destination_root, copies)
    sources = [tdr_relocate_source(source, destination) for source in inputs.sources]
    manifest = Dict(input.destination_path => TDRTrackedInput(input.destination_path,
        input.destination_path, input.columns) for input in values(copies))
    time_data_path = destination(inputs.time_data_path)
    return merge(inputs, (; source_root=destination_root, system, manifest, json_data,
        sources, time_data_path, time_data=json_data[time_data_path]))
end

function tdr_relocate_source(source::TimeSeriesSource, destination::Function)
    csv_path = isnothing(source.csv_path) ? nothing : destination(source.csv_path)
    inline_file = isnothing(source.inline_file) ? nothing : destination(source.inline_file)
    key = isnothing(csv_path) ? "inline:" * inline_file * ":" * join(string.(source.inline_path), "/") :
        "csv:" * csv_path * ":" * String(source.header)
    references = NamedTuple[merge(reference, (; json_file=isnothing(reference.json_file) ? nothing :
        destination(reference.json_file))) for reference in source.references]
    return TimeSeriesSource(key, csv_path, source.header, inline_file, source.inline_path,
        source.values, source.timestep_hours, references, source.occurrences,
        source.user_weight, source.weight, source.include_in_clustering)
end
