"""
Visit every input-path descriptor nested in `data`.

`visit_path!` receives the raw string stored in each descriptor. When supplied,
`timeseries_handler!` receives the complete time-series descriptor instead of
passing its path to `visit_path!`, allowing callers to inspect its header.
"""
function tdr_visit_input_paths!(visit_path!::Function, data; include_timeseries::Bool=true, stop_at_timeseries::Bool=false,
    timeseries_handler!::Union{Nothing,Function}=nothing)
    if data isa AbstractDict
        if haskey(data, "timeseries")
            # A time-series descriptor is a leaf for JSON-input discovery,
            # but its CSV path is an ordinary manifest dependency.
            stop_at_timeseries && return nothing
            descriptor = data["timeseries"]
            if include_timeseries && descriptor isa AbstractDict &&
               haskey(descriptor, "path") && descriptor["path"] isa AbstractString
                if isnothing(timeseries_handler!)
                    visit_path!(String(descriptor["path"]))
                else
                    timeseries_handler!(descriptor)
                end
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
                timeseries_handler!,
            )
        end
    elseif data isa AbstractVector
        for value in data
            tdr_visit_input_paths!(visit_path!, value;
                include_timeseries=include_timeseries,
                stop_at_timeseries=stop_at_timeseries,
                timeseries_handler!,
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
        target = abspath(joinpath(case_root, reference_path))
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
    return is_within(path, case_root)
end

"""
One input dependency in a TDR manifest, keyed by its absolute `source_path`.
`columns = nothing` requires a complete copy; otherwise it lists the requested
time-series headers. Recognized time/index columns are retained when copying.
"""
struct TDRTrackedInput
    source_path::String
    destination_path::String
    columns::Union{Nothing,Set{Symbol}}
end

function tdr_manifest_path!(manifest::Dict{String,TDRTrackedInput}, case_root::String, path::String;
    destination_root::String=case_root, system_index::Union{Nothing,Int}=nothing,
    columns::Union{Nothing,Set{Symbol}}=nothing)
    source_path = abspath(path)
    tdr_path_within_case(case_root, source_path) || throw(ArgumentError(
        "Preprocessing does not support input paths outside the source case directory: $source_path",
    ))
    ispath(source_path) || throw(ArgumentError("Referenced input path does not exist: $source_path"))
    destination = joinpath(destination_root, relpath(source_path, case_root))
    !isnothing(system_index) && (destination = tdr_system_input_path(destination_root, system_index, destination))
    if haskey(manifest, source_path)
        existing = manifest[source_path].columns
        # A complete-file reference takes precedence, regardless of traversal order.
        columns = isnothing(existing) || isnothing(columns) ? nothing : union(existing, columns)
    end
    manifest[source_path] = TDRTrackedInput(source_path, destination, columns)
    return nothing
end

function tdr_collect_manifest_paths!(manifest::Dict{String,TDRTrackedInput}, case_root::String, path::String,
    visited_json::Set{String}=Set{String}(); recursive_directories::Bool=true,
    destination_root::String=case_root, system_index::Union{Nothing,Int}=nothing)
    tdr_manifest_path!(manifest, case_root, path; destination_root, system_index)
    if isdir(path)
        directories = recursive_directories ? walkdir(path) : [(path, String[], readdir(path))]
        for (directory, _, files) in directories
            for file in files
                child = joinpath(directory, file)
                isfile(child) || continue
                tdr_collect_manifest_paths!(manifest, case_root, child, visited_json;
                    recursive_directories, destination_root, system_index)
            end
        end
        return nothing
    end
    isjson(path) || return nothing
    canonical_path = abspath(path)
    canonical_path in visited_json && return nothing
    push!(visited_json, canonical_path)
    data = mutable_json_data(read_json(canonical_path))
    tdr_collect_manifest_references!(manifest, case_root, data, visited_json;
        recursive_directories, destination_root, system_index)
    return nothing
end

"""Follow ordinary and time-series references using the same manifest traversal rules."""
function tdr_collect_manifest_references!(manifest::Dict{String,TDRTrackedInput}, case_root::String, data,
    visited_json::Set{String}; recursive_directories::Bool=true,
    destination_root::String=case_root, system_index::Union{Nothing,Int}=nothing)
    function collect_manifest_path(reference_path::String)
        target = abspath(joinpath(case_root, reference_path))
        if ispath(target)
            tdr_collect_manifest_paths!(manifest, case_root, target, visited_json;
                recursive_directories, destination_root, system_index)
        end
        return nothing
    end
    timeseries_handler! = descriptor -> tdr_collect_manifest_timeseries!(manifest, case_root, descriptor;
        destination_root, system_index)
    tdr_visit_input_paths!(collect_manifest_path, data; timeseries_handler!)
    return nothing
end

function tdr_collect_manifest_timeseries!(manifest::Dict{String,TDRTrackedInput}, case_root::String, descriptor;
    destination_root::String=case_root, system_index::Union{Nothing,Int}=nothing)
    haskey(descriptor, "header") && descriptor["header"] isa AbstractString ||
        throw(ArgumentError("Timeseries descriptors must contain a string `header`."))
    target = abspath(joinpath(case_root, String(descriptor["path"])))
    tdr_manifest_path!(manifest, case_root, target; destination_root, system_index,
        columns=Set([Symbol(descriptor["header"])]))
    return nothing
end

"""
Collect one System's dependencies as a dictionary of [`TDRTrackedInput`](@ref)
entries keyed by source path. Supply `destination_root` and `system_index` to
assign private output paths during discovery.
"""
function tdr_system_input_manifest(case_root::String, system;
    destination_root::String=case_root, system_index::Union{Nothing,Int}=nothing)
    manifest = Dict{String,TDRTrackedInput}()
    visited_json = Set{String}()
    # Ordinary input directories load their immediate files. Nested directories
    # are dependencies only when an input explicitly references them.
    tdr_collect_manifest_references!(manifest, case_root, system, visited_json;
        recursive_directories=false, destination_root, system_index)
    return manifest
end

"""Return the complete ordinary-input copy manifest rooted at `system_data.json`."""
function tdr_case_input_manifest(case_root::String; destination_root::String=case_root, prepared=nothing)
    root_file = joinpath(case_root, "system_data.json")
    isfile(root_file) || throw(ArgumentError("Case has no system_data.json at $(abspath(root_file))"))
    manifest = Dict{String,TDRTrackedInput}()
    if isnothing(prepared)
        tdr_collect_manifest_paths!(manifest, case_root, root_file; destination_root)
    else
        tdr_manifest_path!(manifest, case_root, root_file; destination_root)
        case_definition = Dict(key => value for (key, value) in prepared.root if key != "case")
        if haskey(prepared.root, "case")
            tdr_collect_manifest_references!(manifest, case_root, case_definition, Set{String}();
                recursive_directories=false, destination_root)
        end
        if length(prepared.systems) == 1
            for input in values(only(prepared.systems).manifest)
                manifest[input.source_path] = TDRTrackedInput(input.source_path,
                    joinpath(destination_root, relpath(input.source_path, case_root)), nothing)
            end
        end
    end
    for (directory, subdirectories, files) in walkdir(case_root)
        filter!(name -> !startswith(name, "results") &&
            !(directory == case_root && name == "TDR"), subdirectories)
        for file in files
            (endswith(file, ".jl") || endswith(file, ".md")) || continue
            tdr_manifest_path!(manifest, case_root, joinpath(directory, file); destination_root)
        end
    end
    additions = user_additions_path(case_root)
    if isdir(additions)
        tdr_collect_manifest_paths!(manifest, case_root, additions; destination_root)
    end
    return manifest
end

function tdr_copy_input_manifest!(source_root::String, output_root::String; copy_result_files::Bool=false, settings_path::Union{Nothing,String}=nothing, prepared=nothing)
    if !isfile(joinpath(source_root, "system_data.json"))
        for source_path in readdir(source_root; join=true)
            basename(source_path) == "TDR" && continue
            is_result_directory = isdir(source_path) && startswith(basename(source_path), "results")
            is_result_directory && !copy_result_files && continue
            cp(source_path, joinpath(output_root, basename(source_path)); force=true)
        end
        return nothing
    end
    manifest = tdr_case_input_manifest(source_root; destination_root=output_root, prepared)
    root, systems = tdr_system_entries(source_root)
    if length(systems) > 1 && isnothing(prepared)
        case_inputs = tdr_system_input_manifest(source_root,
            Dict(key => value for (key, value) in root if key != "case"))
        additions = user_additions_path(source_root)
        filter!(manifest) do entry
            path = entry.first
            path == joinpath(source_root, "system_data.json") || haskey(case_inputs, path) ||
                endswith(path, ".jl") || endswith(path, ".md") ||
                tdr_path_within_case(additions, path)
        end
    end
    if !isnothing(settings_path)
        canonical_settings = abspath(settings_path)
        tdr_path_within_case(source_root, canonical_settings) &&
            tdr_manifest_path!(manifest, source_root, canonical_settings; destination_root=output_root)
    end
    if copy_result_files
        for name in readdir(source_root)
            startswith(name, "results") || continue
            source_path = joinpath(source_root, name)
            isdir(source_path) || continue
            for (directory, _, files) in walkdir(source_path), file in files
                tdr_manifest_path!(manifest, source_root, joinpath(directory, file); destination_root=output_root)
            end
        end
    end
    for input in sort!(collect(values(manifest)); by=input -> input.source_path)
        mkpath(dirname(input.destination_path))
        # General case copies retain complete files; column selection belongs to
        # the private System copies prepared below.
        cp(input.source_path, input.destination_path; force=true)
    end
    return nothing
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

function tdr_system_time_data_path(case_root::String, system_index::Int)
    _, systems = tdr_system_entries(case_root)
    return tdr_system_time_data_path(case_root, systems[system_index]; system_index)
end

function tdr_system_time_data_path(case_root::String, system::AbstractDict; system_index::Int=1)
    haskey(system, "time_data") && system["time_data"] isa AbstractDict &&
        haskey(system["time_data"], "path") || throw(ArgumentError(
            "System $system_index must define `time_data.path` in system_data.json.",
        ))
    path = abspath(joinpath(case_root, String(system["time_data"]["path"])))
    tdr_path_within_case(case_root, path) || throw(ArgumentError("TDR does not support time_data outside the case directory: $path"))
    return path
end

"""Return the ordinary generated-case path for one System-specific input file."""
function tdr_system_input_path(case_root::String, system_index::Int, source_path::String)
    relative_path = relpath(source_path, case_root)
    tdr_path_within_case(case_root, source_path) || throw(ArgumentError(
        "TDR does not support input paths outside the case directory: $source_path",
    ))
    parts = splitpath(relative_path)
    # Re-preparing an already private input must not add another copy layer.
    if length(parts) >= 3 && parts[1] == "inputs" && occursin(r"^system_\d+$", parts[2])
        relative_path = joinpath(parts[3:end]...)
    end
    return joinpath(case_root, "inputs", "system_$system_index", relative_path)
end

"""
Rewrite mapped input paths in a JSON tree. Resolve existing references relative
to `source_root` and write replacement paths relative to `destination_root`.
"""
function tdr_rewrite_input_paths!(data, source_root::String, destination_root::String, replacements::Dict{String,TDRTrackedInput})
    if data isa AbstractDict
        if haskey(data, "path") && data["path"] isa AbstractString
            source_path = abspath(joinpath(source_root, String(data["path"])))
            if haskey(replacements, source_path)
                data["path"] = tdr_normalize_path(relpath(replacements[source_path].destination_path, destination_root))
            end
        end
        foreach(value -> tdr_rewrite_input_paths!(value, source_root, destination_root, replacements), values(data))
    elseif data isa AbstractVector
        foreach(value -> tdr_rewrite_input_paths!(value, source_root, destination_root, replacements), data)
    end
    return nothing
end

"""Copy prepared dependencies and translate their snapshots to the working Case."""
function tdr_prepare_system_inputs!(case_root::String, prepared)
    number_of_systems = length(prepared.systems)
    working = map(prepared.systems) do inputs
        relocated = tdr_relocate_inputs(inputs, case_root;
            private_index=number_of_systems > 1 ? inputs.system_index : nothing)
        if number_of_systems > 1
            for (path, input) in inputs.manifest
                destination = tdr_system_input_path(case_root, inputs.system_index,
                    joinpath(case_root, relpath(path, inputs.source_root)))
                isfile(path) && isjson(path) && continue
                tdr_copy_system_input!(TDRTrackedInput(path, destination, input.columns))
            end
            for (path, data) in relocated.json_data
                mkpath(dirname(path))
                write_json(path, data)
            end
        end
        relocated
    end
    root = deepcopy(prepared.root)
    if haskey(root, "case")
        root["case"] = [inputs.system for inputs in working]
    else
        root = only(working).system
    end
    write_json(joinpath(case_root, "system_data.json"), root)
    return merge(prepared, (; source_root=case_root, root, systems=working))
end

"""Copy an ordinary input intact, or retain only the requested time-series columns."""
function tdr_copy_system_input!(input::TDRTrackedInput)
    source_path, destination, headers = input.source_path, input.destination_path, input.columns
    if isdir(source_path)
        mkpath(destination)
        return nothing
    end
    source_path == destination && return nothing
    mkpath(dirname(destination))
    if isnothing(headers)
        cp(source_path, destination; force=true)
        return nothing
    end
    index_columns = ("time_index", "time", "index", "hour", "datetime")
    # CSV's column selector keeps source order and avoids materializing unused
    # columns. Do not use read_csv here: its cache materializes the entire file.
    data = CSV.read(source_path, DataFrame;
        select=(index, name) -> Symbol(name) in headers || lowercase(String(name)) in index_columns)
    missing_headers = setdiff(headers, Set(propertynames(data)))
    isempty(missing_headers) || throw(ArgumentError(
        "Time-series columns $(collect(missing_headers)) not found in $source_path.",
    ))
    CSV.write(destination, data; compress=endswith(destination, ".gz"))
    return nothing
end

function tdr_shared_input_path(case_root::String, path::String)
    relative_path = relpath(path, case_root)
    parts = splitpath(relative_path)
    length(parts) >= 3 || return nothing
    parts[1] == "inputs" && occursin(r"^system_\d+$", parts[2]) || return nothing
    return joinpath(case_root, parts[3:end]...)
end

"""Find shared destinations for byte-identical copies of the same input."""
function tdr_shared_input_replacements(case_root::String, source_paths; json_inputs::Bool=false, occupied_paths=Set{String}())
    replacements = Dict{String,TDRTrackedInput}()
    for (shared_path, paths) in source_paths
        content_groups = Vector{Vector{String}}()
        for path in sort!(unique(paths))
            group = findfirst(group -> read(first(group)) == read(path), content_groups)
            isnothing(group) ? push!(content_groups, [path]) : push!(content_groups[group], path)
        end
        for (group_index, group) in enumerate(content_groups)
            length(group) > 1 || continue
            # The first content group reuses the original case-relative path.
            # Additional groups and conflicting earlier consolidations stay separate.
            destination = group_index == 1 ? shared_path : joinpath(case_root,
                "inputs", "shared", "group_$group_index", relpath(shared_path, case_root))
            if json_inputs
                destination_index = group_index
                while (destination != shared_path || destination in occupied_paths) &&
                      isfile(destination) && read(destination) != read(first(group))
                    destination_index += 1
                    destination = joinpath(case_root, "inputs", "shared",
                        "group_$destination_index", relpath(shared_path, case_root))
                end
            end
            mkpath(dirname(destination))
            cp(first(group), destination; force=true)
            for path in group
                replacements[path] = TDRTrackedInput(path, destination, nothing)
            end
        end
    end
    return replacements
end

"""Consolidate identical reduced CSVs and directly referenced JSON inputs."""
function tdr_consolidate_shared_inputs!(case_root::String, prepared_systems)
    source_paths = Dict{String,Vector{String}}()
    json_paths = Set{String}([joinpath(case_root, "system_data.json")])
    time_paths = Set(inputs.time_data_path for inputs in prepared_systems)
    for inputs in prepared_systems
        union!(json_paths, keys(inputs.json_data))
        for source in inputs.sources
            isnothing(source.csv_path) && continue
            shared_path = tdr_shared_input_path(case_root, source.csv_path)
            isnothing(shared_path) && continue
            push!(get!(source_paths, shared_path, String[]), source.csv_path)
        end
    end
    replacements = tdr_shared_input_replacements(case_root, source_paths)
    while true
        # Rewrite before comparing JSON: shared children can make their parents
        # identical. Track shared JSON destinations for subsequent passes.
        for path in json_paths
            data = mutable_json_data(read_json(path))
            tdr_rewrite_input_paths!(data, case_root, case_root, replacements)
            write_json(path, data)
        end
        for input in values(replacements)
            if isjson(input.source_path)
                delete!(json_paths, input.source_path)
                push!(json_paths, input.destination_path)
            end
            rm(input.source_path; force=true)
        end

        direct_paths = Set{String}()
        directory_paths = Set{String}()
        for path in json_paths
            tdr_visit_input_paths!(mutable_json_data(read_json(path)); include_timeseries=false) do reference
                target = abspath(joinpath(case_root, reference))
                isdir(target) && push!(directory_paths, target)
                isfile(target) && isjson(target) && push!(direct_paths, target)
            end
        end
        empty!(source_paths)
        for path in direct_paths
            path in json_paths || continue
            path in time_paths && continue
            any(directory -> is_within(path, directory), directory_paths) && continue
            shared_path = tdr_shared_input_path(case_root, path)
            isnothing(shared_path) && continue
            push!(get!(source_paths, shared_path, String[]), path)
        end
        replacements = tdr_shared_input_replacements(case_root, source_paths; json_inputs=true, occupied_paths=json_paths)
        isempty(replacements) && return nothing
    end
end
