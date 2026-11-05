function tdr_full_length(time_data_path::String, data=mutable_json_data(read_json(time_data_path)))
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
    context::TDRContext,
    case_root::String,
    full_length::Int,
    total_hours::Int,
    trailing_hours::Ref{Int},
    all_features::Vector{TDRFeatureSpec},
    exclusions::Vector{TDRFeatureSpec},
    path::Vector{Any},
)
    haskey(descriptor, "path") && haskey(descriptor, "header") ||
        throw(ArgumentError("Timeseries descriptor in $(context.input_file) must contain `path` and `header`."))
    csv_path = abspath(joinpath(case_root, String(descriptor["path"])))
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

    reference_context = tdr_child_context(context; csv_file=csv_path, field=tdr_field_name(path))
    feature = tdr_feature_for_reference(all_features, reference_context, case_root)
    excluded = any(exclusion -> tdr_reference_matches_selector(reference_context, exclusion, feature, case_root), exclusions)
    reference = tdr_logical_reference(
        reference_context,
        path,
        feature,
        !isnothing(feature) && !excluded;
        explicitly_excluded=excluded,
    )
    tdr_add_reference!(sources, source_key, values; csv_path=csv_path, header=header, reference)
    return nothing
end

function tdr_collect_inline_reference!(
    sources::Dict{String,TimeSeriesSource},
    data::AbstractVector,
    context::TDRContext,
    case_root::String,
    full_length::Int,
    total_hours::Int,
    trailing_hours::Ref{Int},
    all_features::Vector{TDRFeatureSpec},
    exclusions::Vector{TDRFeatureSpec},
    path::Vector{Any},
)
    reference_context = tdr_child_context(context; field=tdr_field_name(path))
    feature = tdr_feature_for_reference(all_features, reference_context, case_root)
    excluded = any(exclusion -> tdr_reference_matches_selector(reference_context, exclusion, feature, case_root), exclusions)
    reference = tdr_logical_reference(
        reference_context,
        path,
        feature,
        !isnothing(feature) && !excluded;
        explicitly_excluded=excluded,
    )
    key = "inline:" * context.input_file * ":" * join(string.(path), "/")
    values, removed_hours = tdr_time_series_values(
        data,
        "inline vector in $(context.input_file)",
        full_length,
        total_hours,
    )
    trailing_hours[] = max(trailing_hours[], removed_hours)
    tdr_add_reference!(sources, key, values; inline_file=context.input_file, inline_path=path, reference)
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
    context = TDRContext(; input_file=json_file, asset, commodity)
    return tdr_collect_references!(sources, data, context, case_root, full_length, total_hours,
        trailing_hours, all_features, exclusions, commodity_names, path)
end

function tdr_collect_references!(
    sources::Dict{String,TimeSeriesSource},
    data,
    context::TDRContext,
    case_root::String,
    full_length::Int,
    total_hours::Int,
    trailing_hours::Ref{Int},
    all_features::Vector{TDRFeatureSpec},
    exclusions::Vector{TDRFeatureSpec},
    commodity_names::Set{String},
    path::Vector{Any},
)
    if data isa AbstractDict
        if haskey(data, "timeseries")
            descriptor = data["timeseries"]
            descriptor isa AbstractDict || throw(ArgumentError("Invalid timeseries descriptor in $(context.input_file)."))
            tdr_collect_csv_reference!(
                sources,
                descriptor,
                context,
                case_root,
                full_length,
                total_hours,
                trailing_hours,
                all_features,
                exclusions,
                path,
            )
            return nothing
        end
        next_asset = context.asset
        next_commodity = context.commodity
        if haskey(data, "type") && data["type"] isa AbstractString
            type_name = String(data["type"])
            if type_name in commodity_names || type_name == context.commodity
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
        child_context = tdr_child_context(context; asset=next_asset, commodity=next_commodity)
        location_entry = length(path) >= 2 && path[end-1] == "locations" &&
            path[end] isa Integer && get(data, "id", nothing) isa AbstractString
        for (key, value) in pairs(data)
            push!(path, key)
            if location_entry && key == "commodities" && value isa AbstractDict
                # These are ordinary node inputs with an implicit type. Supply
                # context to the same traversal without changing data or paths.
                for (node_commodity, node_data) in pairs(value)
                    push!(path, node_commodity)
                    node_context = tdr_child_context(child_context; commodity=String(node_commodity))
                    tdr_collect_references!(sources, node_data, node_context, case_root, full_length, total_hours, trailing_hours, all_features, exclusions, commodity_names, path)
                    pop!(path)
                end
            else
                tdr_collect_references!(sources, value, child_context, case_root, full_length, total_hours, trailing_hours, all_features, exclusions, commodity_names, path)
            end
            pop!(path)
        end
    elseif data isa AbstractVector
        if length(data) > 1 && length(data) in (full_length, total_hours) && all(value -> value isa Real, data)
            tdr_collect_inline_reference!(
                sources,
                data,
                context,
                case_root,
                full_length,
                total_hours,
                trailing_hours,
                all_features,
                exclusions,
                path,
            )
        else
            for (idx, value) in pairs(data)
                push!(path, idx)
                tdr_collect_references!(sources, value, context, case_root, full_length, total_hours, trailing_hours, all_features, exclusions, commodity_names, path)
                pop!(path)
            end
        end
    end
    return nothing
end

"""Discover physical series from an already validated time grid and dependency snapshot."""
function tdr_sources(case_root::String, settings::TDRSettings, time_grid, input_data)
    (; full_length, total_hours, time_data) = time_grid
    sources = Dict{String,TimeSeriesSource}()
    trailing_hours = Ref(0)
    commodity_names = Set(String.(keys(time_data["HoursPerTimeStep"])))
    for file in sort!(collect(keys(input_data)))
        tdr_collect_references!(sources, input_data[file], file, case_root, full_length, total_hours,
            trailing_hours, settings.all_features, settings.excluded_features, commodity_names)
    end
    isempty(sources) && throw(ArgumentError("No time-dependent inputs were discovered for TDR."))
    all_sources = sort!(collect(values(sources)); by=source -> source.key)
    any(source -> source.include_in_clustering, all_sources) ||
        throw(ArgumentError("No TDR clustering features remain after exclusions."))
    return (; sources=all_sources, trailing_hours=trailing_hours[])
end
