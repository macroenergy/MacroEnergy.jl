"""
    location_templates_by_id(document)

Validate existing location IDs and return an ID-to-entry lookup. Replace the
document's location array with a mutable vector that accepts strings and objects.
"""
function location_templates_by_id(document::AbstractDict)
    entries = get(document, :locations, nothing)
    entries isa AbstractVector || throw(ArgumentError("Location template document requires a `locations` array"))
    locations_by_id = Dict{String,Any}()
    for (index, entry) in enumerate(entries)
        location_id = parse_location_input(entry, index).id
        haskey(locations_by_id, location_id) && throw(ArgumentError("Duplicate location ID `$location_id` in template document"))
        locations_by_id[location_id] = entry
    end
    # Parsed object-only arrays cannot accept string shorthand entries.
    document[:locations] = Any[entries...]
    return locations_by_id
end

"""
    location_template_definition(entry)

Return parsed JSON for comparing definitions across file round-trips, accounting
for parsed key types and Symbol values serialized as strings.
"""
function location_template_definition(entry)
    data = entry isa AbstractString ? Dict(:id => entry) : entry
    # Compare JSON content: parsed keys are symbols, and Symbol values serialize as strings.
    return JSON3.read(JSON3.write(data; allow_inf=true); allow_inf=true)
end

"""
    add_location_template!(document, entry[, locations_by_id])

Validate and copy one location string or dictionary into the document. Preserve
existing entries for repeated names or identical definitions; reject conflicts.
Pass a shared ID lookup when adding several entries to avoid rebuilding it.
"""
function add_location_template!(document::AbstractDict, entry,
    locations_by_id::AbstractDict=location_templates_by_id(document))
    location_id = parse_location_input(entry).id
    if haskey(locations_by_id, location_id)
        existing = locations_by_id[location_id]
        name_only = entry isa AbstractString || length(entry) == 1
        name_only || isequal(location_template_definition(existing), location_template_definition(entry)) || throw(ArgumentError(
            "Location `$location_id` already exists with a different definition; edit the existing entry to change it",
        ))
        return nothing
    end
    stored = deepcopy(entry)
    push!(document[:locations], stored)
    locations_by_id[location_id] = stored
    return nothing
end

"""
    update_location_templates!(update!, loc_file, make_file)

Read or initialize a location document, call `update!(document, locations_by_id)`,
and write once after the callback returns. Require an existing file if `make_file`
is false; otherwise allow a new JSON file or directory.
"""
function update_location_templates!(update!::Function, loc_file::AbstractString, make_file::Bool)
    path = isfile(loc_file) || (!isdir(loc_file) && isjson(loc_file)) ? loc_file : joinpath(loc_file, "locations.json")
    isfile(path) || make_file || throw(ArgumentError("Location file does not exist: $path"))
    document = isfile(path) ? copy(read_json(path)) : Dict{Symbol,Any}(:locations => Any[])
    locations_by_id = location_templates_by_id(document)
    update!(document, locations_by_id)
    mkpath(dirname(path))
    write_json(path, document)
    return nothing
end

"""
    template_location(loc_file, entry; style="full", format="json", make_file=true)

Add one location name or symbol-keyed dictionary to a JSON location file.
Preserve existing definitions and extension fields; reject conflicting details
for an existing ID. A directory path selects its `locations.json` file.
"""
function template_location(loc_file::AbstractString, entry::Union{AbstractString,AbstractDict};
    style::AbstractString="full", format::AbstractString="json", make_file::Bool=true)
    return update_location_templates!(loc_file, make_file) do document, locations_by_id
        add_location_template!(document, entry, locations_by_id)
    end
end

"""
    template_location(loc_file, entries::AbstractVector; kwargs...)

Add a batch of location names and dictionaries with one file read, one shared ID
lookup, and one write. Validate all entries before writing the updated document.
"""
function template_location(loc_file::AbstractString, entries::AbstractVector;
    style::AbstractString="full", format::AbstractString="json", make_file::Bool=true)
    return update_location_templates!(loc_file, make_file) do document, locations_by_id
        for entry in entries
            add_location_template!(document, entry, locations_by_id)
        end
    end
end

"""
    template_location(system::AbstractSystem, entries; kwargs...)

Add one location or a batch to the location file configured in the System's
`system_data.json`. Forward keyword arguments to the file overload.
"""
function template_location(system::AbstractSystem, entries; kwargs...)
    system_data = load_system_data(joinpath(system.data_dirpath, "system_data.json"); lazy_load=true)
    loc_file = joinpath(system.data_dirpath, system_data[:locations][:path])
    return template_location(loc_file, entries; kwargs...)
end
