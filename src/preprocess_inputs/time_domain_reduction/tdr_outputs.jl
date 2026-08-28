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

function tdr_write_time_data!(time_data_path::String, case_root::String, source_time_data::Dict{String,Any}, settings::TDRSettings, representative_periods::Vector{Int}, period_map::Vector{Int})
    data = deepcopy(source_time_data)
    data["NumberOfSubperiods"] = settings.representative_periods
    map_path = joinpath(dirname(time_data_path), "period_map.csv")
    data["SubPeriodMap"] = Dict("path" => replace(relpath(map_path, case_root), '\\' => '/'))
    write_json(time_data_path, data)
    map = DataFrame(
        Period_Index=collect(eachindex(period_map)),
        Rep_Period=[representative_periods[index] for index in period_map],
        Rep_Period_Index=period_map,
    )
    CSV.write(map_path, map)
    return map_path
end
