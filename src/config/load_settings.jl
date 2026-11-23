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

Load the Benders settings of a case into `settings[:BendersSettings]` and return `settings`.

The `BendersSettings` of case_settings.json take priority. They are given either inline or as
`{"path": ...}`, naming a file (absolute, or relative to the case) that is read here.
settings/benders_settings.json is used only if case_settings.json has no `BendersSettings`, or
an empty one. If both are given, benders_settings.json is ignored, with a warning if the two
differ. If `BendersSettings.path` names a missing file, that is an error, unless
benders_settings.json exists: then it is used instead, with a warning.
"""
function load_benders_settings(settings::AbstractDict{Symbol,Any}, path::AbstractString)::AbstractDict{Symbol,Any}
    case_benders = get(settings, :BendersSettings, nothing)
    if case_benders isa AbstractDict && haskey(case_benders, :path)
        benders_path = settings_file_path(case_benders[:path], path)
        if isfile(benders_path)
            @info("Loading Benders settings from path: $benders_path")
            case_benders = settings[:BendersSettings] = read_file(benders_path)
        else
            @warn("Benders settings file not found: $benders_path")
            isnothing(try_load_benders_settings(path)) && throw(InputValidationError("case_settings.BendersSettings.path",
                "file not found: $benders_path"))
            case_benders = nothing
        end
    end

    default_benders = try_load_benders_settings(path)
    isnothing(default_benders) && return settings
    if isnothing(case_benders) || (case_benders isa AbstractDict && isempty(case_benders))
        settings[:BendersSettings] = default_benders
        return settings
    end
    # A value that is not an object is reported when the settings are checked
    case_benders isa AbstractDict || return settings
    # Compared with the defaults filled in: results/settings.json writes all of them
    spec = benders_settings_spec()
    if !isequal(merge_defaults(spec, settings_dict(case_benders)), merge_defaults(spec, settings_dict(default_benders)))
        @warn("The BendersSettings of case_settings.json take priority over $BENDERS_SETTINGS_FILEPATH, which is ignored.")
    end
    return settings
end

"""
    resolve_settings(case_data::AbstractDict{Symbol,Any}, case_dir::AbstractString; num_periods=nothing)::NamedTuple

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

# The file a settings entry of system_data.json names, as an absolute path: the entry is a path, or
# `{"path": ...}`, to a file or to a directory containing one of `filenames` (the first that
# exists). `nothing` if the entry holds the settings themselves. Everything that compares settings
# files (the loader, `migrate_settings`, TDR) finds them here, so that they agree on which file
# a directory entry names.
function settings_source_file(source, rel_path::AbstractString, filenames::Tuple)::Union{Nothing,String}
    source isa AbstractString && (source = Dict{Symbol,Any}(:path => source))
    source isa AbstractDict || throw(InputValidationError("system_data.settings",
        "expected a path or an object, got $(repr(source))"))
    haskey(source, :path) || return nothing
    path = normpath(abspath(settings_file_path(source[:path], rel_path)))
    isdir(path) || return path
    candidates = [joinpath(path, filename) for filename in filenames]
    index = findfirst(isfile, candidates)
    return isnothing(index) ? first(candidates) : candidates[index]
end

# Read a settings entry of system_data.json (see `settings_source_file`). Return the settings and
# the absolute path of the file they were read from (`nothing` for inline settings).
function read_settings_source(source, rel_path::AbstractString, filenames::Tuple)
    path = settings_source_file(source, rel_path, filenames)
    isnothing(path) && return drop_unset_deprecated_settings!(settings_dict(source)), nothing
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

# The top-level `settings` entry of a case. A case without one uses the conventional file, if
# there is one.
function case_settings_entry(case_data::AbstractDict{Symbol,Any}, case_dir::AbstractString)
    source = get(case_data, :settings, nothing)
    isnothing(source) || return source
    # Absolute: the path already includes the case folder, which must not be joined to it again
    implicit = abspath(case_dir, "settings", CASE_SETTINGS_FILENAME)
    return isfile(implicit) ? Dict{Symbol,Any}(:path => implicit) : Dict{Symbol,Any}()
end

# The settings of `case_settings.json`, plus any deprecated per-period settings
function merged_settings(case_data::AbstractDict{Symbol,Any}, case_dir::AbstractString)::OrderedDict{Symbol,Any}
    settings, path = read_settings_source(case_settings_entry(case_data, case_dir), case_dir, CASE_ENTRY_FILENAMES)
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
