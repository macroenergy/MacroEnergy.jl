# Constants for file paths
const BENDERS_SETTINGS_FILEPATH = "settings/benders_settings.json"

"""
    try_load_benders_settings(path::AbstractString)::Union{AbstractDict{Symbol,Any}, Nothing}

Attempts to load Benders settings from the given path. Returns the settings if found, nothing otherwise.
"""
function try_load_benders_settings(path::AbstractString)::Union{AbstractDict{Symbol,Any}, Nothing}
    benders_path = joinpath(path, BENDERS_SETTINGS_FILEPATH)
    if isfile(benders_path)
        @debug("Loading Benders settings from default location: $benders_path")
        return read_file(benders_path)
    end
    return nothing
end

"""
    load_benders_settings(settings::AbstractDict{Symbol,Any}, path::AbstractString)::AbstractDict{Symbol,Any}

Load Benders settings from a file. First checks if a specific path is provided in the settings,
otherwise looks for benders_settings.json in the settings directory, which takes priority over
settings written directly in `BendersSettings`, with a warning. Handles both absolute and relative
paths. A path to a missing file is an error unless benders_settings.json exists.
"""
function load_benders_settings(settings::AbstractDict{Symbol,Any}, path::AbstractString)::AbstractDict{Symbol,Any}
    # Try to load from specified path if provided
    if haskey(settings, :BendersSettings) && 
       isa(settings[:BendersSettings], AbstractDict) && 
       haskey(settings[:BendersSettings], :path)

        benders_path = settings_file_path(settings[:BendersSettings][:path], path)
        if isfile(benders_path)
            @info("Loading Benders settings from path: $benders_path")
            settings[:BendersSettings] = read_file(benders_path)
            return settings
        end
        
        @warn("Benders settings file not found at either absolute path '$(settings[:BendersSettings][:path])' or relative path '$benders_path'")
        isnothing(try_load_benders_settings(path)) && throw(InputValidationError("case_settings.BendersSettings.path",
            "file not found: $benders_path"))
        delete!(settings, :BendersSettings)
    end

    # Otherwise, try to load from default location defined as BENDERS_SETTINGS_FILEPATH
    benders_settings = try_load_benders_settings(path)
    if !isnothing(benders_settings)
        written = settings_dict(something(get(settings, :BendersSettings, nothing), Dict{Symbol,Any}()))
        # Compared with the defaults filled in: results/settings.json writes all of them
        spec = benders_settings_spec()
        if !isempty(written) && !isequal(merge_defaults(spec, written), merge_defaults(spec, settings_dict(benders_settings)))
            @warn("$BENDERS_SETTINGS_FILEPATH takes priority over the BendersSettings in case_settings.json, which are ignored.")
        end
        settings[:BendersSettings] = benders_settings
    end

    return settings
end

"""
    resolve_settings(case_data::AbstractDict{Symbol,Any}, case_dir::AbstractString)::NamedTuple

Read the settings of a case and return them as one `NamedTuple`, shared by the `Case` and by
every `System` in it.

All settings are read from `case_data[:settings]`, usually `settings/case_settings.json`.
Settings given per period (the `settings` entry of each period, usually
`settings/macro_settings.json`) are deprecated: they are still read, with a warning, but they
must be the same for every period and must not contradict `case_settings.json`.
Deprecated keys are translated (see `translate_deprecated_settings`) and unknown keys are an error.
"""
function resolve_settings(case_data::AbstractDict{Symbol,Any}, case_dir::AbstractString)::NamedTuple
    @info("Configuring settings")
    raw = merged_settings(case_data, case_dir)
    if get(raw, :SolutionAlgorithm, nothing) == "Benders"
        load_benders_settings(raw, case_dir)
    end
    settings = configure_settings(raw)
    @info(" -- Solution algorithm set to $(settings[:SolutionAlgorithm])")
    @info(" -- Expansion horizon set to $(settings[:ExpansionHorizon])")
    return settings
end

# The settings of a System loaded on its own (not as part of a Case): the same ones `load_case`
# would use for a single-period case in this folder.
function standalone_settings(system_data::AbstractDict{Symbol,Any}, data_dir::AbstractString)::NamedTuple
    return resolve_settings(Dict{Symbol,Any}(
        :settings => single_system_case_settings(joinpath(data_dir, "system_data.json"), system_data),
        :case => Any[system_data],
    ), data_dir)
end

# Read a settings entry of system_data.json: a path, or `{"path": ...}`, to a file or to a directory
# containing one of `filenames` (the first that exists), or the settings themselves. Return the
# settings and the absolute path of the file they were read from (`nothing` for inline settings).
function read_settings_source(source, rel_path::AbstractString, filenames::Tuple)
    source isa AbstractString && (source = Dict{Symbol,Any}(:path => source))
    source isa AbstractDict || throw(InputValidationError("system_data.settings",
        "expected a path or an object, got $(repr(source))"))
    haskey(source, :path) || return drop_unset_deprecated_settings!(settings_dict(source)), nothing
    path = normpath(abspath(settings_file_path(source[:path], rel_path)))
    if isdir(path)
        candidates = [joinpath(path, filename) for filename in filenames]
        index = findfirst(isfile, candidates)
        path = isnothing(index) ? first(candidates) : candidates[index]
    end
    isfile(path) || error("Settings file not found: $path")
    return drop_unset_deprecated_settings!(settings_dict(read_file(path))), path
end

# Settings paths are relative to the location of system_data.json, not to the current directory
function settings_file_path(path::AbstractString, rel_path::AbstractString)::String
    from_case = joinpath(rel_path, path)
    return ispath(from_case) ? from_case : String(path)
end

# The settings of `case_settings.json`, plus any deprecated per-period settings. A case without a
# top-level `settings` entry uses the conventional file, if there is one.
function merged_settings(case_data::AbstractDict{Symbol,Any}, case_dir::AbstractString)::OrderedDict{Symbol,Any}
    source = get(case_data, :settings, nothing)
    if isnothing(source)
        implicit = joinpath(case_dir, "settings", CASE_SETTINGS_FILENAME)
        source = isfile(implicit) ? Dict{Symbol,Any}(:path => implicit) : Dict{Symbol,Any}()
    end
    settings, path = read_settings_source(source, case_dir, (CASE_SETTINGS_FILENAME, LEGACY_SYSTEM_SETTINGS_FILENAME))
    legacy = legacy_period_settings(case_data[:case], case_dir, settings, path)
    isnothing(legacy) && return settings
    for (key, value) in legacy
        combine_setting!(settings, key, value, "case_settings.$key") do conflict, existing, period_value
            throw(InputValidationError(conflict,
                "is $(repr(existing)) in case_settings.json but $(repr(period_value)) in the per-period settings"))
        end
    end
    return settings
end

# The deprecated per-period settings of a case, or `nothing` if there are none. A period whose
# `settings` entry is the case settings themselves (the same file or, for the inline settings that
# eager loading produces, the same content) has no settings of its own. Every period must have
# the same settings, so one period having some and another having none is an error.
function legacy_period_settings(periods::AbstractVector, case_dir::AbstractString,
    case_settings::AbstractDict, case_settings_path::Union{Nothing,AbstractString}
)::Union{Nothing,OrderedDict{Symbol,Any}}
    found = Tuple{Int,OrderedDict{Symbol,Any}}[]
    without = Int[]
    for (index, period) in enumerate(periods)
        if isnothing(get(period, :settings, nothing))
            push!(without, index)
            continue
        end
        settings, path = read_settings_source(period[:settings], case_dir, (LEGACY_SYSTEM_SETTINGS_FILENAME, CASE_SETTINGS_FILENAME))
        same_as_case = isnothing(path) ? isequal(settings, case_settings) : path == case_settings_path
        if same_as_case
            push!(without, index)
        else
            push!(found, (index, settings))
        end
    end
    isempty(found) && return nothing
    @warn(string("Settings given per period (the `settings` entry of each period in system_data.json, ",
        "usually settings/macro_settings.json) are deprecated. Move them into settings/case_settings.json, ",
        "which holds the settings of the whole case."), maxlog=1)
    first_index, reference = first(found)
    isempty(without) || throw(InputValidationError("system_data.case[$(first(without))].settings",
        "this period has no settings of its own, but period $first_index does. Every period now uses " *
        "the same settings: move them into case_settings.json"))
    for (index, settings) in found[2:end]
        isequal(settings, reference) && continue
        differing = sort!([key for key in union(keys(settings), keys(reference))
            if !isequal(get(settings, key, nothing), get(reference, key, nothing))])
        throw(InputValidationError("system_data.case[$index].settings",
            "differs from period $first_index in $(join(differing, ", ")). Every period now uses " *
            "the same settings: move them into case_settings.json"))
    end
    return reference
end
