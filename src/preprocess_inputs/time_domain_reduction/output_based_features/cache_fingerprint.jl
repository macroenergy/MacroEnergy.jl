# This is to help keep track of changes to the cache formatting.
# It should be incremented whenever the structure of the cached data changes.
const TDR_OUTPUT_CACHE_VERSION = 1

"""One source dependency, identified by its portable case-relative path."""
struct TDROutputCacheFile
    path::String
    sha256::String
end

"""Output-profile selection; clustering weights are deliberately excluded."""
struct TDROutputCacheFeatureSelection
    id::Union{Nothing,String}
    provider::String
    asset::Union{Nothing,String}
    commodity::Union{Nothing,String}
end

"""
Inputs determining output-feature cache validity. Review the cache version when
changing these fields or their interpretation. System and Case definitions retain
their flexible JSON structure; the rest of the fingerprint has explicit types.
"""
struct TDROutputCacheInputs
    cache_version::Int
    system_index::Union{Nothing,Int}
    system::Dict{String,Any}
    case::Dict{String,Any}
    files::Vector{TDROutputCacheFile}
    full_length::Int
    timesteps_per_representative_period::Int
    include_policy_constraints::Bool
    feature_selection::Vector{TDROutputCacheFeatureSelection}
end

"""Digest and the source inputs/configuration from which it was computed."""
struct TDROutputCacheFingerprint
    sha256::String
    inputs::TDROutputCacheInputs
end

# Preserve the on-disk schema independently of the in-memory representation.
tdr_cache_data(file::TDROutputCacheFile) = Dict("path" => file.path, "sha256" => file.sha256)
tdr_cache_data(feature::TDROutputCacheFeatureSelection) = Dict(
    "id" => feature.id, "provider" => feature.provider,
    "asset" => feature.asset, "commodity" => feature.commodity)
tdr_cache_data(inputs::TDROutputCacheInputs) = Dict(
    "cache_version" => inputs.cache_version,
    "system_index" => inputs.system_index,
    "system" => inputs.system,
    "case" => inputs.case,
    "files" => tdr_cache_data.(inputs.files),
    "full_length" => inputs.full_length,
    "timesteps_per_representative_period" => inputs.timesteps_per_representative_period,
    "include_policy_constraints" => inputs.include_policy_constraints,
    "feature_selection" => tdr_cache_data.(inputs.feature_selection))
tdr_cache_data(fingerprint::TDROutputCacheFingerprint) = Dict(
    "sha256" => fingerprint.sha256, "inputs" => tdr_cache_data(fingerprint.inputs))

struct TDROutputCacheMismatch <: Exception
    reason::String
end
Base.showerror(io::IO, error::TDROutputCacheMismatch) = print(io, error.reason)

# Sort object keys before serialization; Dict iteration order is not a cache key.
function tdr_canonical_cache_data(value)
    if value isa AbstractDict
        return OrderedDict(String(key) => tdr_canonical_cache_data(value[key])
            for key in sort!(collect(keys(value)); by=String))
    elseif value isa AbstractVector
        return tdr_canonical_cache_data.(value)
    end
    return value
end

tdr_cache_json(value) = JSON3.write(tdr_canonical_cache_data(value))
tdr_cache_json(value::Union{TDROutputCacheInputs,TDROutputCacheFeatureSelection}) =
    tdr_cache_json(tdr_cache_data(value))

"""Output selection affects cached profiles; weights are applied when loading."""
function tdr_output_feature_selection(features::Vector{TDROutputFeatureSpec})
    selections = [TDROutputCacheFeatureSelection(feature.id, feature.provider,
        feature.asset, feature.commodity) for feature in features]
    return sort!(selections; by=tdr_cache_json)
end

function tdr_cache_input_definition(case_root::String, data)
    definition = deepcopy(data)
    function normalize_paths!(value)
        if value isa AbstractDict
            if get(value, "path", nothing) isa AbstractString
                value["path"] = tdr_normalize_path(relpath(abspath(case_root, value["path"]), case_root))
            end
            foreach(normalize_paths!, values(value))
        elseif value isa AbstractVector
            foreach(normalize_paths!, value)
        end
    end
    normalize_paths!(definition)
    return definition
end

"""
Fingerprint one source System without parsing CSVs or materializing file contents.
Share `file_hashes` across Systems to stream each shared dependency only once per run.
"""
function tdr_output_cache_fingerprint(
    case_root::String, settings::TDRSettings, full_length::Int;
    system_index::Union{Nothing,Int}=nothing,
    file_hashes::Dict{String,String}=Dict{String,String}(),
)
    case_root = abspath(case_root)
    root, systems = tdr_system_entries(case_root)
    index = isnothing(system_index) ? 1 : system_index
    system = systems[index]
    manifest = tdr_system_input_manifest(case_root, system)
    case_definition = haskey(root, "case") ? Dict(key => value for (key, value) in root if key != "case") : Dict()
    tdr_collect_manifest_references!(manifest, case_root, case_definition, Set{String}();
        recursive_directories=false)
    # Bare single-System cases also load this conventional settings file implicitly.
    implicit_settings = joinpath(case_root, "settings", "case_settings.json")
    isfile(implicit_settings) && tdr_collect_manifest_paths!(manifest, case_root, implicit_settings)
    additions = user_additions_path(case_root)
    isdir(additions) && tdr_collect_manifest_paths!(manifest, case_root, additions)
    files = [TDROutputCacheFile(
        tdr_normalize_path(relpath(path, case_root)),
        get!(file_hashes, path) do
            open(path, "r") do io
                bytes2hex(SHA.sha256(io))
            end
        end,
    ) for path in sort!(collect(keys(manifest))) if isfile(path)]
    inputs = TDROutputCacheInputs(
        TDR_OUTPUT_CACHE_VERSION,
        system_index,
        tdr_cache_input_definition(case_root, system),
        tdr_cache_input_definition(case_root, case_definition),
        sort!(files; by=file -> file.path),
        full_length,
        settings.timesteps_per_representative_period,
        settings.output_features.subperiod_runs.include_policy_constraints,
        tdr_output_feature_selection(settings.output_features.features),
    )
    return TDROutputCacheFingerprint(bytes2hex(SHA.sha256(tdr_cache_json(inputs))), inputs)
end

"""Record solver information without making it a condition for cache reuse."""
function tdr_output_solver_provenance(run_case_kwargs::NamedTuple)
    attributes = get(run_case_kwargs, :optimizer_attributes, nothing)
    supplied = isnothing(attributes) ? nothing : Dict(string(key) =>
        (value isa Union{Nothing,Bool,Number,AbstractString} ? value : string(value))
        for (key, value) in pairs(attributes isa NamedTuple ? attributes : Dict(attributes)))
    return Dict(
        "optimizer" => string(get(run_case_kwargs, :optimizer, TDR_DEFAULT_SUBPERIOD_RUN_KWARGS.optimizer)),
        "supplied_optimizer_attributes" => supplied,
    )
end
