function tdr_output_features_directory(case_root::String; system_index::Union{Nothing,Int}=nothing)
    isnothing(system_index) && return joinpath(case_root, "TDR", "output_features")
    return joinpath(case_root, "TDR", "systems", "system_$system_index", "output_features")
end

tdr_output_features_path(case_root::String; system_index::Union{Nothing,Int}=nothing) =
    joinpath(tdr_output_features_directory(case_root; system_index), "output_features.csv.gz")
tdr_output_metadata_path(case_root::String; system_index::Union{Nothing,Int}=nothing) =
    joinpath(tdr_output_features_directory(case_root; system_index), "output_metadata.json")

function tdr_saved_output_features_exist(case_root::String; system_index::Union{Nothing,Int}=nothing)
    return isfile(tdr_output_features_path(case_root; system_index)) &&
        isfile(tdr_output_metadata_path(case_root; system_index))
end

function tdr_output_feature_spec_data(feature::TDROutputFeatureSpec)
    return Dict(
        "id" => feature.id,
        "provider" => feature.provider,
        "asset" => feature.asset,
        "commodity" => feature.commodity,
        "weight" => feature.user_weight,
    )
end

function tdr_output_feature_specs_match(saved_data, features::Vector{TDROutputFeatureSpec})
    saved_data isa AbstractVector && length(saved_data) == length(features) || return false
    return all(zip(saved_data, features)) do (saved, feature)
        saved isa AbstractDict &&
            get(saved, "id", nothing) == feature.id &&
            get(saved, "provider", nothing) == feature.provider &&
            get(saved, "asset", nothing) == feature.asset &&
            get(saved, "commodity", nothing) == feature.commodity &&
            get(saved, "weight", nothing) == feature.user_weight
    end
end

function tdr_output_feature_column_names(sources::Vector{TimeSeriesSource})
    used = Set{String}()
    columns = String[]
    for source in sources
        base = replace(source.key, "output:" => "")
        base = replace(base, r"[^A-Za-z0-9_]+" => "_")
        column = isempty(base) ? "output_feature" : base
        suffix = 2
        while column in used
            column = "$(base)_$(suffix)"
            suffix += 1
        end
        push!(used, column)
        push!(columns, column)
    end
    return columns
end

function tdr_write_output_features!(
    case_root::String,
    sources::Vector{TimeSeriesSource},
    settings::TDRSettings,
    full_length::Int,
    ; system_index::Union{Nothing,Int}=nothing,
)
    period_length = settings.timesteps_per_representative_period
    n_periods = full_length ÷ period_length
    columns = tdr_output_feature_column_names(sources)
    data = DataFrame(
        Period_Index=repeat(collect(1:n_periods); inner=period_length),
        Time_Index=repeat(collect(1:period_length), n_periods),
    )
    for (source, column) in zip(sources, columns)
        data[!, Symbol(column)] = source.values
    end
    directory = tdr_output_features_directory(case_root; system_index)
    mkpath(directory)
    CSV.write(tdr_output_features_path(case_root; system_index), data; compress=true)
    metadata = Dict(
        "system_index" => system_index,
        "full_length" => full_length,
        "timesteps_per_representative_period" => period_length,
        "feature_specs" => tdr_output_feature_spec_data.(settings.output_features.features),
        "series" => [Dict(
            "column" => column,
            "key" => source.key,
            "feature" => tdr_output_feature_spec_data(TDROutputFeatureSpec(
                id=only(source.references).feature_id,
                provider=only(source.references).field,
                asset=only(source.references).asset,
                commodity=only(source.references).commodity,
                user_weight=only(source.references).user_weight,
            )),
            "occurrences" => source.occurrences,
            "user_weight" => source.user_weight,
            "weight" => source.weight,
        ) for (source, column) in zip(sources, columns)],
    )
    write_json(tdr_output_metadata_path(case_root; system_index), metadata)
    return nothing
end

function tdr_load_output_features(
    case_root::String,
    settings::TDRSettings,
    full_length::Int,
    ; system_index::Union{Nothing,Int}=nothing,
)
    data_path = tdr_output_features_path(case_root; system_index)
    metadata_path = tdr_output_metadata_path(case_root; system_index)
    isfile(data_path) || throw(ArgumentError("Saved TDR output features do not exist: $data_path"))
    isfile(metadata_path) || throw(ArgumentError("Saved TDR output metadata does not exist: $metadata_path"))
    metadata = mutable_json_data(read_json(metadata_path))
    get(metadata, "system_index", nothing) == system_index || throw(ArgumentError(
        "Saved TDR output features belong to a different System.",
    ))
    period_length = settings.timesteps_per_representative_period
    get(metadata, "full_length", nothing) == full_length || throw(ArgumentError("Saved TDR output features have a different input horizon."))
    get(metadata, "timesteps_per_representative_period", nothing) == period_length || throw(ArgumentError("Saved TDR output features have a different representative-period length."))
    tdr_output_feature_specs_match(get(metadata, "feature_specs", nothing), settings.output_features.features) || throw(ArgumentError(
        "Saved TDR output features were generated with different output-feature specifications.",
    ))
    data = read_csv(data_path)
    expected_periods = repeat(collect(1:full_length ÷ period_length); inner=period_length)
    expected_times = repeat(collect(1:period_length), full_length ÷ period_length)
    hasproperty(data, :Period_Index) && hasproperty(data, :Time_Index) || throw(ArgumentError(
        "Saved TDR output features must contain Period_Index and Time_Index columns.",
    ))
    data.Period_Index == expected_periods && data.Time_Index == expected_times || throw(ArgumentError(
        "Saved TDR output features are not ordered by Period_Index and Time_Index.",
    ))
    series = get(metadata, "series", nothing)
    series isa AbstractVector && !isempty(series) || throw(ArgumentError("Saved TDR output metadata has no output series."))
    sources = TimeSeriesSource[]
    for item in series
        column = Symbol(item["column"])
        column in propertynames(data) || throw(ArgumentError("Saved TDR output feature column `$column` is missing."))
        feature = tdr_output_feature_spec(item["feature"])
        values = data[!, column]
        eltype(values) <: Real || throw(ArgumentError("Saved TDR output feature `$column` is not numeric."))
        reference = (
            json_file=nothing, input_path=Any[], feature_id=feature.id, field=feature.provider,
            asset=feature.asset, commodity=feature.commodity, user_weight=feature.user_weight,
            include_in_clustering=true,
        )
        push!(sources, TimeSeriesSource(
            String(item["key"]), nothing, nothing, nothing, Any[], Float64.(values), 1,
            [reference], Int(item["occurrences"]), Float64(item["user_weight"]),
            Float64(item["weight"]), true,
        ))
    end
    return sources
end
