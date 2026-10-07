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

function tdr_write_subperiod_time_data!(time_data_path::String, source_time_data::Dict{String,Any}, period_length::Int)
    data = tdr_reduced_time_data(source_time_data, period_length, 1)
    write_json(time_data_path, data)
    return nothing
end

"""Prepare the reusable dependency snapshot for isolated candidate solves."""
function tdr_prepare_subperiod_inputs(inputs)
    manifest = copy(inputs.manifest)
    additions = user_additions_path(inputs.source_root)
    if isdir(additions)
        tdr_collect_manifest_paths!(manifest, inputs.source_root, additions;
            destination_root=inputs.source_root)
    end
    json_data = copy(inputs.json_data)
    for path in keys(manifest)
        isfile(path) && isjson(path) && !haskey(json_data, path) || continue
        json_data[path] = mutable_json_data(read_json(path))
    end
    return merge(inputs, (; manifest, json_data))
end

function tdr_read_case_settings(case_root::String, root)
    source_settings = haskey(root, "case") ? get(root, "settings", default_case_settings()) :
        single_system_case_settings(joinpath(case_root, "system_data.json"))
    settings = Dict{String,Any}(String(key) => value for (key, value) in source_settings)
    if haskey(settings, "path")
        source_path = abspath(joinpath(case_root, String(settings["path"])))
        isfile(source_path) || throw(ArgumentError("Case settings file does not exist: $source_path"))
        settings = mutable_json_data(read_json(source_path))
    end
    return settings
end

function tdr_single_system_case_settings(source_settings, system_index::Int)
    settings = deepcopy(source_settings)
    defaults = Dict{String,Any}(String(key) => value for (key, value) in default_case_settings())
    lengths = get(settings, "PeriodLengths", defaults["PeriodLengths"])
    lengths isa AbstractVector && length(lengths) >= system_index || throw(ArgumentError(
        "Case settings `PeriodLengths` must contain a period length for System $system_index.",
    ))
    settings["PeriodLengths"] = Any[lengths[system_index]]
    settings["ExpansionHorizon"] = "PerfectForesight"
    settings["SolutionAlgorithm"] = get(settings, "SolutionAlgorithm", defaults["SolutionAlgorithm"])
    # Omit defaults so the loader restores their original Julia types.
    filter!(settings) do entry
        key, value = entry
        !ismissing(value) && (key in ("PeriodLengths", "ExpansionHorizon", "SolutionAlgorithm") ||
            !haskey(defaults, key) || !isequal(value, defaults[key]))
    end
    return settings
end

function tdr_copy_subperiod_case(inputs, destination_case_root::String)
    relocated = tdr_relocate_inputs(inputs, destination_case_root)
    mkpath(destination_case_root)
    for input in sort!(collect(values(inputs.manifest)); by=input -> input.source_path)
        isfile(input.source_path) && isjson(input.source_path) && continue
        destination = joinpath(destination_case_root, relpath(input.source_path, inputs.source_root))
        tdr_copy_system_input!(TDRTrackedInput(input.source_path, destination, input.columns))
    end
    for (path, data) in relocated.json_data
        mkpath(dirname(path))
        write_json(path, data)
    end
    write_json(joinpath(destination_case_root, "system_data.json"), relocated.system)
    destination_path = joinpath(destination_case_root, "settings", "case_settings.json")
    mkpath(dirname(destination_path))
    write_json(destination_path, inputs.case_settings)
    return relocated
end

function tdr_materialize_subperiod_case!(inputs, destination_case_root::String,
    period::Int, settings::TDRSettings)
    relocated = tdr_copy_subperiod_case(inputs, destination_case_root)
    indices = collect(inputs.candidates.ranges[period])
    tdr_write_reduced_sources!(relocated.sources, indices)
    tdr_write_subperiod_time_data!(relocated.time_data_path, inputs.time_data, inputs.candidates.period_length)
    if !settings.output_features.subperiod_runs.include_policy_constraints
        policy_names = tdr_policy_constraint_names()
        for path in union(collect(keys(relocated.json_data)), [joinpath(destination_case_root, "system_data.json")])
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
    inputs,
    period::Int,
    settings::TDRSettings;
    artifact_root::String=inputs.source_root,
)
    destination = tdr_saved_subperiod_directory(artifact_root, period; system_index=inputs.system_index)
    ispath(destination) && rm(destination; recursive=true, force=true)
    mktempdir() do temporary_root
        temporary_case = joinpath(temporary_root, "case")
        tdr_materialize_subperiod_case!(inputs, temporary_case, period, settings)
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
