const USER_ADDITIONS_NAME = "UserAdditions"
const USER_ADDITIONS_PATH = joinpath("tmp")
const USER_ADDITIONS_FILE = USER_ADDITIONS_NAME * ".jl"
const USER_SUBCOMMODITIES_FILE = "usersubcommodities.jl"
const USER_ASSETS_FILE = "userassets.jl"

user_additions_path(path::AbstractString) = joinpath(path, USER_ADDITIONS_PATH)
user_additions_module_path(path::AbstractString) = joinpath(user_additions_path(path), USER_ADDITIONS_FILE)
user_additions_subcommodities_path(path::AbstractString) = joinpath(user_additions_path(path), USER_SUBCOMMODITIES_FILE)
user_additions_assets_path(path::AbstractString) = joinpath(user_additions_path(path), USER_ASSETS_FILE)

function load_user_additions(module_file_path::AbstractString, user_additions_name::AbstractString=USER_ADDITIONS_NAME)
    """
    Load user additions from the specified case additions path.

    This function attempts to load a module named `UserAdditions` from the specified case additions path. If the module is not found, it logs a warning.
    """
    if isfile(module_file_path)
        @info(" ++ Loading user additions from $(relpath(module_file_path))")
        try
            push!(LOAD_PATH, dirname(module_file_path))
            Base.require(Base.PkgId(user_additions_name))
            @info(" ++ Successfully loaded $(user_additions_name) module.")
        catch e
            @warn("Could not load $(user_additions_name) module: $e")
        end
    else
        @warn("User additions file not found at $(relpath(module_file_path))")
    end
end

function create_user_additions_module(case_path::AbstractString=pwd())
    """
    Setup user additions by loading the user additions module.
    This function is called to ensure that the user additions are loaded before running any cases.
    """
    module_path = user_additions_module_path(case_path)
    user_files = [
        ("commodities", user_additions_subcommodities_path(case_path)),
        ("assets", user_additions_assets_path(case_path))
    ]
    mkpath(dirname(module_path))
    io = open(module_path, "w")
    println(io, "module $(USER_ADDITIONS_NAME)")
    println(io, "using $(@__MODULE__)")
    for (name, file) in user_files
        println(io, "")
        println(io, "$(name)_path = raw\"$file\"")
        println(io, "if isfile($(name)_path)")
        println(io, "    include($(name)_path)")
        println(io, "end")
    end
    println(io, "")
    println(io, "end")
    close(io)
end

function write_user_subcommodities(case_path::AbstractString, subcommodities_lines::Set{String})
    user_subcommodities_path = user_additions_subcommodities_path(case_path)
    @debug(" -- Writing subcommodities to file $(user_subcommodities_path)")
    mkpath(dirname(user_subcommodities_path))
    # Read each lines from the file into a Set{String} to avoid duplicates
    existing_lines = Set{String}()
    if isfile(user_subcommodities_path)
        for line in eachline(user_subcommodities_path) 
            if !isempty(strip(line))
                push!(existing_lines, line)
            end
        end
    end
    union!(subcommodities_lines, existing_lines)
    io = open(user_subcommodities_path, "w")
    for line in subcommodities_lines
        println(io, line)
    end
    close(io)
end