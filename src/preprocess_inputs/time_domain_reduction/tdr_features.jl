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
