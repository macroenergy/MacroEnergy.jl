function tdr_write_reduced_sources!(sources::Vector{TimeSeriesSource}, row_indices::Vector{Int})
    by_csv = Dict{String,Vector{TimeSeriesSource}}()
    inline = TimeSeriesSource[]
    for source in sources
        if isnothing(source.csv_path)
            push!(inline, source)
        else
            push!(get!(by_csv, source.csv_path, TimeSeriesSource[]), source)
        end
    end
    for (source_path, _) in by_csv
        frame = read_csv(source_path)
        reduced = frame[row_indices, :]
        for name in names(reduced)
            lowercase(String(name)) in ("time_index", "time", "index", "hour", "datetime") &&
                (reduced[!, name] = collect(1:nrow(reduced)))
        end
        CSV.write(source_path, reduced)
    end
    by_json = Dict{String,Vector{TimeSeriesSource}}()
    for source in inline
        push!(get!(by_json, source.inline_file, TimeSeriesSource[]), source)
    end
    for (source_path, json_sources) in by_json
        data = mutable_json_data(read_json(source_path))
        for source in json_sources
            set_at_path!(data, source.inline_path, source.values[row_indices])
        end
        write_json(source_path, data)
    end
    return nothing
end

function tdr_existing_period_map(time_data::Dict{String,Any}, case_root::String)
    !haskey(time_data, "SubPeriodMap") && return nothing

    map_data = time_data["SubPeriodMap"]
    map_data isa AbstractDict && haskey(map_data, "path") ||
        throw(ArgumentError("TDR requires SubPeriodMap to contain a CSV `path`."))
    map_path = rel_or_abs_path(String(map_data["path"]), case_root)
    isfile(map_path) || throw(ArgumentError("Sub-period map file does not exist: $map_path"))
    period_map = read_csv(map_path)
    names(period_map) == ["Period_Index", "Rep_Period", "Rep_Period_Index"] ||
        throw(ArgumentError("TDR requires sub-period map columns Period_Index, Rep_Period, and Rep_Period_Index."))
    return period_map
end

function tdr_compose_period_map(
    existing_map::Union{Nothing,DataFrame},
    representative_periods::Vector{Int},
    period_map::Vector{Int},
)
    if isnothing(existing_map)
        return DataFrame(
            Period_Index=collect(eachindex(period_map)),
            Rep_Period=[representative_periods[index] for index in period_map],
            Rep_Period_Index=period_map,
        )
    end

    representative_labels = Dict{Int,Int}()
    for row in eachrow(existing_map)
        representative_index = Int(row.Rep_Period_Index)
        representative_label = Int(row.Rep_Period)
        if haskey(representative_labels, representative_index)
            representative_labels[representative_index] == representative_label ||
                throw(ArgumentError("Sub-period map assigns multiple Rep_Period values to Rep_Period_Index $representative_index."))
        else
            representative_labels[representative_index] = representative_label
        end
    end

    all(haskey(representative_labels, period) for period in representative_periods) ||
        throw(ArgumentError("Sub-period map does not identify every selected representative period."))
    all(1 <= Int(row.Rep_Period_Index) <= length(period_map) for row in eachrow(existing_map)) ||
        throw(ArgumentError("Sub-period map references a representative period outside the input horizon."))

    final_indices = [period_map[Int(row.Rep_Period_Index)] for row in eachrow(existing_map)]
    return DataFrame(
        Period_Index=Int.(existing_map.Period_Index),
        Rep_Period=[representative_labels[representative_periods[index]] for index in final_indices],
        Rep_Period_Index=final_indices,
    )
end

function tdr_write_time_data!(time_data_path::String, case_root::String, source_time_data::Dict{String,Any}, settings::TDRSettings, representative_periods::Vector{Int}, period_map::Vector{Int})
    data = deepcopy(source_time_data)
    data["NumberOfSubperiods"] = settings.representative_periods
    map_path = joinpath(dirname(time_data_path), "period_map.csv")
    data["SubPeriodMap"] = Dict("path" => replace(relpath(map_path, case_root), '\\' => '/'))
    write_json(time_data_path, data)
    existing_map = tdr_existing_period_map(source_time_data, case_root)
    map = tdr_compose_period_map(existing_map, representative_periods, period_map)
    CSV.write(map_path, map)
    return map_path, map
end
