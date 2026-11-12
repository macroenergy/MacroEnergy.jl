###### ###### ###### ###### ###### ###### ###### ###### ###### ###### ###### ###### ######
# Support for settings written for earlier versions: renamed settings (`DEPRECATED_SETTINGS`),
# the deprecated `SolutionAlgorithm: "Myopic"`, and settings given per period. Together with
# migrate_settings.jl, this can go when these are no longer supported.
###### ###### ###### ###### ###### ###### ###### ###### ###### ###### ###### ###### ######

"""
    translate_deprecated_settings(settings)::OrderedDict{Symbol,Any}

Return a copy of `settings` (a dictionary or `NamedTuple`) in which each renamed key is moved
to the key path that replaces it, with a deprecation warning. For example, `OutputDir` becomes
`OutputSettings.Dir`, `WriteFullTimeseries` becomes `OutputSettings.Write.FullTimeseries` and
`DualExportsEnabled` becomes `OutputSettings.Write.Duals` (see `DEPRECATED_SETTINGS`).

Setting a deprecated key and its replacement to different values is an error, unless the
deprecated key is at its default: older templates wrote every default, so such a key is ignored.
"""
function translate_deprecated_settings(settings)::OrderedDict{Symbol,Any}
    translated = drop_unset_deprecated_settings!(settings_dict(settings))
    found = [old for old in keys(DEPRECATED_SETTINGS) if haskey(translated, old)]
    isempty(found) && return translated
    for old in found
        move_setting!(translated, old, DEPRECATED_SETTINGS[old])
    end
    renames = join(["$old → $(join(DEPRECATED_SETTINGS[old], "."))" for old in found], ", ")
    @warn("""
    These settings are deprecated and were translated automatically: $renames.
    Use the new names in case_settings.json. MacroEnergy.migrate_settings("path/to/case") shows how.""", maxlog=1)
    return translated
end

# A deprecated key set to null is not set: older versions wrote that in their settings template
function drop_unset_deprecated_settings!(settings::OrderedDict{Symbol,Any})::OrderedDict{Symbol,Any}
    for old in keys(DEPRECATED_SETTINGS)
        haskey(settings, old) && isnothing(settings[old]) && delete!(settings, old)
    end
    return settings
end

function move_setting!(settings::OrderedDict{Symbol,Any}, old::Symbol, path::Tuple)
    value = pop!(settings, old)
    parent = settings
    for (depth, key) in enumerate(path[1:end-1])
        parent = get!(() -> OrderedDict{Symbol,Any}(), parent, key)
        parent isa AbstractDict || throw(InputValidationError("case_settings.$(join(path[1:depth], "."))",
            "expected an object, got $(repr(parent))"))
    end
    leaf = last(path)
    # An old name at its default says nothing next to the new name: older templates wrote every default
    haskey(parent, leaf) && isequal(settings_dict(value), settings_dict(setting_default(path))) && return nothing
    combine_setting!(parent, leaf, value, join(path, ".")) do conflict, existing, _
        throw(InputValidationError("case_settings.$old",
            "conflicts with $conflict = $(repr(existing)). $old is deprecated: remove it and keep $(join(path, "."))"))
    end
    return nothing
end

# The default of the setting at `path` in `settings_spec()`, including an entry of a per-output map
# (e.g., `(:OutputSettings, :Write, :FullTimeseries)` is `false`)
function setting_default(path::Tuple)
    spec = settings_spec()
    for key in path
        spec isa InputMap && return map_entry(spec, NamedTuple(), key)
        spec = input_spec(spec, key)
    end
    return default_value(spec)
end

function translate_deprecated_solution_algorithm!(settings::AbstractDict{Symbol,Any})
    if get(settings, :SolutionAlgorithm, nothing) == "Myopic"
        @warn("""
        Setting SolutionAlgorithm to \"Myopic\" is deprecated.
        Use ExpansionHorizon: "Myopic" combined with SolutionAlgorithm: "Monolithic" instead.
        Translating automatically: SolutionAlgorithm => Monolithic, ExpansionHorizon => Myopic.
        """)
        settings[:SolutionAlgorithm] = "Monolithic"
        settings[:ExpansionHorizon] = "Myopic"
    end
    return nothing
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
        same_as_case = isnothing(path) ? isequal(settings, case_settings) : same_settings_file(path, case_settings_path)
        if same_as_case
            push!(without, index)
        else
            push!(found, (index, settings))
        end
    end
    isempty(found) && return nothing
    @warn(string("Settings given per period (the `settings` entry of each period in system_data.json, ",
        "usually settings/macro_settings.json) are deprecated. Move them into settings/case_settings.json, ",
        "which holds the settings of the whole case. To see how, run MacroEnergy.migrate_settings($(repr(case_dir)))."), maxlog=1)
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
