include("time_domain_reduction/time_domain_reduction.jl")

"""
    preprocess_inputs(source_case_path, output_case_path;
                      tdr_settings_path, overwrite=false,
                      copy_result_files=false,
                      output_feature_run_kwargs=NamedTuple())

Copy a source case, then apply configured preprocessing steps to the copy. The
resulting directory loads and runs through MacroEnergy's ordinary APIs.
`output_feature_run_kwargs` configures the temporary in-memory solve used only
when TDR output-based features are enabled. Their caches and retained subperiod
artifacts are saved under `source_case_path/TDR/`; source model inputs are unchanged.
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

    number_of_systems = length(last(tdr_system_entries(source_root)))
    settings_by_system = load_tdr_settings_by_system(abspath(tdr_settings_path), number_of_systems)

    @info "*** Preprocessing inputs ***"

    @info "Copying inputs from `$source_root` to `$output_root`."
    copy_case(
        source_root,
        output_root;
        overwrite,
        copy_result_files,
        settings_path=abspath(tdr_settings_path),
    )
    @info "Applying time-domain reduction."

    tdr_prepare_system_inputs!(output_root; source_case_root=source_root)

    tdr_time_domain_reduction(
        output_root,
        settings_by_system;
        source_case_path=source_root,
        output_feature_run_kwargs,
        inputs_prepared=true,
    )
    @info "Finished preprocessing inputs in `$output_root`."
    @info "*** Finished preprocessing inputs ***"
    return nothing
end

function copy_case(
    source_root::String,
    output_root::String;
    overwrite::Bool=false,
    copy_result_files::Bool=false,
    settings_path::Union{Nothing,String}=nothing,
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

    if ispath(output_root)
        if !overwrite
            throw(ArgumentError("Output case directory already exists: $output_root. Pass overwrite=true to replace it."))
        end
        rm(output_root; recursive=true, force=true)
    end
    mkpath(output_root)
    tdr_copy_input_manifest!(source_root, output_root; copy_result_files, settings_path)
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
