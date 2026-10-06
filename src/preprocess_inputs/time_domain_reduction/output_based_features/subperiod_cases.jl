function tdr_policy_constraint_names()
    names = Set{String}()
    function collect_names(type)
        for subtype in subtypes(type)
            push!(names, String(nameof(subtype)))
            collect_names(subtype)
        end
    end
    collect_names(PolicyConstraint)
    return names
end

function tdr_remove_policy_constraints!(value, policy_names::Set{String})
    if value isa AbstractDict
        for name in policy_names
            pop!(value, name, nothing)
        end
        foreach(nested -> tdr_remove_policy_constraints!(nested, policy_names), values(value))
    elseif value isa AbstractVector
        foreach(nested -> tdr_remove_policy_constraints!(nested, policy_names), value)
    end
    return nothing
end

function tdr_write_subperiod_time_data!(time_data_path::String, source_time_data::Dict{String,Any})
    data = deepcopy(source_time_data)
    data["NumberOfSubperiods"] = 1
    pop!(data, "SubPeriodMap", nothing)
    write_json(time_data_path, data)
    return nothing
end

function tdr_copy_subperiod_case(
    source_case_root::String,
    destination_case_root::String;
    system_index::Union{Nothing,Int}=nothing,
)
    _, systems = tdr_system_entries(source_case_root)
    index = isnothing(system_index) ? 1 : system_index
    1 <= index <= length(systems) || throw(ArgumentError(
        "System $index is outside the case's $(length(systems)) Systems.",
    ))
    length(systems) > 1 && isnothing(system_index) && throw(ArgumentError(
        "Multi-System subperiod cases require a system_index.",
    ))
    system = deepcopy(systems[index])
    manifest = tdr_system_input_manifest(source_case_root, system;
        destination_root=destination_case_root)
    additions = user_additions_path(source_case_root)
    if isdir(additions)
        tdr_collect_manifest_paths!(manifest, source_case_root, additions;
            destination_root=destination_case_root)
    end
    mkpath(destination_case_root)
    for input in sort!(collect(values(manifest)); by=input -> input.source_path)
        tdr_copy_system_input!(input)
        isfile(input.source_path) && isjson(input.source_path) || continue
        data = mutable_json_data(read_json(input.destination_path))
        tdr_rewrite_input_paths!(data, source_case_root, destination_case_root, manifest)
        write_json(input.destination_path, data)
    end
    tdr_rewrite_input_paths!(system, source_case_root, destination_case_root, manifest)
    write_json(joinpath(destination_case_root, "system_data.json"), system)
    return nothing
end

function tdr_write_single_system_case_settings!(
    source_case_root::String,
    destination_case_root::String,
    system_index::Int,
)
    root, systems = tdr_system_entries(source_case_root)
    length(systems) > 1 || return nothing
    haskey(root, "settings") && root["settings"] isa AbstractDict &&
        haskey(root["settings"], "path") || throw(ArgumentError(
            "Multi-System output-based TDR requires `settings.path` in system_data.json.",
        ))
    source_path = abspath(joinpath(source_case_root, String(root["settings"]["path"])))
    isfile(source_path) || throw(ArgumentError("Case settings file does not exist: $source_path"))
    settings = mutable_json_data(read_json(source_path))
    lengths = get(settings, "PeriodLengths", nothing)
    lengths isa AbstractVector && length(lengths) >= system_index || throw(ArgumentError(
        "Case settings `PeriodLengths` must contain a period length for System $system_index.",
    ))
    settings["PeriodLengths"] = Any[lengths[system_index]]
    settings["ExpansionHorizon"] = "PerfectForesight"
    destination_path = joinpath(destination_case_root, "settings", "case_settings.json")
    mkpath(dirname(destination_path))
    write_json(destination_path, settings)
    return nothing
end

function tdr_materialize_subperiod_case!(
    source_case_root::String,
    destination_case_root::String,
    period::Int,
    settings::TDRSettings,
    ; system_index::Union{Nothing,Int}=nothing,
)
    tdr_copy_subperiod_case(source_case_root, destination_case_root; system_index)
    if !isnothing(system_index) && length(last(tdr_system_entries(source_case_root))) > 1
        tdr_write_single_system_case_settings!(source_case_root, destination_case_root, system_index)
    end
    sources, _, full_length, time_data_path, time_data, _ = tdr_sources(destination_case_root, settings)
    period_length = settings.timesteps_per_representative_period
    n_periods = full_length ÷ period_length
    1 <= period <= n_periods || throw(ArgumentError("Subperiod $period is outside the $n_periods-period input horizon."))
    indices = collect((period - 1) * period_length + 1:period * period_length)
    tdr_write_reduced_sources!(sources, indices)
    tdr_write_subperiod_time_data!(time_data_path, time_data)
    if !settings.output_features.subperiod_runs.include_policy_constraints
        policy_names = tdr_policy_constraint_names()
        for path in tdr_input_json_files(destination_case_root)
            data = mutable_json_data(read_json(path))
            tdr_remove_policy_constraints!(data, policy_names)
            write_json(path, data)
        end
    end
    clear_csv_cache!()
    return nothing
end

function tdr_saved_subperiod_directory(
    case_root::String,
    period::Int;
    system_index::Union{Nothing,Int}=nothing,
)
    index = isnothing(system_index) ? 1 : system_index
    return joinpath(case_root, "TDR", "subperiod_solves", "system_$index",
        "subperiod_$(lpad(period, 4, '0'))")
end

function tdr_save_subperiod_inputs!(
    case_root::String,
    period::Int,
    settings::TDRSettings;
    system_index::Union{Nothing,Int}=nothing,
    artifact_root::String=case_root,
)
    destination = tdr_saved_subperiod_directory(artifact_root, period; system_index)
    ispath(destination) && rm(destination; recursive=true, force=true)
    mktempdir() do temporary_root
        temporary_case = joinpath(temporary_root, "case")
        tdr_materialize_subperiod_case!(case_root, temporary_case, period, settings; system_index)
        mkpath(dirname(destination))
        mv(temporary_case, destination)
    end
    return destination
end

function tdr_save_subperiod_results!(
    case_root::String,
    period::Int,
    outputs;
    system_index::Union{Nothing,Int}=nothing,
)
    destination = tdr_saved_subperiod_directory(case_root, period; system_index)
    mkpath(destination)
    data = Dict(
        "system_index" => system_index,
        "period" => period,
        "outputs" => Dict(
            key => [Dict(
                "feature" => Dict(
                    "provider" => feature.provider,
                    "id" => feature.id,
                    "asset" => feature.asset,
                    "commodity" => feature.commodity,
                    "weight" => feature.user_weight,
                ),
                "values" => values,
            ) for (feature, values) in matches]
            for (key, matches) in outputs
        ),
    )
    path = joinpath(destination, "results.json.gz")
    write_json(path, data, true)
    return path
end
