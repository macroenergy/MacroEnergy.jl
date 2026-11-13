###### ###### ###### ###### ###### ###### ###### ###### ###### ###### ###### ###### ######
# Where the settings of a case come from: the `settings` entries of `system_data.json`, the
# files they name, and the files found by their conventional names. `configure_settings`
# (configure_settings.jl) turns the settings read here into the settings of the case.
###### ###### ###### ###### ###### ###### ###### ###### ###### ###### ###### ###### ######

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
        
        @warn("Benders settings file not found: $benders_path")
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

# The case-level settings of a case written without a `case` key: the conventional file if there
# is one, and otherwise the System's own `settings` entry. If the System's entry points elsewhere
# while the conventional file exists, this is the deprecated two-file layout, and
# `merged_settings` reads both.
function single_system_case_settings(file_path::AbstractString, system_data::AbstractDict=Dict{Symbol,Any}())
    # Absolute: the path already includes the case folder, which must not be joined to it again
    case_settings_path = abspath(dirname(file_path), "settings", CASE_SETTINGS_FILENAME)
    if isfile(case_settings_path)
        return Dict{Symbol,Any}(:path => case_settings_path)
    end
    return get(system_data, :settings, Dict{Symbol,Any}())
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

# Whether two settings paths name the same existing file. Comparing the strings is not enough:
# file names are case-insensitive on Windows and, by default, on macOS.
same_settings_file(a, b) = !isnothing(a) && !isnothing(b) && samefile(a, b)

# Settings paths are relative to the location of system_data.json, never to the current directory:
# a file missing from the case must not be replaced by another case's file at the same relative
# path. An absolute path is kept as it is. A path found by its conventional name already includes
# the case folder, so it is made absolute where it is found.
settings_file_path(path::AbstractString, rel_path::AbstractString)::String = joinpath(rel_path, path)

# The settings of `case_settings.json`, plus any deprecated per-period settings. A case without a
# top-level `settings` entry uses the conventional file, if there is one.
function merged_settings(case_data::AbstractDict{Symbol,Any}, case_dir::AbstractString)::OrderedDict{Symbol,Any}
    source = get(case_data, :settings, nothing)
    if isnothing(source)
        # Absolute: the path already includes the case folder, which must not be joined to it again
        implicit = abspath(case_dir, "settings", CASE_SETTINGS_FILENAME)
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
