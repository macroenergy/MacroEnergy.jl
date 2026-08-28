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

function tdr_cluster(clustering_sources::Vector{TimeSeriesSource}, full_length::Int, settings::TDRSettings)
    period_length = settings.timesteps_per_representative_period
    n_periods = full_length ÷ period_length
    settings.representative_periods <= n_periods ||
        throw(ArgumentError("representative_periods ($(settings.representative_periods)) exceeds the $n_periods complete input periods."))

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

    input = DataFrame(clustering_matrix, :auto)
    _, assignments, _, medoids, _, _, _ = MacroEnergyTimeReduction.cluster(
        nothing,
        Dict{String,Any}(),
        String(tdr_method_name(settings.method_settings)),
        input,
        settings.representative_periods,
        tdr_method_restarts(settings.method_settings),
        v=tdr_method_verbose(settings.method_settings),
    )
    medoids = Int.(medoids)
    assignments = Int.(assignments)
    order = sortperm(medoids)
    representative_periods = medoids[order]
    cluster_to_index = Dict(order[i] => i for i in eachindex(order))
    period_map = [cluster_to_index[assignments[period]] for period in eachindex(assignments)]
    return representative_periods, period_map
end

function tdr_row_indices(representative_periods::Vector{Int}, period_length::Int)
    return reduce(vcat, [collect((period - 1) * period_length + 1:period * period_length) for period in representative_periods])
end

