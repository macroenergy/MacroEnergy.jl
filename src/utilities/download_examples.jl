macro examples_repo()
    return esc(quote
        reponame = "macroenergy/MacroEnergyExamples.jl"
        examples_path = "examples"
        examples_repo = repo(reponame)
    end)
end

function list_examples()
    examples_repo = @examples_repo
    examples_dir = directory(examples_repo, examples_path)[1]
    examples = [example.name for example in examples_dir if example.typ == "dir"]
    println("Available examples:")
    for example in examples
        println(" - $example")
    end
    println("Download an example using `download_example(\"example name\")`")
    return examples
end

function find_example(example_name::String)
    examples_repo = @examples_repo
    examples_dir = directory(examples_repo, examples_path)[1]
    example_idx = findfirst(x -> x.name == example_name, examples_dir)
    if isnothing(example_idx)
        println("Example not found: $example_name")
        return nothing
    end
    return examples_dir[example_idx], examples_repo
end

function download_example(example_name::String, local_path::String = pwd())
    example_dir, examples_repo = find_example(example_name)
    download_gh(example_dir, examples_repo, local_path)
    println("Example downloaded to $local_path")
    return nothing
end

function example_readme(example_name::String, local_path::String = pwd())
    example_dir, examples_repo = find_example(example_name)
    for item in directory(examples_repo, example_dir)[1]
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

function example_contents(example_name::String, local_path::String = pwd())
    example_dir, examples_repo = find_example(example_name)
    example_files = [file.path for file in directory(examples_repo, example_dir)[1] if file.typ == "file"]
    println("Contents of $example_name:")
    for file in example_files
        println(" - $file")
    end
    return nothing
end

function download_gh(dir_path::String, repo::GitHub.Repo, local_path::String)
    try
        download_gh(directory(repo, dir_path)[1], repo, local_path)
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

function download_gh(elem::GitHub.Content, repo::GitHub.Repo, local_path::String)
    if elem.typ == "file"
        download(elem.download_url, joinpath(local_path, elem.path))
    elseif elem.typ == "dir"
        mkpath(joinpath(local_path, elem.path))
        new_dir = directory(repo, elem.path)[1]
        for sub_elem in new_dir
            download_gh(sub_elem, repo, local_path)
        end
    end
end

function download_gh(elems::Vector{GitHub.Content}, repo::GitHub.Repo, local_path::String)
    for elem in elems
        download_gh(elem, repo, local_path)
    end
end