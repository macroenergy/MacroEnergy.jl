include("tdr_utilities.jl")
include("tdr_settings.jl")
include("tdr_inputs.jl")
include("tdr_clustering.jl")
include("tdr_outputs.jl")

"""
    time_domain_reduction(case_path, settings)

Apply an input-only time-domain reduction in an already copied case directory.
`settings` may be a [`TDRSettings`](@ref) or a path to its JSON file.
"""
function time_domain_reduction(case_path::AbstractString, settings)::Nothing
    parsed_settings = settings isa TDRSettings ? settings : load_time_domain_reduction_settings(settings)
    tdr_time_domain_reduction(abspath(case_path), parsed_settings)
    return nothing
end

function tdr_time_domain_reduction(case_path::AbstractString, parsed_settings::TDRSettings; source_case_path::AbstractString=case_path)::Nothing
    case_root = abspath(case_path)
    isdir(case_root) || throw(ArgumentError("Case directory does not exist: $case_root"))

    sources, clustering_sources, full_length, time_data_path, time_data = tdr_sources(case_root, parsed_settings)
    representatives, period_map = tdr_cluster(clustering_sources, full_length, parsed_settings)
    row_indices = tdr_row_indices(representatives, parsed_settings.timesteps_per_representative_period)
    tdr_write_reduced_sources!(sources, row_indices)
    clear_csv_cache!()
    map_path = tdr_write_time_data!(time_data_path, case_root, time_data, parsed_settings, representatives, period_map)
    provenance = Dict(
        "source_case_path" => abspath(source_case_path),
        "settings" => Dict(
            "timesteps_per_representative_period" => parsed_settings.timesteps_per_representative_period,
            "representative_periods" => parsed_settings.representative_periods,
            "method" => String(tdr_method_name(parsed_settings.method_settings)),
            "method_settings" => tdr_method_settings_data(parsed_settings.method_settings),
            "scaling" => String(parsed_settings.scaling),
        ),
        "representative_periods" => representatives,
        "period_map_path" => relpath(map_path, case_root),
    )
    write_json(joinpath(case_root, "time_domain_reduction_provenance.json"), provenance)
    return nothing
end
