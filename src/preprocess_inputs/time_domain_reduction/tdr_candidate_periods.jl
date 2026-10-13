"""Complete candidates within source subperiods, and their chronological occurrences."""
struct TDRCandidatePeriods
    source_period_length::Int
    period_length::Int
    source_occurrences::Vector{Int}
    ranges::Vector{UnitRange{Int}}
    occurrence_map::Vector{Int}
    weights::Vector{Int}
    labels::Vector{Int}
    trimmed_hours_per_source_period::Int
end

function tdr_build_candidate_periods(time_data::Dict{String,Any}, case_root::String, settings::TDRSettings)
    lengths = unique(Int.(collect(values(time_data["HoursPerSubperiod"]))))
    length(lengths) == 1 || throw(ArgumentError("TDR requires the same source subperiod length for all commodities."))
    source_length = only(lengths)
    period_length = settings.timesteps_per_representative_period
    period_length <= source_length || throw(ArgumentError(
        "Requested representative-period length ($period_length) exceeds the source subperiod length ($source_length). " *
        "TDR splits source subperiods independently and cannot join them into longer periods.",
    ))
    n_sources = Int(time_data["NumberOfSubperiods"])
    n_sources > 0 && source_length > 0 || throw(ArgumentError("TDR requires positive source subperiod counts and lengths."))
    children, remainder = divrem(source_length, period_length)
    settings.representative_periods <= n_sources * children || throw(ArgumentError(
        "representative_periods ($(settings.representative_periods)) exceeds the $(n_sources * children) complete candidates within source subperiods.",
    ))
    existing_map = tdr_existing_period_map(time_data, case_root)
    occurrences, origins = if isnothing(existing_map)
        collect(1:n_sources), collect(1:n_sources)
    else
        indices = existing_map.Period_Index
        all(index -> index isa Integer && index > 0, indices) && allunique(indices) ||
            throw(ArgumentError("Sub-period map Period_Index values must be unique positive integers."))
        parents = existing_map.Rep_Period_Index
        all(index -> index isa Integer && 1 <= index <= n_sources, parents) ||
            throw(ArgumentError("Sub-period map references a representative outside the stored source subperiods."))
        order = sortperm(indices)
        sorted_parents = Int.(parents[order])
        sorted_indices = indices[order]
        origins = Int[]
        for parent in 1:n_sources
            labels = unique(existing_map.Rep_Period[parents .== parent])
            length(labels) == 1 || throw(ArgumentError("Sub-period map must identify one source label per stored representative."))
            origin = findfirst(==(only(labels)), sorted_indices)
            !isnothing(origin) && sorted_parents[origin] == parent || throw(ArgumentError(
                "Sub-period map representative labels must identify their own chronological occurrences.",
            ))
            push!(origins, origin)
        end
        issorted(origins) || throw(ArgumentError("Stored representatives must follow their chronological source-label order."))
        sorted_parents, origins
    end
    parent_weights = zeros(Int, n_sources)
    for parent in occurrences
        parent_weights[parent] += 1
    end
    all(>(0), parent_weights) || throw(ArgumentError("Sub-period map must reference every stored source subperiod."))
    ranges = UnitRange{Int}[
        ((parent - 1) * source_length + (child - 1) * period_length + 1):((parent - 1) * source_length + child * period_length)
        for parent in 1:n_sources for child in 1:children
    ]
    occurrence_map = Int[(parent - 1) * children + child for parent in occurrences for child in 1:children]
    labels = Int[(origin - 1) * children + child for origin in origins for child in 1:children]
    return TDRCandidatePeriods(source_length, period_length, occurrences, ranges,
        occurrence_map, repeat(parent_weights; inner=children), labels, remainder)
end

function tdr_build_candidate_periods(case_root::String, settings::TDRSettings; system_index::Int=1)
    _, _, time_data = tdr_full_length(tdr_system_time_data_path(case_root, system_index))
    return tdr_build_candidate_periods(time_data, case_root, settings)
end

tdr_candidate_length(periods::TDRCandidatePeriods) = length(periods.ranges) * periods.period_length
function tdr_candidate_rows(periods::TDRCandidatePeriods, selected=eachindex(periods.ranges))
    rows = Int[]
    sizehint!(rows, length(selected) * periods.period_length)
    for candidate in selected
        append!(rows, periods.ranges[candidate])
    end
    return rows
end

function tdr_candidate_sources(sources::Vector{TimeSeriesSource}, periods::TDRCandidatePeriods)
    rows = iszero(periods.trimmed_hours_per_source_period) ? nothing : tdr_candidate_rows(periods)
    return [TimeSeriesSource(source.key, source.csv_path, source.header, source.inline_file,
        source.inline_path, isnothing(rows) ? source.values : source.values[rows], source.timestep_hours, source.references,
        source.occurrences, source.user_weight, source.weight, source.include_in_clustering)
        for source in sources]
end

"""Update the explicit time grid while retaining the modeled horizon and resolution."""
function tdr_reduced_time_data(source_time_data::Dict{String,Any}, period_length::Int, count::Int)
    data = deepcopy(source_time_data)
    data["HoursPerSubperiod"] = Dict(commodity => period_length for commodity in keys(data["HoursPerSubperiod"]))
    data["NumberOfSubperiods"] = count
    pop!(data, "SubPeriodMap", nothing)
    return data
end

function tdr_candidate_summary(periods::TDRCandidatePeriods)
    return Dict(
        "source_period_length" => periods.source_period_length,
        "source_periods" => length(periods.ranges) ÷ (periods.source_period_length ÷ periods.period_length),
        "source_period_occurrences" => length(periods.source_occurrences),
        "candidate_periods" => length(periods.ranges),
        "retained_candidate_hours" => tdr_candidate_length(periods),
        "candidate_occurrence_weights" => periods.weights,
        "trimmed_hours_per_source_period" => periods.trimmed_hours_per_source_period,
        "trimmed_stored_hours" => periods.trimmed_hours_per_source_period *
            (length(periods.ranges) ÷ (periods.source_period_length ÷ periods.period_length)),
        "trimmed_represented_hours" => periods.trimmed_hours_per_source_period * length(periods.source_occurrences),
    )
end
