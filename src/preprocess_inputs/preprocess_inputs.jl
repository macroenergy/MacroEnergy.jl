include("time_domain_reduction/time_domain_reduction.jl")

"""
    preprocess_inputs(source_case_path, output_case_path;
                      tdr_settings_path, overwrite=false)

Copy a source case, then apply configured preprocessing steps to the copy. The
resulting directory loads and runs through MacroEnergy's ordinary APIs.
"""
function preprocess_inputs(
    source_case_path::AbstractString,
    output_case_path::AbstractString;
    tdr_settings_path::AbstractString,
    overwrite::Bool=false,
)::Nothing
    source_root = abspath(source_case_path)
    output_root = abspath(output_case_path)
    isdir(source_root) || throw(ArgumentError("Source case directory does not exist: $source_root"))

    settings = load_time_domain_reduction_settings(abspath(tdr_settings_path))

    copy_case(source_root, output_root; overwrite)

    tdr_time_domain_reduction(output_root, settings; source_case_path=source_root)
    return nothing
end

function copy_case(source_root::String, output_root::String; overwrite::Bool=false)
    if is_within(output_root, source_root)
        throw(ArgumentError(
            "Output case directory must not be inside the source case directory. " *
            "Choose a sibling or another external directory: $output_root",
        ))
    end

    source_output_name = joinpath(source_root, basename(output_root))
    if isdir(source_output_name)
        throw(ArgumentError(
            "Source case directory contains `$source_output_name`, a directory with the same " *
            "name as the requested output directory. This is likely a previous generated " *
            "output and would be copied into the new case. Remove or move it before preprocessing.",
        ))
    end
    
    if ispath(output_root)
        if !overwrite
            throw(ArgumentError("Output case directory already exists: $output_root. Pass overwrite=true to replace it."))
        end
        rm(output_root; recursive=true, force=true)
    end

    mkpath(dirname(output_root))
    cp(source_root, output_root; force=false)
    return nothing
end

function is_within(path::String, parent::String)
    relative_path = relpath(path, parent)
    return relative_path == "." || !(
        relative_path == ".." ||
        startswith(relative_path, "../") ||
        startswith(relative_path, "..\\")
    )
end
