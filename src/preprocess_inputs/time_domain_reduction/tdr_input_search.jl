"""
Visit every input-path descriptor nested in `data`.

`visit_path!` receives the raw string stored in each descriptor. Keeping the
tree traversal here makes the deliberately different handling of time-series
descriptors explicit at its callers.
"""
function tdr_visit_input_paths!(visit_path!::Function, data; include_timeseries::Bool=true, stop_at_timeseries::Bool=false)
    if data isa AbstractDict
        if haskey(data, "timeseries")
            # A time-series descriptor is a leaf for JSON-input discovery,
            # but its CSV path is an ordinary manifest dependency.
            stop_at_timeseries && return nothing
            descriptor = data["timeseries"]
            if include_timeseries && descriptor isa AbstractDict &&
               haskey(descriptor, "path") && descriptor["path"] isa AbstractString
                visit_path!(String(descriptor["path"]))
            end
        end
        if haskey(data, "path") && data["path"] isa AbstractString
            visit_path!(String(data["path"]))
        end
        for (key, value) in pairs(data)
            # The descriptor path was handled above. Do not visit it again as
            # an ordinary nested `path` field.
            key == "timeseries" && continue
            tdr_visit_input_paths!(visit_path!, value;
                include_timeseries=include_timeseries,
                stop_at_timeseries=stop_at_timeseries,
            )
        end
    elseif data isa AbstractVector
        for value in data
            tdr_visit_input_paths!(visit_path!, value;
                include_timeseries=include_timeseries,
                stop_at_timeseries=stop_at_timeseries,
            )
        end
    end
    return nothing
end

function tdr_collect_json_files!(files::Set{String}, case_root::String, path::String)
    canonical_path = abspath(path)
    if canonical_path in files
        # Multiple input references can point to the same JSON file. Avoid
        # reading it twice and following a cyclic reference forever.
        return nothing
    end

    if !(isfile(canonical_path) && isjson(canonical_path))
        # References may also point to CSV files or optional/missing files.
        # JSON files are the only inputs that may contain further references.
        return nothing
    end

    push!(files, canonical_path)
    data = mutable_json_data(read_json(canonical_path))

    function follow_json_path(reference_path::String)
        target = rel_or_abs_path(reference_path, case_root)
        if isdir(target)
            # Use the same one-level directory interpretation as normal
            # MacroEnergy input loading.
            for name in get_json_files(target)
                tdr_collect_json_files!(files, case_root, joinpath(target, name))
            end
        elseif isjson(target)
            tdr_collect_json_files!(files, case_root, target)
        end
        return nothing
    end
    tdr_visit_input_paths!(follow_json_path, data;
        include_timeseries=false,
        stop_at_timeseries=true,
    )
    return nothing
end

function tdr_input_json_files(case_root::String)
    root_file = joinpath(case_root, "system_data.json")
    isfile(root_file) || throw(ArgumentError("Case has no system_data.json at $(abspath(root_file))"))

    files = Set{String}()
    tdr_collect_json_files!(files, case_root, root_file)
    return sort!(collect(files))
end

function tdr_path_within_case(case_root::String, path::String)
    relative = relpath(path, case_root)
    return relative != ".." && !startswith(relative, "../") && !startswith(relative, "..\\")
end

function tdr_manifest_path!(paths::Set{String}, case_root::String, path::String)
    canonical_path = abspath(path)
    tdr_path_within_case(case_root, canonical_path) || throw(ArgumentError(
        "Preprocessing does not support input paths outside the source case directory: $canonical_path",
    ))
    ispath(canonical_path) || throw(ArgumentError("Referenced input path does not exist: $canonical_path"))
    push!(paths, canonical_path)
    return nothing
end

function tdr_collect_manifest_paths!(paths::Set{String}, case_root::String, path::String, visited_json::Set{String}=Set{String}())
    tdr_manifest_path!(paths, case_root, path)
    isdir(path) && begin
        for (directory, _, files) in walkdir(path)
            for file in files
                child = joinpath(directory, file)
                tdr_manifest_path!(paths, case_root, child)
                isjson(child) && tdr_collect_manifest_paths!(paths, case_root, child, visited_json)
            end
        end
        return nothing
    end
    isjson(path) || return nothing
    canonical_path = abspath(path)
    canonical_path in visited_json && return nothing
    push!(visited_json, canonical_path)
    data = mutable_json_data(read_json(canonical_path))

    function collect_manifest_path(reference_path::String)
        target = abspath(rel_or_abs_path(reference_path, case_root))
        if ispath(target)
            tdr_collect_manifest_paths!(paths, case_root, target, visited_json)
        end
        return nothing
    end
    tdr_visit_input_paths!(collect_manifest_path, data)
    return nothing
end

"""Return the complete ordinary-input copy manifest rooted at `system_data.json`."""
function tdr_case_input_manifest(case_root::String)
    root_file = joinpath(case_root, "system_data.json")
    isfile(root_file) || throw(ArgumentError("Case has no system_data.json at $(abspath(root_file))"))
    paths = Set{String}()
    tdr_collect_manifest_paths!(paths, case_root, root_file)
    for (directory, _, files) in walkdir(case_root)
        startswith(basename(directory), "results") && continue
        for file in files
            (endswith(file, ".jl") || endswith(file, ".md")) || continue
            tdr_manifest_path!(paths, case_root, joinpath(directory, file))
        end
    end
    additions = user_additions_path(case_root)
    if isdir(additions)
        tdr_collect_manifest_paths!(paths, case_root, additions)
    end
    return sort!(collect(paths))
end

function tdr_copy_input_manifest!(source_root::String, output_root::String; copy_result_files::Bool=false, settings_path::Union{Nothing,String}=nothing)
    if !isfile(joinpath(source_root, "system_data.json"))
        for source_path in readdir(source_root; join=true)
            is_result_directory = isdir(source_path) && startswith(basename(source_path), "results")
            is_result_directory && !copy_result_files && continue
            cp(source_path, joinpath(output_root, basename(source_path)); force=true)
        end
        return nothing
    end
    paths = tdr_case_input_manifest(source_root)
    if !isnothing(settings_path)
        canonical_settings = abspath(settings_path)
        tdr_path_within_case(source_root, canonical_settings) && push!(paths, canonical_settings)
    end
    if copy_result_files
        for name in readdir(source_root)
            startswith(name, "results") || continue
            source_path = joinpath(source_root, name)
            isdir(source_path) && append!(paths, [joinpath(directory, file) for (directory, _, files) in walkdir(source_path) for file in files])
        end
    end
    for source_path in unique(paths)
        relative = relpath(source_path, source_root)
        destination = joinpath(output_root, relative)
        mkpath(dirname(destination))
        cp(source_path, destination; force=true)
    end
    return nothing
end

function tdr_time_data_path(case_root::String, json_files::Vector{String})
    candidates = filter(path -> basename(path) == "time_data.json", json_files)
    length(candidates) == 1 || throw(ArgumentError("TDR currently requires exactly one referenced time_data.json; found $(length(candidates))."))
    return only(candidates)
end

function tdr_system_entries(case_root::String)
    root_path = joinpath(case_root, "system_data.json")
    root = mutable_json_data(read_json(root_path))
    if haskey(root, "case")
        root["case"] isa AbstractVector || throw(ArgumentError("`case` in system_data.json must be an array."))
        return root, root["case"]
    end
    return root, Any[root]
end

function tdr_system_json_files(case_root::String, system_index::Int)
    root, systems = tdr_system_entries(case_root)
    1 <= system_index <= length(systems) || throw(ArgumentError("System $system_index is outside the case's $(length(systems)) Systems."))
    files = Set{String}()
    function collect_json_path(reference_path::String)
        target = abspath(rel_or_abs_path(reference_path, case_root))
        if ispath(target)
            tdr_path_within_case(case_root, target) || throw(ArgumentError("TDR does not support input paths outside the case directory: $target"))
            if isdir(target)
                for name in get_json_files(target)
                    tdr_collect_json_files!(files, case_root, joinpath(target, name))
                end
            elseif isjson(target)
                tdr_collect_json_files!(files, case_root, target)
            end
        end
        return nothing
    end
    tdr_visit_input_paths!(collect_json_path, systems[system_index])
    !haskey(root, "case") && push!(files, joinpath(case_root, "system_data.json"))
    return sort!(collect(files))
end

function tdr_system_time_data_path(case_root::String, system_index::Int)
    _, systems = tdr_system_entries(case_root)
    system = systems[system_index]
    haskey(system, "time_data") && system["time_data"] isa AbstractDict &&
        haskey(system["time_data"], "path") || throw(ArgumentError(
            "System $system_index must define `time_data.path` in system_data.json.",
        ))
    path = abspath(rel_or_abs_path(String(system["time_data"]["path"]), case_root))
    tdr_path_within_case(case_root, path) || throw(ArgumentError("TDR does not support time_data outside the case directory: $path"))
    return path
end

tdr_system_inputs_directory(case_root::String, system_index::Int) =
    joinpath(case_root, "TDR", "systems", "system_$system_index", "inputs")

function tdr_rewrite_input_paths!(data, source_root::String, destination_root::String)
    if data isa AbstractDict
        if haskey(data, "path") && data["path"] isa AbstractString
            source_path = abspath(rel_or_abs_path(String(data["path"]), source_root))
            if ispath(source_path) && tdr_path_within_case(source_root, source_path)
                data["path"] = replace(relpath(joinpath(destination_root, relpath(source_path, source_root)), source_root), '\\' => '/')
            end
        end
        foreach(value -> tdr_rewrite_input_paths!(value, source_root, destination_root), values(data))
    elseif data isa AbstractVector
        foreach(value -> tdr_rewrite_input_paths!(value, source_root, destination_root), data)
    end
    return nothing
end

function tdr_prepare_system_inputs!(case_root::String)
    root, systems = tdr_system_entries(case_root)
    length(systems) == 1 && return 1
    manifest = filter(isfile, tdr_case_input_manifest(case_root))
    for system_index in eachindex(systems)
        destination_root = tdr_system_inputs_directory(case_root, system_index)
        for source_path in manifest
            destination = joinpath(destination_root, relpath(source_path, case_root))
            mkpath(dirname(destination))
            cp(source_path, destination; force=true)
        end
        for source_path in manifest
            isjson(source_path) || continue
            destination = joinpath(destination_root, relpath(source_path, case_root))
            data = mutable_json_data(read_json(destination))
            tdr_rewrite_input_paths!(data, case_root, destination_root)
            write_json(destination, data)
        end
        tdr_rewrite_input_paths!(systems[system_index], case_root, destination_root)
    end
    write_json(joinpath(case_root, "system_data.json"), root)
    return length(systems)
end
