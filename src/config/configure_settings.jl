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
    settings = namedtuple(resolve_inputs(system_settings_spec(), model_settings))
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
