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
otherwise looks for benders_settings.json in the settings directory. Handles both absolute and relative paths.
"""
function load_benders_settings(settings::AbstractDict{Symbol,Any}, path::AbstractString)::AbstractDict{Symbol,Any}
    # Try to load from specified path if provided
    if haskey(settings, :BendersSettings) && 
       isa(settings[:BendersSettings], AbstractDict) && 
       haskey(settings[:BendersSettings], :path)

        benders_path = rel_or_abs_path(settings[:BendersSettings][:path], path)
        if isfile(benders_path)
            @info("Loading Benders settings from path: $benders_path")
            settings[:BendersSettings] = read_file(benders_path)
            return settings
        end
        
        @warn("Benders settings file not found at either absolute path '$(settings[:BendersSettings][:path])' or relative path '$benders_path'")
    end

    # Otherwise, try to load from default location defined as BENDERS_SETTINGS_FILEPATH
    benders_settings = try_load_benders_settings(path)
    if !isnothing(benders_settings)
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

# The settings of a System loaded on its own (not as part of a Case): its `settings` entry, or
# else `settings/case_settings.json` next to it, or else the defaults.
function standalone_settings(system_data::AbstractDict{Symbol,Any}, data_dir::AbstractString)::NamedTuple
    source = get(system_data, :settings, nothing)
    if isnothing(source)
        implicit = joinpath(data_dir, "settings", CASE_SETTINGS_FILENAME)
        source = isfile(implicit) ? Dict{Symbol,Any}(:path => implicit) : Dict{Symbol,Any}()
    end
    raw, _ = read_settings_source(source, data_dir, LEGACY_SYSTEM_SETTINGS_FILENAME)
    return resolve_settings(Dict{Symbol,Any}(:settings => raw, :case => Any[]), data_dir)
end

# Read a settings entry of system_data.json: `{"path": ...}`, pointing to a file or to a
# directory containing `default_filename`, or the settings themselves. Return the settings and
# the absolute path of the file they were read from (`nothing` for inline settings).
function read_settings_source(source, rel_path::AbstractString, default_filename::AbstractString)
    if source isa AbstractDict && haskey(source, :path)
        path = normpath(abspath(rel_or_abs_path(String(source[:path]), String(rel_path))))
        isdir(path) && (path = joinpath(path, default_filename))
        isfile(path) || error("Settings file not found: $path")
        return settings_dict(read_file(path)), path
    end
    return settings_dict(source), nothing
end

# The settings of `case_settings.json`, plus any deprecated per-period settings
function merged_settings(case_data::AbstractDict{Symbol,Any}, case_dir::AbstractString)::OrderedDict{Symbol,Any}
    source = get(case_data, :settings, nothing)
    settings, path = isnothing(source) ? (OrderedDict{Symbol,Any}(), nothing) :
        read_settings_source(source, case_dir, CASE_SETTINGS_FILENAME)
    legacy = legacy_period_settings(case_data[:case], case_dir, path)
    isnothing(legacy) && return settings
    for (key, value) in legacy
        if haskey(settings, key) && !isequal(settings[key], value)
            throw(InputValidationError("case_settings.$key",
                "is $(repr(settings[key])) in case_settings.json but $(repr(value)) in the per-period settings"))
        end
        settings[key] = value
    end
    return settings
end

# The deprecated per-period settings of a case, or `nothing` if there are none. Every period
# must have the same settings. A period whose `settings` entry points to `case_settings_path`
# (as a single-period case may) has none.
function legacy_period_settings(periods::AbstractVector, case_dir::AbstractString,
    case_settings_path::Union{Nothing,AbstractString})::Union{Nothing,OrderedDict{Symbol,Any}}
    found = Tuple{Int,OrderedDict{Symbol,Any}}[]
    for (index, period) in enumerate(periods)
        haskey(period, :settings) || continue
        settings, path = read_settings_source(period[:settings], case_dir, LEGACY_SYSTEM_SETTINGS_FILENAME)
        !isnothing(path) && path == case_settings_path && continue
        push!(found, (index, settings))
    end
    isempty(found) && return nothing
    @warn(string("Settings given per period (the `settings` entry of each period in system_data.json, ",
        "usually settings/macro_settings.json) are deprecated. Move them into settings/case_settings.json, ",
        "which holds the settings of the whole case."), maxlog=1)
    first_index, reference = first(found)
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
