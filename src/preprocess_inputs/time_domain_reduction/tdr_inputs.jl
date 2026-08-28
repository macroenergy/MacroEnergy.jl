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

    function follow_paths(value)
        if value isa AbstractDict
            # Value points to a time-series, probably in a CSV file, not a
            # nested JSON input. We'll catch this later
            if haskey(value, "timeseries")
                return

            # MacroEnergy input references use a `path` field. The target can
            # be one JSON file or a directory containing several JSON inputs.
            elseif haskey(value, "path")
                reference_path = value["path"]

                if reference_path isa AbstractString
                    target = rel_or_abs_path(reference_path, case_root)

                    if isdir(target)
                        # Use the same one-level directory interpretation as
                        # normal MacroEnergy input loading.
                        for name in get_json_files(target)
                            tdr_collect_json_files!(files, case_root, joinpath(target, name))
                        end

                    elseif isjson(target)
                        # A direct JSON reference contributes one more file to
                        # the recursively resolved case-input set.
                        tdr_collect_json_files!(files, case_root, target)
                    end
                end
            end

            # An object can reference another input and also contain nested
            # references, so inspect all remaining values as well.
            for nested_value in values(value)
                follow_paths(nested_value)
            end

        elseif value isa AbstractVector
            # References can occur in lists of asset instances or other input
            # collections, so inspect every element.
            for nested_value in value
                follow_paths(nested_value)
            end
        end
    end

    follow_paths(data)
    return nothing
end

function tdr_input_json_files(case_root::String)
    root_file = joinpath(case_root, "system_data.json")
    isfile(root_file) || throw(ArgumentError("Case has no system_data.json at $(abspath(root_file))"))

    files = Set{String}()
    tdr_collect_json_files!(files, case_root, root_file)
    return sort!(collect(files))
end

function tdr_time_data_path(case_root::String, json_files::Vector{String})
    candidates = filter(path -> basename(path) == "time_data.json", json_files)
    length(candidates) == 1 || throw(ArgumentError("TDR currently requires exactly one referenced time_data.json; found $(length(candidates))."))
    return only(candidates)
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
    return only(lengths), data
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

function tdr_collect_references!(
    sources,
    data,
    json_file::String,
    case_root::String,
    full_length::Int,
    all_features::Vector{TDRFeatureSpec},
    exclusions::Vector{TDRFeatureSpec},
    commodity_names::Set{String},
    path=Any[];
    asset::Union{Nothing,String}=nothing,
    commodity::Union{Nothing,String}=nothing,
)
    if data isa AbstractDict
        if haskey(data, "timeseries")
            descriptor = data["timeseries"]
            descriptor isa AbstractDict || throw(ArgumentError("Invalid timeseries descriptor in $json_file."))
            haskey(descriptor, "path") && haskey(descriptor, "header") ||
                throw(ArgumentError("Timeseries descriptor in $json_file must contain `path` and `header`."))
            csv_path = abspath(rel_or_abs_path(String(descriptor["path"]), case_root))
            header = Symbol(descriptor["header"])
            source_key = "csv:" * csv_path * ":" * String(header)

            # Repeated descriptors can consume one physical CSV column. Its
            # values and validation are identical, so read it only once.
            if haskey(sources, source_key)
                values = sources[source_key].values
            else
                isfile(csv_path) || throw(ArgumentError("Time-series file does not exist: $csv_path"))
                frame = read_csv(csv_path, header)
                values = frame[!, header]
                eltype(values) <: Real || throw(ArgumentError("Time-series `$header` in $csv_path is not numeric."))
                length(values) == full_length || throw(ArgumentError("Time-series `$header` in $csv_path has length $(length(values)); expected $full_length."))
                values = Float64.(values)
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
            include = !excluded
            user_weight = isnothing(feature) ? 1.0 : feature.user_weight
            reference = (
                json_file=json_file,
                input_path=copy(path),
                feature_id=isnothing(feature) ? nothing : feature.id,
                field=field,
                asset=asset,
                commodity=commodity,
                user_weight=user_weight,
                include_in_clustering=include,
            )
            tdr_add_reference!(sources, source_key, values; csv_path=csv_path, header=header, reference=reference)
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
            tdr_collect_references!(sources, value, json_file, case_root, full_length, all_features, exclusions, commodity_names, [path; key]; asset=next_asset, commodity=next_commodity)
        end
    elseif data isa AbstractVector
        if length(data) == full_length && all(value -> value isa Real, data)
            field = tdr_field_name(path)
            feature = tdr_feature_for_reference(all_features, field, json_file, nothing, case_root, asset, commodity)
            if !isnothing(feature)
                excluded = any(exclusion -> tdr_feature_matches_selector(feature, exclusion), exclusions)
                reference = (
                    json_file=json_file,
                    input_path=copy(path),
                    feature_id=feature.id,
                    field=field,
                    asset=asset,
                    commodity=commodity,
                    user_weight=feature.user_weight,
                    include_in_clustering=!excluded,
                )
                key = "inline:" * json_file * ":" * join(string.(path), "/")
                tdr_add_reference!(sources, key, Float64.(data); inline_file=json_file, inline_path=path, reference=reference)
            end
        else
            for (idx, value) in pairs(data)
                tdr_collect_references!(sources, value, json_file, case_root, full_length, all_features, exclusions, commodity_names, [path; idx]; asset=asset, commodity=commodity)
            end
        end
    end
    return nothing
end

function tdr_sources(case_root::String, settings::TDRSettings)
    files = tdr_input_json_files(case_root)
    time_data_path = tdr_time_data_path(case_root, files)
    full_length, time_data = tdr_full_length(time_data_path)
    full_length % settings.timesteps_per_representative_period == 0 ||
        throw(ArgumentError("The full horizon ($full_length) is not divisible by timesteps_per_representative_period ($(settings.timesteps_per_representative_period))."))
    sources = Dict{String,TimeSeriesSource}()
    commodity_names = Set(String.(keys(time_data["HoursPerTimeStep"])))
    for file in files
        tdr_collect_references!(sources, mutable_json_data(read_json(file)), file, case_root, full_length, settings.all_features, settings.excluded_features, commodity_names)
    end
    isempty(sources) && throw(ArgumentError("No time-dependent inputs were discovered for TDR."))
    all_sources = collect(values(sources))
    clustering_sources = filter(source -> source.include_in_clustering, all_sources)
    isempty(clustering_sources) && throw(ArgumentError("No TDR clustering features remain after exclusions."))
    return all_sources, clustering_sources, full_length, time_data_path, time_data
end
