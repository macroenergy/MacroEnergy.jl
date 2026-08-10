const REPO_ROOT = normpath(joinpath(@__DIR__, "..", ".."))
const CHANGELOG_PATH = joinpath(REPO_ROOT, "CHANGELOG.md")
const README_PATH = joinpath(REPO_ROOT, "README.md")
const DOCS_INDEX_PATH = joinpath(REPO_ROOT, "docs", "src", "index.md")
const DOCS_CHANGELOG_PATH = joinpath(REPO_ROOT, "docs", "src", "changelog.md")

const GENERATED_BEGIN = "<!-- BEGIN GENERATED RECENT CHANGES -->"
const GENERATED_END = "<!-- END GENERATED RECENT CHANGES -->"
const GENERATED_NOTICE = "<!-- This file is generated from CHANGELOG.md by docs/scripts/update_changelog.jl. -->"

function heading_level(line::AbstractString)
    startswith(line, "#") || return 0
    count = 0
    for char in line
        char == '#' || break
        count += 1
    end
    return count
end

function section_bounds(lines::Vector{<:AbstractString}, heading::String)
    start = findfirst(==(heading), lines)
    isnothing(start) && return nothing

    level = heading_level(heading)
    stop = length(lines) + 1
    for index in (start + 1):length(lines)
        current_level = heading_level(lines[index])
        if current_level > 0 && current_level <= level
            stop = index
            break
        end
    end
    return start, stop
end

function replace_or_insert_section(content::String, section_heading::String, section_body::String, after_heading::String)
    lines = split(chomp(content), "\n"; keepempty=true)
    new_section = split(chomp(section_heading * "\n\n" * section_body) * "\n", "\n"; keepempty=true)

    existing_bounds = section_bounds(lines, section_heading)
    if !isnothing(existing_bounds)
        start, stop = existing_bounds
        splice!(lines, start:(stop - 1), new_section)
        return join(lines, "\n") * "\n"
    end

    after_bounds = section_bounds(lines, after_heading)
    isnothing(after_bounds) && error("Could not find section heading: $after_heading")

    _, stop = after_bounds
    insert_at = stop
    while insert_at > 1 && isempty(lines[insert_at - 1])
        insert_at -= 1
    end

    splice!(lines, insert_at:insert_at - 1, vcat([""], new_section, [""]))
    return join(lines, "\n") * "\n"
end

function latest_release(changelog::String)
    lines = split(chomp(changelog), "\n"; keepempty=true)
    release_heading = r"^## \[([^\]]+)\] - ([0-9]{4}-[0-9]{2}-[0-9]{2})$"
    start = findfirst(line -> occursin(release_heading, line), lines)
    isnothing(start) && error("Could not find a released changelog entry")

    match_result = match(release_heading, lines[start])
    version, date = match_result.captures

    stop = length(lines) + 1
    for index in (start + 1):length(lines)
        if startswith(lines[index], "## ")
            stop = index
            break
        end
    end

    body = lines[(start + 1):(stop - 1)]
    while !isempty(body) && isempty(first(body))
        popfirst!(body)
    end
    while !isempty(body) && isempty(last(body))
        pop!(body)
    end

    return version, date, body
end

function latest_release_markdown(changelog::String, footer::String)
    version, date, body = latest_release(changelog)
    lines = ["### $version - $date"]

    for line in body
        if startswith(line, "### ")
            push!(lines, "#" * line)
        else
            push!(lines, line)
        end
    end

    push!(lines, "")
    push!(lines, footer)
    return GENERATED_BEGIN * "\n" * join(lines, "\n") * "\n" * GENERATED_END
end

function write_if_changed(path::String, content::String)
    if isfile(path) && read(path, String) == content
        return false
    end

    mkpath(dirname(path))
    write(path, content)
    return true
end

function main()
    changelog = read(CHANGELOG_PATH, String)

    readme_recent = latest_release_markdown(
        changelog,
        "For the full release history, see [CHANGELOG.md](CHANGELOG.md).",
    )
    docs_recent = latest_release_markdown(
        changelog,
        "For the full release history, see [the changelog](@ref Changelog).",
    )

    readme = read(README_PATH, String)
    updated_readme = replace_or_insert_section(readme, "## Recent changes", readme_recent, "## Installation")

    docs_index = read(DOCS_INDEX_PATH, String)
    updated_docs_index = replace_or_insert_section(docs_index, "## Recent changes", docs_recent, "## Structure of the documentation")

    docs_changelog = GENERATED_NOTICE * "\n\n" * changelog

    changed = [
        write_if_changed(README_PATH, updated_readme),
        write_if_changed(DOCS_INDEX_PATH, updated_docs_index),
        write_if_changed(DOCS_CHANGELOG_PATH, docs_changelog),
    ]

    println(any(changed) ? "Updated changelog outputs." : "Changelog outputs are already up to date.")
end

main()
