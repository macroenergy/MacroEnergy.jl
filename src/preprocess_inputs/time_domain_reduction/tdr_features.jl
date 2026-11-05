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
    !isnothing(addition.id) && return feature.id == addition.id
    return feature.field == addition.field && feature.file == addition.file &&
        feature.asset == addition.asset && feature.commodity == addition.commodity
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
    return tdr_normalize_path(relpath(path, case_root))
end

function tdr_context_files(context::TDRContext, case_root::String)
    files = String[tdr_relative_path(case_root, context.input_file)]
    !isnothing(context.csv_file) && push!(files, tdr_relative_path(case_root, context.csv_file))
    return files
end

# Exclusions match the actual logical reference. A selector ID refers to the
# selected feature, while file/field/asset/commodity come from the input.
function tdr_reference_matches_selector(context::TDRContext, selector::TDRFeatureSpec,
    feature::Union{Nothing,TDRFeatureSpec}, case_root::String)
    (!isnothing(selector.id) && (isnothing(feature) || feature.id != selector.id)) && return false
    (!isempty(selector.field) && context.field != selector.field) && return false
    (!isnothing(selector.file) && !(selector.file in tdr_context_files(context, case_root))) && return false
    (!isnothing(selector.asset) && context.asset != selector.asset) && return false
    (!isnothing(selector.commodity) && context.commodity != selector.commodity) && return false
    return true
end

function tdr_feature_for_reference(
    features::Vector{TDRFeatureSpec},
    context::TDRContext,
    case_root::String,
)
    candidate_files = tdr_context_files(context, case_root)
    matches = [
        feature for feature in features if feature.field == context.field &&
            (isnothing(feature.file) || feature.file in candidate_files) &&
            (isnothing(feature.asset) || feature.asset == context.asset) &&
            (isnothing(feature.commodity) || feature.commodity == context.commodity)
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
    length(matches) == 1 || throw(ArgumentError("TDR feature selection for field `$(context.field)` is ambiguous."))
    return only(matches)
end

# Preserve the existing internal entry point for callers supplying separate fields.
function tdr_feature_for_reference(features::Vector{TDRFeatureSpec}, field::String,
    json_file::String, csv_file::Union{Nothing,String}, case_root::String,
    asset::Union{Nothing,String}, commodity::Union{Nothing,String})
    context = TDRContext(; input_file=json_file, csv_file, field, asset, commodity)
    return tdr_feature_for_reference(features, context, case_root)
end

function tdr_logical_reference(
    context::TDRContext,
    input_path::Vector{Any},
    feature::Union{Nothing,TDRFeatureSpec},
    include_in_clustering::Bool;
    explicitly_excluded::Bool=false,
)
    return (
        json_file=context.input_file,
        input_path=copy(input_path),
        feature_id=isnothing(feature) ? nothing : feature.id,
        field=context.field,
        asset=context.asset,
        commodity=context.commodity,
        user_weight=isnothing(feature) ? 1.0 : feature.user_weight,
        include_in_clustering=include_in_clustering,
        clustering_exclusion_reason=include_in_clustering ? nothing :
            explicitly_excluded ? "explicitly_excluded" : "no_matching_feature",
    )
end
