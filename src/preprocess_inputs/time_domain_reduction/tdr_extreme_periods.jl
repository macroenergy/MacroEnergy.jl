function tdr_feature_matches_reference(
    feature::TDRFeatureSpec,
    reference,
    source::TimeSeriesSource,
    case_root::String,
)
    !isnothing(feature.id) && reference.feature_id != feature.id && return false
    feature.field != reference.field && return false
    !isnothing(feature.asset) && feature.asset != reference.asset && return false
    !isnothing(feature.commodity) && feature.commodity != reference.commodity && return false

    if !isnothing(feature.file)
        candidate_files = String[tdr_relative_path(case_root, reference.json_file)]
        !isnothing(source.csv_path) && push!(candidate_files, tdr_relative_path(case_root, source.csv_path))
        feature.file in candidate_files || return false
    end
    return true
end

function tdr_extreme_period_sources(
    sources::Vector{TimeSeriesSource},
    specification::TDRExtremePeriodSpec,
    case_root::String,
)
    matches = [
        source for source in sources if any(
            reference -> tdr_feature_matches_reference(specification.feature, reference, source, case_root),
            source.references,
        )
    ]
    isempty(matches) && throw(ArgumentError(
        "Extreme-period feature `$(specification.feature.field)` did not match any time-series sources.",
    ))
    return matches
end

function tdr_extreme_period(
    sources::Vector{TimeSeriesSource},
    specification::TDRExtremePeriodSpec,
    period_length::Int,
)
    isempty(sources) && throw(ArgumentError("Extreme-period selection requires at least one time-series source."))
    period_length > 0 || throw(ArgumentError("Extreme-period period length must be positive."))
    full_length = length(first(sources).values)
    full_length % period_length == 0 || throw(ArgumentError(
        "Extreme-period sources must contain complete representative periods.",
    ))
    aggregate = zeros(full_length)
    for source in sources
        length(source.values) == full_length ||
            throw(ArgumentError("Extreme-period sources have inconsistent lengths."))
        aggregate .+= source.values
    end

    if specification.aggregation == :integral
        period_values = vec(sum(reshape(aggregate, period_length, :); dims=1))
        _, period = specification.select == :max ? findmax(period_values) : findmin(period_values)
        return period
    end

    _, timestep = specification.select == :max ? findmax(aggregate) : findmin(aggregate)
    return cld(timestep, period_length)
end

function tdr_extreme_periods(
    sources::Vector{TimeSeriesSource},
    period_length::Int,
    settings::TDRSettings,
    case_root::String,
)
    periods = Int[]
    for specification in settings.extreme_periods
        matching_sources = tdr_extreme_period_sources(sources, specification, case_root)
        push!(periods, tdr_extreme_period(matching_sources, specification, period_length))
    end
    unique!(sort!(periods))
    length(periods) < settings.representative_periods || throw(ArgumentError(
        "The $(length(periods)) forced extreme periods must be fewer than representative_periods ($(settings.representative_periods)).",
    ))
    return periods
end

function tdr_extreme_period_specification_data(specification::TDRExtremePeriodSpec)
    feature = specification.feature
    return Dict(
        "feature" => Dict(
            "id" => feature.id,
            "file" => feature.file,
            "asset" => feature.asset,
            "commodity" => feature.commodity,
            "field" => feature.field,
        ),
        "aggregation" => String(specification.aggregation),
        "select" => String(specification.select),
    )
end
