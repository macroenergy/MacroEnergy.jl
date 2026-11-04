"""
    write_settings(case::Case, filepath::AbstractString)

Write the settings of a case to a JSON file. The `Case` and every `System` in it share the same settings.

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
    write_json(filepath, OrderedDict{Symbol,Any}(pairs(case.settings)))
end