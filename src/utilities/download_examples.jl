const EXAMPLES_REPO_NAME = "macroenergy/MacroEnergyExamples.jl"
const EXAMPLES_PATH = "examples"

function examples_repository(auth_kwargs=NamedTuple())
    return repo(EXAMPLES_REPO_NAME; auth_kwargs...)
end

function macroenergy_version()
    project = Pkg.TOML.parsefile(joinpath(@__DIR__, "..", "..", "Project.toml"))
    return VersionNumber(project["version"])
end

function example_version_tag(version::VersionNumber)
    return "v$(version)"
end

function example_version_tag(version::AbstractString)
    version_string = startswith(version, "v") ? version[2:end] : version
    return example_version_tag(VersionNumber(version_string))
end

function example_release_branch(version::VersionNumber)
    return "release-$(version.major).$(version.minor)"
end

function default_examples_ref()
    return example_version_tag(macroenergy_version())
end

function examples_refs(; branch=nothing, version=nothing)
    if !isnothing(branch) && !isnothing(version)
        error("Specify either `branch` or `version`, not both.")
    elseif !isnothing(branch)
        return [string(branch)]
    elseif !isnothing(version)
        return [example_version_tag(version)]
    end
    version = macroenergy_version()
    return [example_version_tag(version), example_release_branch(version)]
end

function examples_ref(; branch=nothing, version=nothing)
    return first(examples_refs(; branch=branch, version=version))
end

function ref_kwargs(ref::AbstractString)
    return (; params=Dict("ref" => ref))
end

function is_github_404(e)
    return isa(e, ErrorException) && occursin("Status Code: 404", e.msg)
end

function directory_at_ref(repo::GitHub.Repo, path, ref::AbstractString; auth_kwargs=NamedTuple())
    return directory(repo, path; auth_kwargs..., ref_kwargs(ref)...)[1]
end

function examples_directory(examples_repo::GitHub.Repo; branch=nothing, version=nothing, auth_kwargs=NamedTuple())
    last_error = nothing
    for ref in examples_refs(; branch=branch, version=version)
        try
            return directory_at_ref(examples_repo, EXAMPLES_PATH, ref; auth_kwargs=auth_kwargs), ref
        catch e
            if is_github_404(e)
                last_error = e
            else
                rethrow(e)
            end
        end
    end
    throw(last_error)
end

function find_example_with_ref(example_name::String; branch=nothing, version=nothing, auth_kwargs=NamedTuple())
    examples_repo = examples_repository(auth_kwargs)
    examples_dir, ref = examples_directory(examples_repo; branch=branch, version=version, auth_kwargs=auth_kwargs)
    example_idx = findfirst(x -> x.name == example_name, examples_dir)
    if isnothing(example_idx)
        println("Example not found in MacroEnergyExamples.jl@$ref: $example_name")
        return nothing, nothing, ref
    end
    return examples_dir[example_idx], examples_repo, ref
end

function example_items_with_ref(example_name::String; branch=nothing, version=nothing, auth_kwargs=NamedTuple())
    example_dir, examples_repo, ref = find_example_with_ref(example_name; branch=branch, version=version, auth_kwargs=auth_kwargs)
    if isnothing(example_dir)
        return nothing, ref
    end
    return directory_at_ref(examples_repo, example_dir, ref; auth_kwargs=auth_kwargs), ref
end

@doc """
    list_examples(; branch=nothing, version=nothing, auth::Any)::Vector{String}

List all available examples in the MacroEnergyExamples repository.
This function will print the names of all examples and return a vector of their names.
These names can be used with `download_example` and other methods to download or get
information about specific examples.

By default, examples are listed from the `vX.Y.Z` tag that matches the current
MacroEnergy version, falling back to `release-X.Y` when that tag is not
available. Use `branch` to list examples from a branch, or `version` to list
examples from a specific `vX.Y.Z` tag.

The `auth` parameter can be used to authenticate your requests to the GitHub API. 
It should be a valid `GitHub.OAuth2` object created using the `authenticate_github` method, 
or a `GitHub.UsernamePassAuth` or `GitHub.JWTAuth` object created using the GitHub.jl package.
"""
function list_examples(; branch=nothing, version=nothing, auth=nothing)
    auth_kwargs = check_auth(auth)
    examples_repo = examples_repository(auth_kwargs)
    examples_dir, ref = examples_directory(examples_repo; branch=branch, version=version, auth_kwargs=auth_kwargs)
    examples = [example.name for example in examples_dir if example.typ == "dir"]
    println("Available examples from MacroEnergyExamples.jl@$ref:")
    for example in examples
        println(" - $example")
    end
    println("Download an example using `download_example(\"example name\")`")
    return examples
end

@doc """
    find_example(example_name::String; branch=nothing, version=nothing, auth::Any)::Tuple{GitHub.Content, GitHub.Repo}

Find an example by its name in the MacroEnergyExamples repository. These names can be obtained
from `list_examples()`. `find_example` returns a tuple containing the `GitHub.Content` object
for the requested examples GitHub directory and the `GitHub.Repo` object for the MacroEnergyExamples repository.

By default, examples are searched from the `vX.Y.Z` tag that matches the current
MacroEnergy version, falling back to `release-X.Y` when that tag is not
available. Use `branch` to search a branch, or `version` to search a specific
`vX.Y.Z` tag.

The `auth` parameter can be used to authenticate your requests to the GitHub API. 
It should be a valid `GitHub.OAuth2` object created using the `authenticate_github` method, 
or a `GitHub.UsernamePassAuth` or `GitHub.JWTAuth` object created using the GitHub.jl package.
"""
function find_example(example_name::String; branch=nothing, version=nothing, auth=nothing)
    auth_kwargs = check_auth(auth)
    example_dir, examples_repo, _ = find_example_with_ref(example_name; branch=branch, version=version, auth_kwargs=auth_kwargs)
    return example_dir, examples_repo
end

@doc """
    download_example(example_name::String, target_dir::String = pwd(); branch=nothing, version=nothing, auth::Any)::Nothing

Download an example from the MacroEnergyExamples repository to a specified target directory.
The `example_name` should match one of the names listed by `list_examples()`.
The `target_dir` is the directory where the example will be downloaded, defaulting to the current working directory.

By default, examples are downloaded from the `vX.Y.Z` tag that matches the
current MacroEnergy version, falling back to `release-X.Y` when that tag is not
available. Use `branch` to download from a branch, or `version` to download
from a specific `vX.Y.Z` tag.

The `auth` parameter can be used to authenticate your requests to the GitHub API. 
It should be a valid `GitHub.OAuth2` object created using the `authenticate_github` method, 
or a `GitHub.UsernamePassAuth` or `GitHub.JWTAuth` object created using the GitHub.jl package.
"""
function download_example(example_name::String, target_dir::String = pwd(); branch=nothing, version=nothing, auth=nothing)
    auth_kwargs = check_auth(auth)
    (example_dir, examples_repo, ref) = find_example_with_ref(example_name; branch=branch, version=version, auth_kwargs=auth_kwargs)
    if isnothing(example_dir)
        return nothing
    end
    download_gh(example_dir, examples_repo, target_dir; ref=ref, auth_kwargs...)
    println("Example '$example_name' downloaded from MacroEnergyExamples.jl@$ref to $target_dir")
    return nothing
end

@doc """
    download_examples(target_dir::String = pwd(), pause_seconds::Float64 = 1.0; branch=nothing, version=nothing, auth::Any)::Nothing

Download all examples from the MacroEnergyExamples repository to a specified target directory.\n
The `target_dir` is the directory where all examples will be downloaded, defaulting to the current working directory. pause_seconds is the time to pause between downloads to avoid hitting GitHub API rate limits.

By default, examples are downloaded from the `vX.Y.Z` tag that matches the
current MacroEnergy version, falling back to `release-X.Y` when that tag is not
available. Use `branch` to download from a branch, or `version` to download
from a specific `vX.Y.Z` tag.

The `auth` parameter can be used to authenticate your requests to the GitHub API. 
It should be a valid `GitHub.OAuth2` object created using the `authenticate_github` method, 
or a `GitHub.UsernamePassAuth` or `GitHub.JWTAuth` object created using the GitHub.jl package.
"""
function download_examples(target_dir::String = pwd(), pause_seconds::Float64 = 1.0; branch=nothing, version=nothing, auth=nothing)
    auth_kwargs = check_auth(auth)
    try
        examples_repo = examples_repository(auth_kwargs)
        examples_dir, ref = examples_directory(examples_repo; branch=branch, version=version, auth_kwargs=auth_kwargs)
        println("Downloading all examples from MacroEnergyExamples.jl@$ref to $target_dir")
        for example_dir in examples_dir
            example_dir.typ == "dir" || continue
            download_gh(example_dir, examples_repo, target_dir; ref=ref, auth_kwargs...)
            println("Example '$(example_dir.name)' downloaded from MacroEnergyExamples.jl@$ref to $target_dir")
            # Pause for pause_seconds seconds to avoid hitting GitHub API rate limits
            sleep(pause_seconds)
        end
    catch e
        if is_github_404(e)
            rethrow(e)
        else
            println("You may have hit the GitHub API rate limit.\nPlease download examples individually, increase the pause_seconds, or login to the GitHub API to increase your rate limit.")
        end
    end
    return nothing
end

@doc """
    example_readme(example_name::String; branch=nothing, version=nothing, auth::Any)::Nothing

Display the README.md file for a specific example from the MacroEnergyExamples repository.
The `example_name` should match one of the names listed by `list_examples()`.

By default, the README is read from the `vX.Y.Z` tag that matches the current
MacroEnergy version, falling back to `release-X.Y` when that tag is not
available. Use `branch` to read from a branch, or `version` to read from a
specific `vX.Y.Z` tag.

The `auth` parameter can be used to authenticate your requests to the GitHub API. 
It should be a valid `GitHub.OAuth2` object created using the `authenticate_github` method, 
or a `GitHub.UsernamePassAuth` or `GitHub.JWTAuth` object created using the GitHub.jl package.
"""
function example_readme(example_name::String; branch=nothing, version=nothing, auth=nothing)
    auth_kwargs = check_auth(auth)
    example_items, ref = example_items_with_ref(example_name; branch=branch, version=version, auth_kwargs=auth_kwargs)
    if isnothing(example_items)
        return nothing
    end
    for item in example_items
        if lowercase(item.name) == "readme.md"
            tmp_file_name = download(item.download_url)
            readme_contents = Markdown.parse(read(tmp_file_name, String))
            display(readme_contents)
            return nothing
        end
    end
    println("No README.md found for example: $example_name")
    return nothing
end

@doc """
    example_contents(example_name::String; branch=nothing, version=nothing, auth::Any)::Nothing

Display the contents of a specific example from the MacroEnergyExamples repository.
The `example_name` should match one of the names listed by `list_examples()`.
This function will print the names of all files in the example directory.

By default, contents are read from the `vX.Y.Z` tag that matches the current
MacroEnergy version, falling back to `release-X.Y` when that tag is not
available. Use `branch` to read from a branch, or `version` to read from a
specific `vX.Y.Z` tag.

The `auth` parameter can be used to authenticate your requests to the GitHub API. 
It should be a valid `GitHub.OAuth2` object created using the `authenticate_github` method, 
or a `GitHub.UsernamePassAuth` or `GitHub.JWTAuth` object created using the GitHub.jl package.
"""
function example_contents(example_name::String; branch=nothing, version=nothing, auth=nothing)
    auth_kwargs = check_auth(auth)
    example_items, ref = example_items_with_ref(example_name; branch=branch, version=version, auth_kwargs=auth_kwargs)
    if isnothing(example_items)
        return nothing
    end
    example_files = [file.path for file in example_items if file.typ == "file"]
    println("Contents of $example_name from MacroEnergyExamples.jl@$ref:")
    for file in example_files
        println(" - $file")
    end
    return nothing
end

"""
    download_gh(dir_path::String, repo::GitHub.Repo, target_dir::String; auth::Any)::Nothing

Download a directory from a GitHub repository to a specified target directory.\n
The `dir_path` is the path to the directory in the repository, `repo` is the `GitHub.Repo` object,
and `target_dir` is the local directory where the contents will be downloaded.
"""
function download_gh(dir_path::String, repo::GitHub.Repo, target_dir::String; ref=default_examples_ref(), auth=nothing)
    auth_kwargs = check_auth(auth)
    try
        download_gh(directory(repo, dir_path; auth_kwargs..., ref_kwargs(ref)...)[1], repo, target_dir; ref=ref, auth_kwargs...)
        return nothing
    catch e
        if is_github_404(e)
            println("Directory not found in MacroEnergyExamples.jl@$ref: $dir_path")
            return nothing
        else
            rethrow(e)
            return nothing
        end
    end
end

"""
    download_gh(elem::GitHub.Content, repo::GitHub.Repo, target_dir::String; auth::Any)::Nothing

Attempt to download a single element (file or directory) from a GitHub repository to a specified target directory. If the element is a file, it will be downloaded directly. If it is a directory, the function will recursively download all contents within that directory.\n
The `elem` is a `GitHub.Content` object representing the file or directory, `repo` is the `GitHub.Repo` object, and `target_dir` is the local directory where the contents will be downloaded.
"""
function download_gh(elem::GitHub.Content, repo::GitHub.Repo, target_dir::String; ref=default_examples_ref(), auth=nothing)
    auth_kwargs = check_auth(auth)
    target_dir = joinpath(pwd(), target_dir)
    split_path = splitpath(elem.path)
    if split_path[1] == "examples"
        target_path = joinpath(target_dir, split_path[2:end]...)
    else
        target_path = joinpath(target_dir, split_path...)
    end
    if elem.typ == "file"
        download(elem.download_url, target_path)
    elseif elem.typ == "dir"
        mkpath(target_path)
        new_dir = directory(repo, elem.path; auth_kwargs..., ref_kwargs(ref)...)[1]
        for sub_elem in new_dir
            download_gh(sub_elem, repo, target_dir; ref=ref, auth_kwargs...)
        end
    end
end

function download_gh(elems::Vector{GitHub.Content}, repo::GitHub.Repo, target_dir::String; ref=default_examples_ref(), auth=nothing)
    auth_kwargs = check_auth(auth)
    for elem in elems
        download_gh(elem, repo, target_dir; ref=ref, auth_kwargs...)
    end
end


"""
    authenticate_github(token::String)::GitHub.OAuth2

Authenticate your downloads from GitHub using a personal access token. This function returns a `GitHub.OAuth2` object that can be used for authenticated requests to the GitHub API.\n

You should create a personal access token in the GitHub settings under Developer settings -> Personal access tokens.\n

You can use the created OAuth2 token to authenticate your other function calls, for example: 
    
```julia
auth = authenticate_github("your_personal_access_token")
list_examples(; auth=auth)
download_example("example_name"; auth=auth)
```

"""
function authenticate_github(token::String)::GitHub.OAuth2
    return GitHub.authenticate(token)
end

"""
    check_auth(auth::Any)::NamedTuple

Check if the provided authentication object is valid for GitHub API requests. This function returns a NamedTuple containing the `auth` object if it is a valid type, or an empty NamedTuple otherwise.\n
The `auth` parameter can be a `GitHub.OAuth2`, `GitHub.UsernamePassAuth`, or `GitHub.JWTAuth` object.
"""
function check_auth(auth::Any)::NamedTuple
    if isa(auth, GitHub.OAuth2) || isa(auth, GitHub.UsernamePassAuth) || isa(auth, GitHub.JWTAuth)
        return (; auth=auth)
    end
        return NamedTuple()
end
