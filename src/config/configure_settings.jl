function default_settings()
    return (
        ConstraintScaling = false,
        EnableJuMPDirectModel = false,
        EnableJuMPStringNames = false,
        AllowImplicitTopLevelCommodities = true,
        WriteSubcommodities = true,
        OverwriteResults = false,
        OutputDir = "results",
        OutputLayout = "long",
        OutputFormat = "csv",
        WriteOutputs = (;),
        OutputSignificantDigits = nothing,
        OutputAssetTags = true,
        AutoCreateNodes = false,
        AutoCreateLocations = true,
        Retrofitting = false,
        DualExportsEnabled = nothing  # Deprecated: use WriteOutputs.Duals (nothing = not set by the user)
    )
end

# File formats supported by `OutputFormat`, used as the output file extension
const OUTPUT_FORMATS = ("csv", "csv.gz", "parquet")
# Output types that can be keyed in `OutputFormat` and `WriteOutputs`
const OUTPUT_KEYS = (:Capacity, :CapacitySummary, :Capex, :Costs, :Curtailment, :Duals, :Flow, :NonServedDemand, :StorageLevel, :TimeWeights)

namedtuple(x) = x   # default case
function namedtuple(d::T) where {T<:AbstractDict}
    return (; (Symbol(k) => (v isa AbstractDict ? namedtuple(v) : v) for (k, v) in d)...)
end

function configure_settings(path::AbstractString, rel_path::AbstractString)
    path = rel_or_abs_path(path, rel_path)
    if isdir(path)
        path = joinpath(path, "macro_settings.json")
    end
    if !isfile(path)
        error("Settings file not found: $path")
    end
    model_settings = namedtuple(read_file(path))
    return configure_settings(model_settings)
end

function configure_settings(
    model_settings::AbstractDict{Symbol,Any},
    rel_path::AbstractString,
)
    if haskey(model_settings, :path)
        path = rel_or_abs_path(model_settings[:path], rel_path)
        return configure_settings(path, rel_path)
    else
        return configure_settings(namedtuple(model_settings))
    end
end

function configure_settings(model_settings::NamedTuple)
    validate_names(model_settings)
    settings = default_settings()

    settings = merge(settings, model_settings)

    validate_settings(settings)
    return translate_deprecated_settings(settings)
end

"""
    translate_deprecated_settings(settings::NamedTuple)

Translate deprecated settings into their replacements, with a deprecation warning:
- `DualExportsEnabled` → `WriteOutputs.Duals`. Setting both to different values is an error.

For backward compatibility, the returned `DualExportsEnabled` is always a `Bool` that mirrors
`WriteOutputs.Duals` (`true` unless duals are switched off), so code that reads
`settings.DualExportsEnabled` keeps working. `WriteOutputs.Duals` is the setting Macro uses.
"""
function translate_deprecated_settings(settings::NamedTuple)
    dual_exports = settings[:DualExportsEnabled]
    write_outputs = settings[:WriteOutputs]
    if !isnothing(dual_exports)
        if haskey(write_outputs, :Duals) && write_outputs[:Duals] != dual_exports
            error("Conflicting settings: DualExportsEnabled = $dual_exports but WriteOutputs.Duals = $(write_outputs[:Duals]). " *
                  "DualExportsEnabled is deprecated; remove it and keep WriteOutputs.Duals.")
        end
        @warn("""
        DualExportsEnabled is deprecated. Use "WriteOutputs": {"Duals": $dual_exports} instead.
        Translating automatically: WriteOutputs.Duals => $dual_exports.
        """, maxlog=1)
        write_outputs = merge(write_outputs, (Duals=dual_exports,))
    end
    return merge(settings, (WriteOutputs=write_outputs, DualExportsEnabled=get(write_outputs, :Duals, true)))
end

function validate_settings(settings::NamedTuple)
    @assert settings[:ConstraintScaling] ∈ (false, true)
    @assert settings[:AllowImplicitTopLevelCommodities] isa Bool
    @assert isnothing(settings[:DualExportsEnabled]) || settings[:DualExportsEnabled] isa Bool "DualExportsEnabled (deprecated) must be true or false"
    @assert settings[:OutputAssetTags] isa Bool
    @assert settings[:OutputLayout] isa Union{String, NamedTuple}
    if settings[:OutputLayout] isa String
        @assert settings[:OutputLayout] ∈ ("long", "wide")
    else
        # Note: we currently support these output files
        @assert all(keys(settings[:OutputLayout]) .∈ Ref((:Capacity, :CapacitySummary, :Costs, :Curtailment, :Flow, :NonServedDemand, :StorageLevel)))
        @assert all(values(settings[:OutputLayout]) .∈ Ref(("long", "wide")))
    end
    @assert settings[:OutputFormat] isa Union{String, NamedTuple}
    if settings[:OutputFormat] isa String
        @assert settings[:OutputFormat] ∈ OUTPUT_FORMATS "OutputFormat must be one of $(OUTPUT_FORMATS)"
    else
        @assert all(keys(settings[:OutputFormat]) .∈ Ref(OUTPUT_KEYS)) "OutputFormat keys must be in $(OUTPUT_KEYS)"
        @assert all(values(settings[:OutputFormat]) .∈ Ref(OUTPUT_FORMATS)) "OutputFormat values must be one of $(OUTPUT_FORMATS)"
    end
    @assert settings[:WriteOutputs] isa NamedTuple "WriteOutputs must be an object of output names to true/false"
    @assert all(keys(settings[:WriteOutputs]) .∈ Ref(OUTPUT_KEYS)) "WriteOutputs keys must be in $(OUTPUT_KEYS)"
    @assert all(v -> v isa Bool, values(settings[:WriteOutputs])) "WriteOutputs values must be true or false"
    sigdigits = settings[:OutputSignificantDigits]
    @assert isnothing(sigdigits) || (sigdigits isa Integer && sigdigits >= 1) "OutputSignificantDigits must be a positive integer"
    return nothing
end

function validate_names(settings::NamedTuple)
    # Check that all the names in the settings file are valid
    valid_names = keys(default_settings())
    unknown_names = setdiff(keys(settings), valid_names)
    if !isempty(unknown_names)
        error("Unknown settings: $(unknown_names)")
    end
end
