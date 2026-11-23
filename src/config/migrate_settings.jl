# The Benders and Myopic settings are shown whole: migrate_settings does not change them
const WHOLE_SETTINGS = (:BendersSettings, :MyopicSettings)
# Where the report sends the user for the settings it does not list. Julia, not the docs: it always
# matches the installed version.
const DEFAULTS_HINT = "To see the defaults, run MacroEnergy.default_settings()."

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
settings, are an error here too. Only files inside the case folder are changed: if the settings
of the whole case are in a file outside it, which other cases may use too, this is an error.

By default this is a dry run: it reports the changes and writes nothing. Call it again with
`dry_run=false` to make them. The report lists each setting that is not at its default, before
and after the update: the file it is in, its name there and its value, with the values that
change first. After a real update, the settings are read back from the files for this list. Old
settings files are not deleted: the report lists the ones that are no longer used. Comments
(keys starting with `#`) are not carried over, and rewriting `system_data.json` may change its
formatting.

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

    settings, before = read_case_settings(root, file)

    # The settings entries of the periods, unless they point to the settings of the whole case
    removed, unused = String[], String[]
    for (index, period) in enumerate(periods)
        period isa AbstractDict || continue
        entry = get(period, "settings", nothing)
        isnothing(entry) && continue
        entry_file = settings_source_file(settings_dict(entry), case_dir, PERIOD_ENTRY_FILENAMES)
        same_settings_file(entry_file, target) && continue
        delete!(period, "settings")
        push!(removed, has_case ? "case[$index].settings" : "settings")
        isnothing(entry_file) || any(file -> same_settings_file(file, entry_file), unused) || push!(unused, entry_file)
    end

    current = inline ? settings_dict(root["settings"]) :
        isfile(target) ? settings_dict(read_json(target)) : OrderedDict{Symbol,Any}()
    rewrite = !isequal(current, settings)
    # Other cases may use a settings file outside the case: merging this case's per-period
    # settings into it would change their settings too
    if rewrite && !inline && !is_within(target, case_dir)
        throw(ArgumentError("""
            The settings of the whole case $case_dir are in $target, which is outside the case. \
            migrate_settings only changes files inside the case, because other cases may use that file too. \
            Copy it into the case, for example to settings/$CASE_SETTINGS_FILENAME, point the top-level \
            `settings` entry of system_data.json to the copy, and run migrate_settings again."""))
    end
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
    # After the update: the settings as they will be written, or as read back from the files
    after = if dry_run
        destination = inline ? "$(report_path(file, case_dir)) (settings)" : report_path(target, case_dir)
        settings_reading(settings, [(destination, settings)])
    else
        last(read_case_settings(ordered_json(read_json(file)), file))
    end
    comparison = settings_comparison(before, after, dry_run)
    @info(migration_report(case_dir, file, target, settings, rewrite, removed, unused, commented, comparison, dry_run))
    return settings
end

# Read and check the settings of a case as `load_case` does, without its deprecation warnings.
# `root` is the case's system_data.json, at `file`. Return the settings of the whole case, under
# their current names, and where each comes from (see `settings_reading`).
function read_case_settings(root::AbstractDict, file::AbstractString)
    case_dir = dirname(file)
    has_case = haskey(root, "case")
    periods = Any[settings_dict(period) for period in (has_case ? root["case"] : Any[root])]
    case_entry = has_case ? settings_dict(get(root, "settings", nothing)) : single_system_case_settings(file, only(periods))
    case_data = Dict{Symbol,Any}(:settings => case_entry, :case => periods)
    return with_logger(NullLogger()) do
        translated = translate_deprecated_settings(merged_settings(case_data, case_dir))
        translate_deprecated_solution_algorithm!(translated)
        check = deepcopy(translated)
        get(check, :SolutionAlgorithm, nothing) == "Benders" && load_benders_settings(check, case_dir)
        configure_settings(check; num_periods=length(periods))
        translated, settings_reading(translated, settings_sources(case_data, file, has_case))
    end
end

# The settings files and entries of a case, as `merged_settings` reads them: the settings of the
# whole case, then the per-period settings, if any. Each comes with the name the report shows.
function settings_sources(case_data::AbstractDict{Symbol,Any}, file::AbstractString, has_case::Bool)
    case_dir = dirname(file)
    name(path, entry) = isnothing(path) ? "$(report_path(file, case_dir)) ($entry)" : report_path(path, case_dir)
    case_settings, case_path = read_settings_source(case_settings_entry(case_data, case_dir), case_dir, CASE_ENTRY_FILENAMES)
    sources = [(name(case_path, "settings"), case_settings)]
    legacy = legacy_period_settings(case_data[:case], case_dir, case_settings, case_path)
    if !isnothing(legacy)
        # Every period has the same settings (or reading them is an error): the first one names them
        path = settings_source_file(first(case_data[:case])[:settings], case_dir, PERIOD_ENTRY_FILENAMES)
        push!(sources, (name(path, has_case ? "case[1].settings" : "settings"), legacy))
    end
    return sources
end

# The settings of a case as key paths, e.g. `(:OutputSettings, :Layout, :Flow) => "wide"`
# (`values`), and where each comes from (`origins`): the file or entry, the key as it is written
# there, and the value. `settings` are under their current names, and `sources` (see
# `settings_sources`) are as written.
function settings_reading(settings::AbstractDict, sources::AbstractVector)
    origins = Dict{Tuple,Tuple{String,String,Any}}()
    for (source, raw) in sources
        add_origins!(origins, raw, source)
    end
    return (; values=flat_settings(settings), origins)
end

function flat_settings(settings::AbstractDict, prefix::Tuple=())::OrderedDict{Tuple,Any}
    flat = OrderedDict{Tuple,Any}()
    for (key, value) in settings
        path = (prefix..., Symbol(key))
        value isa AbstractDict && !(first(path) in WHOLE_SETTINGS) ? merge!(flat, flat_settings(value, path)) :
            (flat[path] = value)
    end
    return flat
end

# Add where each setting of `raw` comes from, under its current name. A setting keeps its first
# source, as in `merged_settings`. New names come before old ones: next to an old name at its
# default (older templates wrote every default), the new name is the one that counts.
function add_origins!(origins::AbstractDict, raw::AbstractDict, source::AbstractString, new::Tuple=(), old::Tuple=())
    renamed(key) = isempty(new) && haskey(DEPRECATED_SETTINGS, Symbol(key))
    for key in [filter(!renamed, collect(keys(raw))); filter(renamed, collect(keys(raw)))]
        value = raw[key]
        new_path = renamed(key) ? DEPRECATED_SETTINGS[Symbol(key)] : (new..., Symbol(key))
        old_path = (old..., Symbol(key))
        if value isa AbstractDict && !(first(new_path) in WHOLE_SETTINGS)
            add_origins!(origins, value, source, new_path, old_path)
            continue
        end
        get!(origins, new_path, (source, join(old_path, "."), value))
        # The deprecated `SolutionAlgorithm: "Myopic"` sets the expansion horizon
        new_path == (:SolutionAlgorithm,) && isequal(value, "Myopic") &&
            get!(origins, (:ExpansionHorizon,), (source, join(old_path, "."), value))
    end
    return origins
end

# Whether two values of a setting are the same. As in JSON, 0 and 0.0 are the same number.
same_setting(a, b) = isequal(a, b) || isequal(a == b, true)

# The settings that are not at their default, before or after the update: where each comes from,
# under which name, and its value. Changed values come first.
function settings_comparison(before, after, dry_run::Bool)::Vector{String}
    effective(reading, path) = get(() -> setting_default(path), reading.values, path)
    at_default(reading, path) = same_setting(effective(reading, path), setting_default(path))
    paths = unique([collect(keys(after.values)); collect(keys(before.values))])
    filter!(path -> !at_default(before, path) || !at_default(after, path), paths)
    isempty(paths) && return ["Every setting is at its default, before and after the update. $DEFAULTS_HINT"]

    changed = filter(path -> !same_setting(effective(before, path), effective(after, path)), paths)
    kept = setdiff(paths, changed)

    # One row per setting, under its current name. After the update the settings are normally all in
    # one file, under their current names: the columns for the file and the name after the update
    # appear only when some setting is elsewhere or under another name.
    name(path) = join(path, ".")
    origin(reading, path) = get(reading.origins, path, ("(default)", name(path), effective(reading, path)))
    after_sources = unique(first(origin(after, path)) for path in paths)
    after_file = length(after_sources) > 1 || only(after_sources) == "(default)"
    after_name = any(path -> origin(after, path)[2] != name(path), paths)
    text(value) = JSON3.write(value; allow_inf=true)
    header = ["Setting", "Before: file", "Before: name", "Before"]
    after_file && push!(header, "After: file")
    after_name && push!(header, "After: name")
    push!(header, "After")
    function cells(path)
        (source, key, value), (after_source, after_key, after_value) = origin(before, path), origin(after, path)
        row = [name(path), source, key, text(value)]
        after_file && push!(row, after_source)
        after_name && push!(row, after_key)
        return push!(row, text(after_value))
    end
    rows = Dict(path => cells(path) for path in paths)
    widths = [maximum(textwidth, [header[column]; [rows[path][column] for path in paths]]) for column in eachindex(header)]
    table(group) = box_table(header, [rows[path] for path in group], widths)

    intro = dry_run ? "The settings that are not at their default, now and as they will be after the update." :
        "The settings that are not at their default, before the update and as read back from the files after it."
    after_file || (intro *= " After it, they $(dry_run ? "will all be" : "are all") in $(only(after_sources)).")
    lines = [intro]
    if isempty(changed)
        append!(lines, table(paths))
        push!(lines, "All of them keep their values.")
    else
        push!(lines, "These $(dry_run ? "will change" : "changed"):")
        append!(lines, table(changed))
        isempty(kept) || push!(lines, "These keep their values:")
        isempty(kept) || append!(lines, table(kept))
    end
    push!(lines, "Settings that are not listed are at their default. $DEFAULTS_HINT")
    return lines
end

# A table drawn with box-drawing characters, with the given column widths
function box_table(header::Vector{String}, rows::Vector{Vector{String}}, widths::Vector{Int})::Vector{String}
    rule(left, middle, right) = left * join(("─"^(width + 2) for width in widths), middle) * right
    cells(values) = "│" * join((" " * rpad(value, width) * " " for (value, width) in zip(values, widths)), "│") * "│"
    return [rule("┌", "┬", "┐"); cells(header); rule("├", "┼", "┤"); cells.(rows); rule("└", "┴", "┘")]
end

# Files inside the case relative to it, and others in full, so that they stand out. Written with
# `/` on every OS, as in system_data.json and the docs, so that the report reads the same everywhere.
function report_path(path::AbstractString, case_dir::AbstractString)::String
    shown = is_within(String(path), String(case_dir)) ? relpath(path, case_dir) : String(path)
    return Sys.iswindows() ? replace(shown, '\\' => '/') : shown
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
function migration_report(case_dir, file, target, settings, rewrite, removed, unused, commented, comparison, dry_run)::String
    relative(path) = report_path(path, case_dir)
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
    append!(lines, comparison)
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
