macro examples_repo()
    return esc(quote
        reponame = "macroenergy/MacroEnergyExamples.jl"
        examples_path = "examples"
        examples_repo = repo(reponame; auth=auth)
    end)
end

@doc """
    list_examples(; auth::Union{GitHub.OAuth2,Nothing})::Vector{String}

List all available examples in the MacroEnergyExamples repository.
This function will print the names of all examples and return a vector of their names.
These names can be used with `download_example` and other methods to download or get
information about specific examples.
"""
function list_examples(; auth::Union{GitHub.OAuth2,Nothing}=nothing)
    examples_repo = @examples_repo
    examples_dir = directory(examples_repo, examples_path; auth=auth)[1]
    examples = [example.name for example in examples_dir if example.typ == "dir"]
    println("Available examples:")
    for example in examples
        println(" - $example")
    end
    println("Download an example using `download_example(\"example name\")`")
    return examples
end

@doc """
    find_example(example_name::String; auth::Union{GitHub.OAuth2,Nothing})::Tuple{GitHub.Content, GitHub.Repo}

Find an example by its name in the MacroEnergyExamples repository. These names can be obtained
from `list_examples()`. `find_example` returns a tuple containing the `GitHub.Content` object
for the requested examples GitHub directory and the `GitHub.Repo` object for the MacroEnergyExamples repository.
"""
function find_example(example_name::String; auth::Union{GitHub.OAuth2,Nothing}=nothing)
    examples_repo = @examples_repo
    examples_dir = directory(examples_repo, examples_path; auth=auth)[1]
    example_idx = findfirst(x -> x.name == example_name, examples_dir)
    if isnothing(example_idx)
        println("Example not found: $example_name")
        return nothing, nothing
    end
    return examples_dir[example_idx], examples_repo
end

@doc """
    download_example(example_name::String, target_dir::String = pwd(); auth::Union{GitHub.OAuth2,Nothing})::Nothing

Download an example from the MacroEnergyExamples repository to a specified target directory.
The `example_name` should match one of the names listed by `list_examples()`.
The `target_dir` is the directory where the example will be downloaded, defaulting to the current working directory.
"""
function download_example(example_name::String, target_dir::String = pwd(); auth::Union{GitHub.OAuth2,Nothing}=nothing)
    (example_dir, examples_repo) = find_example(example_name; auth=auth)
    if isnothing(example_dir)
        return nothing
    end
    download_gh(example_dir, examples_repo, target_dir; auth=auth)
    println("Example '$example_name' downloaded to $target_dir")
    return nothing
end

@doc """
    download_examples(target_dir::String = pwd(), pause_seconds::Float64 = 1.0; auth::Union{GitHub.OAuth2,Nothing})::Nothing

Download all examples from the MacroEnergyExamples repository to a specified target directory.\n
The `target_dir` is the directory where all examples will be downloaded, defaulting to the current working directory. pause_seconds is the time to pause between downloads to avoid hitting GitHub API rate limits.
"""
function download_examples(target_dir::String = pwd(), pause_seconds::Float64 = 1.0; auth::Union{GitHub.OAuth2, Nothing}=nothing)
    try
        all_examples = list_examples(; auth=auth)
        println("Downloading all examples to $target_dir")
        for example_name in all_examples
            download_example(example_name, target_dir; auth=auth)
            # Pause for pause_seconds seconds to avoid hitting GitHub API rate limits
            sleep(pause_seconds)
        end
    catch e
        println("You may have hit the GitHub API rate limit.\nPlease download examples individually, increase the pause_seconds, or login to the GitHub API to increase your rate limit.")
    end
    return nothing
end

@doc """
    example_readme(example_name::String; auth::Union{GitHub.OAuth2,Nothing})::Nothing

Display the README.md file for a specific example from the MacroEnergyExamples repository.
The `example_name` should match one of the names listed by `list_examples()`.
"""
function example_readme(example_name::String; auth::Union{GitHub.OAuth2,Nothing}=nothing)
    example_dir, examples_repo = find_example(example_name; auth=auth)
    for item in directory(examples_repo, example_dir; auth=auth)[1]
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
    example_contents(example_name::String; auth::Union{GitHub.OAuth2,Nothing})::Nothing

Display the contents of a specific example from the MacroEnergyExamples repository.
The `example_name` should match one of the names listed by `list_examples()`.
This function will print the names of all files in the example directory.
"""
function example_contents(example_name::String; auth::Union{GitHub.OAuth2,Nothing}=nothing)
    example_dir, examples_repo = find_example(example_name; auth=auth)
    example_files = [file.path for file in directory(examples_repo, example_dir; auth=auth)[1] if file.typ == "file"]
    println("Contents of $example_name:")
    for file in example_files
        println(" - $file")
    end
    return nothing
end

"""
    download_gh(dir_path::String, repo::GitHub.Repo, target_dir::String; auth::Union{GitHub.OAuth2,Nothing})::Nothing

Download a directory from a GitHub repository to a specified target directory.\n
The `dir_path` is the path to the directory in the repository, `repo` is the `GitHub.Repo` object,
and `target_dir` is the local directory where the contents will be downloaded.
"""
function download_gh(dir_path::String, repo::GitHub.Repo, target_dir::String; auth::Union{GitHub.OAuth2,Nothing}=nothing)
    try
        download_gh(directory(repo, dir_path)[1], repo, target_dir; auth=auth)
        return nothing
    catch e
        if isa(e, GitHub.GitHubError) && e.code == 404
            println("Directory not found: $dir_path")
            return nothing
        else
            printn("Error: $e")
            return nothing
        end
    end
end

"""
    download_gh(elem::GitHub.Content, repo::GitHub.Repo, target_dir::String; auth::Union{GitHub.OAuth2,Nothing})::Nothing

Attempt to download a single element (file or directory) from a GitHub repository to a specified target directory. If the element is a file, it will be downloaded directly. If it is a directory, the function will recursively download all contents within that directory.\n
The `elem` is a `GitHub.Content` object representing the file or directory, `repo` is the `GitHub.Repo` object, and `target_dir` is the local directory where the contents will be downloaded.
"""
function download_gh(elem::GitHub.Content, repo::GitHub.Repo, target_dir::String; auth::Union{GitHub.OAuth2,Nothing}=nothing)
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
        mkpath(joinpath(target_dir, target_path))
        new_dir = directory(repo, elem.path)[1]
        for sub_elem in new_dir
            download_gh(sub_elem, repo, target_dir; auth=auth)
        end
    end
end

function download_gh(elems::Vector{GitHub.Content}, repo::GitHub.Repo, target_dir::String; auth::Union{GitHub.OAuth2,Nothing}=nothing)
    for elem in elems
        download_gh(elem, repo, target_dir; auth=auth)
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
