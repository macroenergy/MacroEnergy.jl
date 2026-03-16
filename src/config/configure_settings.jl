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
        AutoCreateNodes = false,
        AutoCreateLocations = true,
        Retrofitting = false,
        DualExportsEnabled = true
    )
end

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
    return settings
end

function validate_settings(settings::NamedTuple)
    @assert settings[:ConstraintScaling] ∈ (false, true)
    @assert settings[:AllowImplicitTopLevelCommodities] isa Bool
    @assert settings[:DualExportsEnabled] isa Bool
    @assert settings[:OutputLayout] isa Union{String, NamedTuple}
    if settings[:OutputLayout] isa String
        @assert settings[:OutputLayout] ∈ ("long", "wide")
    else
        # Note: we currently support these output files
        @assert all(keys(settings[:OutputLayout]) .∈ Ref((:Capacity, :Costs, :Curtailment, :Flow, :NonServedDemand, :StorageLevel)))
        @assert all(values(settings[:OutputLayout]) .∈ Ref(("long", "wide")))
    end
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
