function tdr_scale(values::Vector{Float64}, scaling::Symbol)
    if scaling == :normalize
        lower, upper = extrema(values)
        return upper == lower ? zeros(length(values)) : (values .- lower) ./ (upper - lower)
    end
    μ = sum(values) / length(values)
    σ = sqrt(sum((value - μ)^2 for value in values) / length(values))
    return iszero(σ) ? zeros(length(values)) : (values .- μ) ./ σ
end

tdr_method_name(::TDRKMeansSettings) = :kmeans
tdr_method_name(::TDRKMedoidsSettings) = :kmedoids
tdr_method_restarts(method_settings::AbstractTDRMethodSettings) = method_settings.restarts
tdr_method_verbose(method_settings::AbstractTDRMethodSettings) = method_settings.verbose
tdr_method_settings_data(method_settings::AbstractTDRMethodSettings) = Dict(
    "restarts" => method_settings.restarts,
    "v" => method_settings.verbose,
)

function tdr_cluster(
    clustering_sources::Vector{TimeSeriesSource},
    full_length::Int,
    settings::TDRSettings;
    extreme_periods::Vector{Int}=Int[],
)
    period_length = settings.timesteps_per_representative_period
    n_periods = full_length ÷ period_length
    settings.representative_periods <= n_periods ||
        throw(ArgumentError("representative_periods ($(settings.representative_periods)) exceeds the $n_periods complete input periods."))
    forced_periods = sort(unique(extreme_periods))
    all(1 <= period <= n_periods for period in forced_periods) ||
        throw(ArgumentError("Forced extreme periods must be within the input horizon."))
    cluster_count = settings.representative_periods - length(forced_periods)
    cluster_count > 0 || throw(ArgumentError(
        "At least one representative-period slot must remain after forcing extreme periods.",
    ))
    candidate_periods = setdiff(collect(1:n_periods), forced_periods)
    cluster_count <= length(candidate_periods) || throw(ArgumentError(
        "Not enough non-extreme periods remain for the requested representative periods.",
    ))

    # Each source contributes one profile row for every timestep in an original
    # period. The final number of rows is therefore known before filling it.
    n_rows = length(clustering_sources) * period_length
    clustering_matrix = Matrix{Float64}(undef, n_rows, n_periods)
    row_start = 1

    for source in sort(clustering_sources; by=source -> source.key)
        scaled = tdr_scale(source.values, settings.scaling) .* sqrt(source.weight)
        row_end = row_start + period_length - 1
        clustering_matrix[row_start:row_end, :] .= reshape(scaled, period_length, n_periods)
        row_start = row_end + 1
    end

    input = DataFrame(clustering_matrix[:, candidate_periods], :auto)
    _, assignments, _, medoids, _, _, _ = MacroEnergyTimeReduction.cluster(
        nothing,
        Dict{String,Any}(),
        String(tdr_method_name(settings.method_settings)),
        input,
        cluster_count,
        tdr_method_restarts(settings.method_settings),
        v=tdr_method_verbose(settings.method_settings),
    )
    medoids = Int.(medoids)
    assignments = Int.(assignments)
    clustered_representatives = candidate_periods[medoids]
    representative_periods = sort([forced_periods; clustered_representatives])
    representative_indices = Dict(period => index for (index, period) in enumerate(representative_periods))
    period_map = zeros(Int, n_periods)
    for (candidate_index, period) in enumerate(candidate_periods)
        representative_period = clustered_representatives[assignments[candidate_index]]
        period_map[period] = representative_indices[representative_period]
    end
    for period in forced_periods
        period_map[period] = representative_indices[period]
    end
    return representative_periods, period_map
end

function tdr_row_indices(representative_periods::Vector{Int}, period_length::Int)
    return reduce(vcat, [collect((period - 1) * period_length + 1:period * period_length) for period in representative_periods])
end
