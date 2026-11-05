"""
    write_settings(case::Case, filepath::AbstractString)

Write the settings of a case to a JSON file. The `Case` and every `System` in it share the same settings.

The file has the same form as `case_settings.json`, so it can be read back to rerun a case with
the same settings: optional settings that were not set are left out, and the solution algorithm
and expansion horizon are written by name.

# Arguments
- `case::Case`: The case object containing the settings to write
- `filepath::AbstractString`: The full path to the output JSON file

# Returns
- `nothing`: The function returns nothing, but writes the settings to the specified file

# Example
```julia
# Write settings to a JSON file
write_settings(case, "output/settings.json")

# Write settings to a case results directory
write_settings(case, joinpath(case_path, "settings.json"))
```

"""
function write_settings(case::Case, filepath::AbstractString)
    write_json(filepath, settings_to_json(case.settings))
end

# The settings in the form the loader reads back. This is the only place that turns settings into
# JSON, so that the writers cannot disagree with each other or with `configure_settings`.
function settings_to_json(settings::NamedTuple)::OrderedDict{Symbol,Any}
    return OrderedDict{Symbol,Any}(key => setting_to_json(value) for (key, value) in pairs(settings)
        if !ismissing(value) && !isnothing(value))
end

setting_to_json(value) = value
setting_to_json(value::Union{AbstractSolutionAlgorithm,AbstractExpansionHorizon}) = String(nameof(typeof(value)))