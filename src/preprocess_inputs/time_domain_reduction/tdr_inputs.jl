function tdr_feature_spec(data::AbstractDict; require_field::Bool=true)
    require_field && !haskey(data, "field") &&
        throw(ArgumentError("Each TDR feature must define `field`."))
    field = get(data, "field", "")
    field isa AbstractString || throw(ArgumentError("TDR feature `field` must be a string."))
    id = get(data, "id", nothing)
    file = get(data, "file", nothing)
    asset = get(data, "asset", nothing)
    commodity = get(data, "commodity", nothing)
    id !== nothing && !(id isa AbstractString) && throw(ArgumentError("TDR feature `id` must be a string."))
    file !== nothing && !(file isa AbstractString) && throw(ArgumentError("TDR feature `file` must be a string."))
    asset !== nothing && !(asset isa AbstractString) && throw(ArgumentError("TDR feature `asset` must be a string."))
    commodity !== nothing && !(commodity isa AbstractString) && throw(ArgumentError("TDR feature `commodity` must be a string."))
    weight = get(data, "weight", 1.0)
    weight isa Real && isfinite(weight) && weight > 0 ||
        throw(ArgumentError("TDR feature `weight` must be a finite positive number."))
    return TDRFeatureSpec(
        id=id,
        file=file,
        asset=asset,
        commodity=commodity,
        field=String(field),
        user_weight=Float64(weight),
        has_user_weight=haskey(data, "weight"),
    )
end

function tdr_feature_matches_selector(feature::TDRFeatureSpec, selector::TDRFeatureSpec)
    (!isnothing(selector.id) && feature.id != selector.id) && return false
    !isempty(selector.field) && feature.field != selector.field && return false
    (!isnothing(selector.file) && feature.file != selector.file) && return false
    (!isnothing(selector.asset) && feature.asset != selector.asset) && return false
    (!isnothing(selector.commodity) && feature.commodity != selector.commodity) && return false
    return true
end

function tdr_feature_override_matches(feature::TDRFeatureSpec, addition::TDRFeatureSpec)
    !isnothing(addition.id) && feature.id != addition.id && return false
    feature.field != addition.field && return false
    !isnothing(addition.file) && feature.file != addition.file && return false
    return true
end

function tdr_merge_features(user_features::Vector{TDRFeatureSpec})
    features = copy(TDR_DEFAULT_FEATURES)
    for addition in user_features
        matches = findall(feature -> tdr_feature_override_matches(feature, addition), features)
        if isempty(matches)
            push!(features, addition)
        elseif length(matches) == 1
            existing = features[matches[1]]
            existing_data = Dict(
                "id" => existing.id,
                "file" => existing.file,
                "asset" => existing.asset,
                "commodity" => existing.commodity,
                "field" => existing.field,
                "weight" => existing.user_weight,
            )
            addition_data = Dict(
                key => value for (key, value) in (
                    "id" => addition.id,
                    "file" => addition.file,
                    "asset" => addition.asset,
                    "commodity" => addition.commodity,
                    "field" => addition.field,
                    "weight" => addition.has_user_weight ? addition.user_weight : nothing,
                ) if !isnothing(value)
            )
            features[matches[1]] = tdr_feature_spec(recursive_merge(existing_data, addition_data))
        else
            throw(ArgumentError("TDR feature selector for `$(addition.field)` is ambiguous."))
        end
    end
    return features
end

"""
Visit every input-path descriptor nested in `data`.

`visit_path!` receives the raw string stored in each descriptor.  Keeping the
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
        relative_directory = relpath(directory, case_root)
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

function tdr_full_length(time_data_path::String)
    data = mutable_json_data(read_json(time_data_path))
    hpt = get(data, "HoursPerTimeStep", nothing)
    hps = get(data, "HoursPerSubperiod", nothing)
    n_subperiods = get(data, "NumberOfSubperiods", nothing)
    hpt isa AbstractDict && hps isa AbstractDict && n_subperiods isa Integer ||
        throw(ArgumentError("Invalid time_data.json for TDR at $time_data_path."))
    all(value -> value == 1, values(hpt)) ||
        throw(ArgumentError("TDR currently supports only hourly source inputs; every HoursPerTimeStep value must equal 1."))
    lengths = unique(Int(n_subperiods) * Int(value) for value in values(hps))
    length(lengths) == 1 ||
        throw(ArgumentError("TDR currently requires all commodities to have the same full hourly horizon."))
    explicit_hours = only(lengths)
    total_hours = get(data, "TotalHoursModeled", explicit_hours)
    total_hours isa Integer && total_hours >= explicit_hours || throw(ArgumentError(
        "TDR requires TotalHoursModeled to be an integer no smaller than the explicit " *
        "subperiod horizon ($explicit_hours hours).",
    ))
    return explicit_hours, Int(total_hours), data
end

function tdr_time_series_values(
    values,
    source_description::String,
    explicit_hours::Int,
    total_hours::Int,
)
    eltype(values) <: Real || throw(ArgumentError("Time-series `$source_description` is not numeric."))
    if length(values) == explicit_hours
        return Float64.(values), 0
    elseif total_hours > explicit_hours && length(values) == total_hours
        return Float64.(values[1:explicit_hours]), total_hours - explicit_hours
    end
    expected_lengths = total_hours == explicit_hours ? "$explicit_hours" : "$explicit_hours or $total_hours"
    throw(ArgumentError(
        "Time-series `$source_description` has length $(length(values)); expected $expected_lengths. " *
        "The explicit MacroEnergy subperiod grid contains $explicit_hours hours.",
    ))
end

function tdr_field_name(path::Vector{Any})
    keys = String[string(key) for key in path if !(key isa Integer)]
    isempty(keys) && return ""
    last_key = last(keys)
    if last_key in ("price", "min", "max") && "supply" in keys
        return "supply.$last_key"
    end
    return last_key
end

function tdr_relative_path(case_root::String, path::String)
    return replace(relpath(path, case_root), '\\' => '/')
end

function tdr_feature_for_reference(
    features::Vector{TDRFeatureSpec},
    field::String,
    json_file::String,
    csv_file::Union{Nothing,String},
    case_root::String,
    asset::Union{Nothing,String},
    commodity::Union{Nothing,String},
)
    candidate_files = String[tdr_relative_path(case_root, json_file)]
    !isnothing(csv_file) && push!(candidate_files, tdr_relative_path(case_root, csv_file))
    matches = [
        feature for feature in features if feature.field == field &&
            (isnothing(feature.file) || feature.file in candidate_files) &&
            (isnothing(feature.asset) || feature.asset == asset) &&
            (isnothing(feature.commodity) || feature.commodity == commodity)
    ]
    isempty(matches) && return nothing
    specificity = [
        (!isnothing(feature.file) ? 1 : 0) +
        (!isnothing(feature.asset) ? 1 : 0) +
        (!isnothing(feature.commodity) ? 1 : 0)
        for feature in matches
    ]
    best = maximum(specificity)
    matches = matches[specificity .== best]
    length(matches) == 1 || throw(ArgumentError("TDR feature selection for field `$field` is ambiguous."))
    return only(matches)
end

function tdr_add_reference!(sources::Dict{String,TimeSeriesSource}, key::String, values::Vector{Float64}; csv_path=nothing, header=nothing, inline_file=nothing, inline_path=Any[], reference)
    if !haskey(sources, key)
        sources[key] = TimeSeriesSource(
            key,
            csv_path,
            header,
            inline_file,
            copy(inline_path),
            values,
            1,
            NamedTuple[],
            0,
            reference.user_weight,
            0.0,
            reference.include_in_clustering,
        )
    end
    source = sources[key]
    length(source.values) == length(values) || throw(ArgumentError("Time-series source `$key` has inconsistent lengths."))
    push!(source.references, reference)
    source.occurrences += 1
    if reference.include_in_clustering
        if source.include_in_clustering && source.user_weight != reference.user_weight
            throw(ArgumentError("Time-series source `$key` is assigned conflicting feature weights."))
        elseif !source.include_in_clustering
            source.user_weight = reference.user_weight
        end
        source.include_in_clustering = true
    end
    source.weight = source.user_weight * source.occurrences
    return nothing
end

function tdr_commodity_context(data::AbstractDict, commodity_names::Set{String})
    values = Set{String}()
    function collect_commodities(value)
        if value isa AbstractDict
            for (key, nested) in pairs(value)
                String(key) in ("commodity", "timedata", "time_interval") &&
                    nested isa AbstractString && String(nested) in commodity_names &&
                    push!(values, String(nested))
                collect_commodities(nested)
            end
        elseif value isa AbstractVector
            foreach(collect_commodities, value)
        end
    end
    collect_commodities(data)
    return length(values) == 1 ? only(values) : nothing
end

function tdr_logical_reference(
    json_file::String,
    input_path::Vector{Any},
    field::String,
    feature::Union{Nothing,TDRFeatureSpec},
    asset::Union{Nothing,String},
    commodity::Union{Nothing,String},
    include_in_clustering::Bool,
)
    return (
        json_file=json_file,
        input_path=copy(input_path),
        feature_id=isnothing(feature) ? nothing : feature.id,
        field=field,
        asset=asset,
        commodity=commodity,
        user_weight=isnothing(feature) ? 1.0 : feature.user_weight,
        include_in_clustering=include_in_clustering,
    )
end

function tdr_collect_csv_reference!(
    sources::Dict{String,TimeSeriesSource},
    descriptor::AbstractDict,
    json_file::String,
    case_root::String,
    full_length::Int,
    total_hours::Int,
    trailing_hours::Ref{Int},
    all_features::Vector{TDRFeatureSpec},
    exclusions::Vector{TDRFeatureSpec},
    path::Vector{Any},
    asset::Union{Nothing,String},
    commodity::Union{Nothing,String},
)
    haskey(descriptor, "path") && haskey(descriptor, "header") ||
        throw(ArgumentError("Timeseries descriptor in $json_file must contain `path` and `header`."))
    csv_path = abspath(rel_or_abs_path(String(descriptor["path"]), case_root))
    header = Symbol(descriptor["header"])
    source_key = "csv:" * csv_path * ":" * String(header)

    # Repeated descriptors can consume one physical CSV column. Its values
    # and validation are identical, so read it only once.
    if haskey(sources, source_key)
        values = sources[source_key].values
    else
        isfile(csv_path) || throw(ArgumentError("Time-series file does not exist: $csv_path"))
        frame = read_csv(csv_path, header)
        values, removed_hours = tdr_time_series_values(
            frame[!, header],
            "$header in $csv_path",
            full_length,
            total_hours,
        )
        trailing_hours[] = max(trailing_hours[], removed_hours)
    end

    field = tdr_field_name(path)
    feature = tdr_feature_for_reference(all_features, field, json_file, csv_path, case_root, asset, commodity)
    selector = TDRFeatureSpec(
        file=tdr_relative_path(case_root, csv_path),
        asset=asset,
        commodity=commodity,
        field=field,
    )
    excluded = isnothing(feature) ?
        any(exclusion -> tdr_feature_matches_selector(selector, exclusion), exclusions) :
        any(exclusion -> tdr_feature_matches_selector(feature, exclusion), exclusions)
    reference = tdr_logical_reference(
        json_file,
        path,
        field,
        feature,
        asset,
        commodity,
        !isnothing(feature) && !excluded,
    )
    tdr_add_reference!(sources, source_key, values; csv_path=csv_path, header=header, reference)
    return nothing
end

function tdr_collect_inline_reference!(
    sources::Dict{String,TimeSeriesSource},
    data::AbstractVector,
    json_file::String,
    case_root::String,
    full_length::Int,
    total_hours::Int,
    trailing_hours::Ref{Int},
    all_features::Vector{TDRFeatureSpec},
    exclusions::Vector{TDRFeatureSpec},
    path::Vector{Any},
    asset::Union{Nothing,String},
    commodity::Union{Nothing,String},
)
    field = tdr_field_name(path)
    feature = tdr_feature_for_reference(all_features, field, json_file, nothing, case_root, asset, commodity)
    isnothing(feature) && return nothing

    excluded = any(exclusion -> tdr_feature_matches_selector(feature, exclusion), exclusions)
    reference = tdr_logical_reference(
        json_file,
        path,
        field,
        feature,
        asset,
        commodity,
        !excluded,
    )
    key = "inline:" * json_file * ":" * join(string.(path), "/")
    values, removed_hours = tdr_time_series_values(
        data,
        "inline vector in $json_file",
        full_length,
        total_hours,
    )
    trailing_hours[] = max(trailing_hours[], removed_hours)
    tdr_add_reference!(sources, key, values; inline_file=json_file, inline_path=path, reference)
    return nothing
end

function tdr_collect_references!(
    sources::Dict{String,TimeSeriesSource},
    data,
    json_file::String,
    case_root::String,
    full_length::Int,
    total_hours::Int,
    trailing_hours::Ref{Int},
    all_features::Vector{TDRFeatureSpec},
    exclusions::Vector{TDRFeatureSpec},
    commodity_names::Set{String},
    path::Vector{Any}=Any[];
    asset::Union{Nothing,String}=nothing,
    commodity::Union{Nothing,String}=nothing,
)
    if data isa AbstractDict
        if haskey(data, "timeseries")
            descriptor = data["timeseries"]
            descriptor isa AbstractDict || throw(ArgumentError("Invalid timeseries descriptor in $json_file."))
            tdr_collect_csv_reference!(
                sources,
                descriptor,
                json_file,
                case_root,
                full_length,
                total_hours,
                trailing_hours,
                all_features,
                exclusions,
                path,
                asset,
                commodity,
            )
            return nothing
        end
        next_asset = asset
        next_commodity = commodity
        if haskey(data, "type") && data["type"] isa AbstractString
            type_name = String(data["type"])
            if type_name in commodity_names
                next_commodity = type_name
            else
                next_asset = type_name
            end
        end
        if haskey(data, "commodity") && data["commodity"] isa AbstractString
            next_commodity = String(data["commodity"])
        end
        if isnothing(next_commodity) && haskey(data, "global_data") && data["global_data"] isa AbstractDict
            next_commodity = tdr_commodity_context(data["global_data"], commodity_names)
        end
        for (key, value) in pairs(data)
            push!(path, key)
            tdr_collect_references!(sources, value, json_file, case_root, full_length, total_hours, trailing_hours, all_features, exclusions, commodity_names, path; asset=next_asset, commodity=next_commodity)
            pop!(path)
        end
    elseif data isa AbstractVector
        if length(data) in (full_length, total_hours) && all(value -> value isa Real, data)
            tdr_collect_inline_reference!(
                sources,
                data,
                json_file,
                case_root,
                full_length,
                total_hours,
                trailing_hours,
                all_features,
                exclusions,
                path,
                asset,
                commodity,
            )
        else
            for (idx, value) in pairs(data)
                push!(path, idx)
                tdr_collect_references!(sources, value, json_file, case_root, full_length, total_hours, trailing_hours, all_features, exclusions, commodity_names, path; asset=asset, commodity=commodity)
                pop!(path)
            end
        end
    end
    return nothing
end

function tdr_sources(case_root::String, settings::TDRSettings; system_index::Int=1)
    files = tdr_system_json_files(case_root, system_index)
    time_data_path = tdr_system_time_data_path(case_root, system_index)
    full_length, total_hours, time_data = tdr_full_length(time_data_path)
    full_length % settings.timesteps_per_representative_period == 0 ||
        throw(ArgumentError("The full horizon ($full_length) is not divisible by timesteps_per_representative_period ($(settings.timesteps_per_representative_period))."))
    sources = Dict{String,TimeSeriesSource}()
    trailing_hours = Ref(0)
    commodity_names = Set(String.(keys(time_data["HoursPerTimeStep"])))
    for file in files
        tdr_collect_references!(sources, mutable_json_data(read_json(file)), file, case_root, full_length, total_hours, trailing_hours, settings.all_features, settings.excluded_features, commodity_names)
    end
    isempty(sources) && throw(ArgumentError("No time-dependent inputs were discovered for TDR."))
    all_sources = sort!(collect(values(sources)); by=source -> source.key)
    clustering_sources = filter(source -> source.include_in_clustering, all_sources)
    isempty(clustering_sources) && throw(ArgumentError("No TDR clustering features remain after exclusions."))
    return all_sources, clustering_sources, full_length, time_data_path, time_data, trailing_hours[]
end
