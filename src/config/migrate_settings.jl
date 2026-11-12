"""
    migrate_settings(path::AbstractString=pwd(); dry_run::Bool=true)::OrderedDict{Symbol,Any}

Update the settings of a case written for an earlier version of Macro, where they were split
between `settings/case_settings.json` and a `settings/macro_settings.json` file referenced by the
`settings` entry of each period in `system_data.json`. `path` is the case folder or its
`system_data.json`.

All the settings are moved into the settings of the whole case, under their current names. These
are in the file named by the top-level `settings` entry of `system_data.json`, or in the entry
itself if the settings are written there, and otherwise in `settings/case_settings.json`. Only the
settings the case sets are written, so the defaults still apply to the others. The `settings`
entries of the periods are removed from `system_data.json`. The settings are read and checked as
`load_case` reads them, so settings that cannot be loaded, such as periods with different
settings, are an error here too.

By default this is a dry run: it reports the changes and writes nothing. Call it again with
`dry_run=false` to make them. Old settings files are not deleted: the report lists the ones that
are no longer used. Comments (keys starting with `#`) are not carried over, and rewriting
`system_data.json` may change its formatting.

Returns the settings of the whole case, as written or as they would be written.

# Examples
```julia
MacroEnergy.migrate_settings("path/to/case")                  # show the changes
MacroEnergy.migrate_settings("path/to/case"; dry_run=false)   # make them
```
"""
function migrate_settings(path::AbstractString=pwd(); dry_run::Bool=true)::OrderedDict{Symbol,Any}
    file = abspath(isdir(path) ? joinpath(path, "system_data.json") : path)
    isfile(file) || throw(ArgumentError("No system_data.json found at $file"))
    case_dir = dirname(file)
    root = ordered_json(read_json(file))
    has_case = haskey(root, "case")
    periods = has_case ? root["case"] : Any[root]
    # The settings of the whole case are written in the top-level entry itself, or in a file
    inline = has_case && get(root, "settings", nothing) isa AbstractDict && !haskey(root["settings"], "path")
    target = inline ? nothing : migrated_settings_file(root, has_case, case_dir)

    # Read and check the settings as `resolve_settings` does, without its deprecation warnings
    settings = with_logger(NullLogger()) do
        symbol_periods = Any[settings_dict(period) for period in periods]
        case_entry = has_case ? settings_dict(get(root, "settings", nothing)) :
            single_system_case_settings(file, only(symbol_periods))
        translated = translate_deprecated_settings(merged_settings(
            Dict{Symbol,Any}(:settings => case_entry, :case => symbol_periods), case_dir))
        check = deepcopy(translated)
        get(check, :SolutionAlgorithm, nothing) == "Benders" && load_benders_settings(check, case_dir)
        configure_settings(check)
        translated
    end

    # The settings entries of the periods, unless they point to the settings of the whole case
    removed, unused = String[], String[]
    for (index, period) in enumerate(periods)
        period isa AbstractDict || continue
        entry = get(period, "settings", nothing)
        isnothing(entry) && continue
        _, entry_file = read_settings_source(settings_dict(entry), case_dir, (LEGACY_SYSTEM_SETTINGS_FILENAME, CASE_SETTINGS_FILENAME))
        same_settings_file(entry_file, target) && continue
        delete!(period, "settings")
        push!(removed, has_case ? "case[$index].settings" : "settings")
        isnothing(entry_file) || any(file -> same_settings_file(file, entry_file), unused) || push!(unused, entry_file)
    end

    current = inline ? settings_dict(root["settings"]) :
        isfile(target) ? settings_dict(read_json(target)) : OrderedDict{Symbol,Any}()
    rewrite = !isequal(current, settings)
    if !rewrite && isempty(removed)
        @info("The settings of $case_dir are already up to date. Nothing to change.")
        return settings
    end

    # What a rewrite loses: the comments of the files and entries it replaces
    commented = filter(file_has_comments, filter(isfile, unused))
    rewrite && !inline && isfile(target) && file_has_comments(target) && pushfirst!(commented, target)
    rewrite && inline && has_comment_keys(root["settings"]) && pushfirst!(commented, file)

    if !dry_run
        if rewrite && !inline
            mkpath(dirname(target))
            write_json(target, settings)
        end
        rewrite && inline && (root["settings"] = settings)
        (isempty(removed) && !(rewrite && inline)) || write_json(file, root)
    end
    @info(migration_report(case_dir, file, target, settings, rewrite, removed, unused, commented, dry_run))
    return settings
end

# The file that holds the settings of the whole case after the migration
function migrated_settings_file(root::AbstractDict, has_case::Bool, case_dir::AbstractString)::String
    entry = has_case ? get(root, "settings", nothing) : nothing
    entry isa AbstractString && (entry = OrderedDict{String,Any}("path" => entry))
    if entry isa AbstractDict && haskey(entry, "path")
        path = normpath(abspath(settings_file_path(String(entry["path"]), case_dir)))
        return isdir(path) ? joinpath(path, CASE_SETTINGS_FILENAME) : path
    end
    return normpath(joinpath(case_dir, "settings", CASE_SETTINGS_FILENAME))
end

# What `migrate_settings` does, or would do with `dry_run=false`, and the files the user can delete
function migration_report(case_dir, file, target, settings, rewrite, removed, unused, commented, dry_run)::String
    relative(path) = relpath(path, case_dir)
    action(future, past) = dry_run ? future : past
    lines = [dry_run ? "Dry run: nothing was changed in $case_dir. With dry_run=false, migrate_settings will:" :
        "migrate_settings updated the settings of $case_dir. It:"]
    if rewrite
        destination = isnothing(target) ? "the settings entry of $(relative(file))" : relative(target)
        json = sprint(io -> JSON3.pretty(io, settings; allow_inf=true))
        push!(lines, "  - $(action("write", "wrote")) these settings to $destination:", replace(json, r"^"m => "      "))
    end
    isempty(removed) || push!(lines, "  - $(action("remove", "removed")) $(join(removed, ", ")) from $(relative(file))")
    isempty(commented) || push!(lines,
        "  - $(action("leave", "left")) out the comments (keys starting with #) in $(join(relative.(commented), ", "))")
    if !isempty(unused)
        push!(lines, "Old files are not deleted. $(dry_run ? "After the update, these" : "These") are no longer used, and you can delete them:")
        append!(lines, ["  - $(relative(path))" for path in unused])
    end
    dry_run && push!(lines, "To update the case, run MacroEnergy.migrate_settings($(repr(case_dir)); dry_run=false).")
    return join(lines, "\n")
end

# JSON read with the order of its keys, so that rewriting system_data.json keeps it
ordered_json(x::JSON3.Object) = OrderedDict{String,Any}(String(key) => ordered_json(value) for (key, value) in pairs(x))
ordered_json(x::JSON3.Array) = Any[ordered_json(value) for value in x]
ordered_json(x) = x

file_has_comments(path::AbstractString) = has_comment_keys(read_json(path))
has_comment_keys(x::AbstractDict) = any(((key, value),) -> startswith(String(key), "#") || has_comment_keys(value), pairs(x))
has_comment_keys(x::AbstractVector) = any(has_comment_keys, x)
has_comment_keys(x) = false
