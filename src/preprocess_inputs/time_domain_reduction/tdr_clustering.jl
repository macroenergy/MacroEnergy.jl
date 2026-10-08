function tdr_scale(values::Vector{Float64}, scaling::Symbol; period_weights::Vector{Int}=Int[])
    if scaling == :normalize
        lower, upper = extrema(values)
        return upper == lower ? zeros(length(values)) : (values .- lower) ./ (upper - lower)
    end
    weights = isempty(period_weights) ? ones(Int, 1) : period_weights
    profiles = reshape(values, :, length(weights))
    mass = size(profiles, 1) * sum(weights)
    μ = sum(weights[p] * sum(view(profiles, :, p)) for p in eachindex(weights)) / mass
    σ = sqrt(sum(weights[p] * sum(value -> (value - μ)^2, view(profiles, :, p))
        for p in eachindex(weights)) / mass)
    return iszero(σ) ? zeros(length(values)) : (values .- μ) ./ σ
end

"""Integer observation weights for the backend, reduced by their common divisor."""
function tdr_weighted_candidates(periods::Vector{Int}, weights::Vector{Int})
    divisor = reduce(gcd, weights[periods])
    return Int[period for period in periods for _ in 1:(weights[period] ÷ divisor)]
end

function tdr_distinct_representatives(medoids, expanded_periods::Vector{Int}, distances)
    representatives = Int[]
    for medoid in medoids
        period = expanded_periods[medoid]
        if period in representatives
            # Repeated observations must not become duplicate stored representatives.
            alternatives = sortperm(view(distances, :, medoid))
            alternative = findfirst(index -> !(expanded_periods[index] in representatives), alternatives)
            isnothing(alternative) && throw(ArgumentError("Clustering did not identify enough distinct candidate periods."))
            period = expanded_periods[alternatives[alternative]]
        end
        push!(representatives, period)
    end
    return representatives
end

"""
    tdr_set_clustering_weights!(input_sources, output_sources, output_weight)

Allocate the requested share of the clustering distance to output sources and
the remaining share to input sources. Within each group, raw feature weights
(`user_weight * occurrences`) retain their relative influence.
"""
function tdr_set_clustering_weights!(
    input_sources::Vector{TimeSeriesSource},
    output_sources::Vector{TimeSeriesSource},
    output_weight::Float64,
)
    input_total = sum(source.weight for source in input_sources)
    output_total = sum(source.weight for source in output_sources)
    input_total > 0 || throw(ArgumentError("Output-based TDR requires at least one input clustering feature."))
    output_total > 0 || throw(ArgumentError("Output-based TDR requires at least one output clustering feature."))
    for source in input_sources
        source.weight = (1 - output_weight) * source.weight / input_total
    end
    for source in output_sources
        source.weight = output_weight * source.weight / output_total
    end
    return nothing
end

tdr_method_restarts(method_settings::AbstractTDRMethodSettings) = method_settings.restarts
tdr_method_verbose(method_settings::AbstractTDRMethodSettings) = method_settings.verbose
tdr_method_settings_data(method_settings::AbstractTDRMethodSettings) = Dict{String,Any}(
    "restarts" => method_settings.restarts,
    "verbose" => method_settings.verbose,
)

function tdr_autoencoder_settings_data(
    method_settings::Union{TDRAutoencoderSequentialSettings,TDRAutoencoderSimultaneousSettings},
)
    return Dict(
        "kernel_size" => method_settings.kernel_size,
        "stride" => method_settings.stride,
        "epochs" => method_settings.epochs,
        "min_err_diff" => method_settings.min_err_diff,
        "patience" => method_settings.patience,
        "warmup" => method_settings.warmup,
        "n_filters" => method_settings.n_filters,
        "latent_dim" => method_settings.latent_dim,
    )
end

tdr_method_setup(::AbstractTDRMethodSettings, ::TDRSettings) = Dict{String,Any}()

function tdr_autoencoder_method_setup(
    method_settings::Union{TDRAutoencoderSequentialSettings,TDRAutoencoderSimultaneousSettings},
    settings::TDRSettings,
)
    scaling_method = settings.scaling == :normalize ? "N" : "S"
    autoencoder_settings = tdr_autoencoder_settings_data(method_settings)
    method_settings isa TDRAutoencoderSimultaneousSettings &&
        (autoencoder_settings["lambda"] = method_settings.lambda)
    return Dict{String,Any}(
        "TimestepsPerRepPeriod" => settings.timesteps_per_representative_period,
        "ScalingMethod" => scaling_method,
        "AutoEncoder" => autoencoder_settings,
    )
end

"""Fit weighted candidate profiles and return original candidate IDs and cluster assignments.

Assignments follow `candidate_periods` order and index the returned representatives.
Backend observation indices and repetition are confined to this adapter.
"""
function tdr_cluster_candidates(matrix::Matrix{Float64}, candidate_periods::Vector{Int},
    candidate_weights::Vector{Int}, cluster_count::Int, settings::TDRSettings)
    expanded_periods = tdr_weighted_candidates(candidate_periods, candidate_weights)
    @info " -- Using $(length(expanded_periods)) observations for $(length(candidate_periods)) candidates with inherited occurrence weights."
    input = DataFrame(matrix[:, expanded_periods], :auto)
    _, assignments, _, medoids, distances, _, _ = MacroEnergyTimeReduction.cluster(
        nothing,
        tdr_method_setup(settings.method_settings, settings),
        String(tdr_method_name(settings.method_settings)),
        input,
        cluster_count,
        tdr_method_restarts(settings.method_settings),
        v=tdr_method_verbose(settings.method_settings),
    )
    medoids = Int.(medoids)
    assignments = Int.(assignments)
    clustered_representatives = tdr_distinct_representatives(medoids, expanded_periods, distances)
    first_observation = Dict{Int,Int}()
    for (index, period) in enumerate(expanded_periods)
        get!(first_observation, period, index)
    end
    candidate_assignments = Int[assignments[first_observation[period]] for period in candidate_periods]
    return (; representatives=clustered_representatives, assignments=candidate_assignments)
end

function tdr_cluster(
    clustering_sources::Vector{TimeSeriesSource},
    full_length::Int,
    settings::TDRSettings;
    extreme_periods::Vector{Int}=Int[],
    candidate_weights::Vector{Int}=ones(Int, full_length ÷ settings.timesteps_per_representative_period),
)
    period_length = settings.timesteps_per_representative_period
    n_periods = full_length ÷ period_length
    length(candidate_weights) == n_periods && all(>(0), candidate_weights) ||
        throw(ArgumentError("Every candidate period must have a positive integer occurrence weight."))
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

    method = tdr_method_name(settings.method_settings)
    @info " -- Clustering $(length(candidate_periods)) regular periods into $cluster_count representatives with `$method` ($(length(forced_periods)) forced extreme periods, $(length(clustering_sources)) time series, $(settings.scaling) scaling)."

    # Each source contributes one profile row for every timestep in an original
    # period. The final number of rows is therefore known before filling it.
    n_rows = length(clustering_sources) * period_length
    clustering_matrix = Matrix{Float64}(undef, n_rows, n_periods)
    row_start = 1

    for source in sort(clustering_sources; by=source -> source.key)
        scaled = tdr_scale(source.values, settings.scaling; period_weights=candidate_weights) .* sqrt(source.weight)
        row_end = row_start + period_length - 1
        clustering_matrix[row_start:row_end, :] .= reshape(scaled, period_length, n_periods)
        row_start = row_end + 1
    end

    result = tdr_cluster_candidates(clustering_matrix, candidate_periods,
        candidate_weights, cluster_count, settings)
    clustered_representatives = result.representatives
    representative_periods = sort([forced_periods; clustered_representatives])
    representative_indices = Dict(period => index for (index, period) in enumerate(representative_periods))
    period_map = zeros(Int, n_periods)
    for (period, assignment) in zip(candidate_periods, result.assignments)
        representative_period = clustered_representatives[assignment]
        period_map[period] = representative_indices[representative_period]
    end
    for period in representative_periods
        period_map[period] = representative_indices[period]
    end
    @info " ++ Selected $(length(clustered_representatives)) regular and $(length(forced_periods)) extreme representative periods."
    return representative_periods, period_map
end
