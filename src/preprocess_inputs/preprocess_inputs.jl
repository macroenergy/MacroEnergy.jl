include("time_domain_reduction/time_domain_reduction.jl")

"""
    preprocess_inputs(source_case_path, output_case_path;
                      tdr_settings_path, overwrite=false,
                      copy_result_files=false,
                      output_feature_run_kwargs=NamedTuple())

Copy a source case, then apply configured preprocessing steps to the copy. The
resulting directory loads and runs through MacroEnergy's ordinary APIs.
`output_feature_run_kwargs` configures the temporary in-memory solve used only
when TDR output-based features are enabled.
Set `copy_result_files=true` to retain top-level directories whose names begin
with `results` when copying the source case.
"""
function preprocess_inputs(
    source_case_path::AbstractString,
    output_case_path::AbstractString;
    tdr_settings_path::AbstractString,
    overwrite::Bool=false,
    copy_result_files::Bool=false,
    output_feature_run_kwargs::NamedTuple=NamedTuple(),
)::Nothing
    source_root = abspath(source_case_path)
    output_root = abspath(output_case_path)
    isdir(source_root) || throw(ArgumentError("Source case directory does not exist: $source_root"))

    settings = load_time_domain_reduction_settings(abspath(tdr_settings_path))

    @info "*** Preprocessing inputs ***"

    preserve_output_features = !isnothing(settings.output_features) &&
        settings.output_features.reuse_saved_features
    @info "Copying inputs from `$source_root` to `$output_root`."
    copy_case(
        source_root,
        output_root;
        overwrite,
        copy_result_files,
        preserve_tdr_output_features=preserve_output_features,
    )
    @info "Applying time-domain reduction."

    tdr_time_domain_reduction(
        output_root,
        settings;
        source_case_path=source_root,
        output_feature_run_kwargs,
    )
    @info "Finished preprocessing inputs in `$output_root`."
    return nothing
end

function copy_case(
    source_root::String,
    output_root::String;
    overwrite::Bool=false,
    copy_result_files::Bool=false,
    preserve_tdr_output_features::Bool=false,
)
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
    
    return mktempdir() do temporary_root
        saved_output_features = joinpath(temporary_root, "output_features")
        has_saved_output_features = preserve_tdr_output_features &&
            tdr_saved_output_features_exist(output_root)
        if has_saved_output_features
            @info " ++ Preserving saved output-based TDR features while replacing the output case."
            cp(tdr_output_features_directory(output_root), saved_output_features; force=false)
        end

        if ispath(output_root)
            if !overwrite
                throw(ArgumentError("Output case directory already exists: $output_root. Pass overwrite=true to replace it."))
            end
            rm(output_root; recursive=true, force=true)
        end

        mkpath(output_root)
        for source_path in readdir(source_root; join=true)
            is_result_directory = isdir(source_path) && startswith(basename(source_path), "results")
            if is_result_directory && !copy_result_files
                continue
            end
            cp(source_path, joinpath(output_root, basename(source_path)); force=false)
        end

        if has_saved_output_features
            destination = tdr_output_features_directory(output_root)
            ispath(destination) && rm(destination; recursive=true, force=true)
            mkpath(dirname(destination))
            cp(saved_output_features, destination; force=false)
        end
        return nothing
    end
end

function is_within(path::String, parent::String)
    relative_path = relpath(path, parent)
    return relative_path == "." || !(
        relative_path == ".." ||
        startswith(relative_path, "../") ||
        startswith(relative_path, "..\\")
    )
end
