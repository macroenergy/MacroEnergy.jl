"""
    write_settings(case::Case, filepath::AbstractString)

Write the case and system settings to a JSON file.

This function extracts the settings from a Case object and writes them to a JSON file.
The settings include both case-level settings and system-level settings for all systems
in the case.

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

# Output Format
The JSON file will contain:
- `case_settings`: The case-level settings
- `system_settings`: An array of settings for each system in the case
"""
function write_settings(case::Case, filepath::AbstractString)
    settings = Dict{Symbol, Any}(
        :case_settings => case.settings,
        :system_settings => [system.settings for system in case.systems]
    )
    write_json(filepath, settings)
end