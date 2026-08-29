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
