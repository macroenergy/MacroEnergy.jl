###### ###### ###### ###### ###### ###### ###### ###### ###### ###### ###### ###### ######
# From the settings read from files (load_settings.jl) to the settings of a case: old names are
# translated, the settings are validated against their spec (settings_schema.jl) and the
# defaults filled in, and the result becomes the `NamedTuple` shared by the Case and its Systems.
###### ###### ###### ###### ###### ###### ###### ###### ###### ###### ###### ###### ######

namedtuple(x) = x   # default case
function namedtuple(d::T) where {T<:AbstractDict}
    return (; (Symbol(k) => (v isa AbstractDict ? namedtuple(v) : v) for (k, v) in d)...)
end

# Copy settings (read from JSON, written inline, or given as a NamedTuple) into nested
# `OrderedDict`s, so they can be edited and compared in the same way and keep the order the
# user wrote them in. Equality between `OrderedDict`s ignores the order.
# JSON has no comments, so keys starting with `#` are comments: they are dropped at every level.
settings_dict(x) = x
settings_dict(x::Union{AbstractDict,NamedTuple}) =
    OrderedDict{Symbol,Any}(Symbol(k) => settings_dict(v) for (k, v) in pairs(x) if !startswith(String(k), "#"))

# Validate the settings of `case_settings.json`, fill in their defaults and return them.
# Deprecated keys and values are translated first; the algorithm names become types last.
function configure_settings(settings::Union{AbstractDict,NamedTuple})::NamedTuple
    raw = translate_deprecated_settings(settings)
    translate_deprecated_solution_algorithm!(raw)
    resolved = resolve_inputs(settings_spec(), raw)
    set_numeric_types!(resolved)
    set_solution_algorithm!(resolved)
    set_expansion_horizon!(resolved)
    isa(resolved[:SolutionAlgorithm], Benders) && configure_benders!(resolved)
    isa(resolved[:ExpansionHorizon], Myopic) && configure_myopic!(resolved)
    return namedtuple(resolved)
end

# JSON does not distinguish 0 from 0.0, but the model needs these exact types (see economics.jl)
function set_numeric_types!(settings::AbstractDict{Symbol,Any})
    settings[:PeriodLengths] = Int.(settings[:PeriodLengths])
    settings[:DiscountRate] = Float64(settings[:DiscountRate])
    settings[:ParameterScalingFactor] = Float64(settings[:ParameterScalingFactor])
    return nothing
end

function translate_deprecated_solution_algorithm!(settings::AbstractDict{Symbol,Any})
    if get(settings, :SolutionAlgorithm, nothing) == "Myopic"
        @warn("""
        Setting SolutionAlgorithm to \"Myopic\" is deprecated.
        Use ExpansionHorizon: "Myopic" combined with SolutionAlgorithm: "Monolithic" instead.
        Translating automatically: SolutionAlgorithm => Monolithic, ExpansionHorizon => Myopic.
        """)
        settings[:SolutionAlgorithm] = "Monolithic"
        settings[:ExpansionHorizon] = "Myopic"
    end
    return nothing
end

function set_solution_algorithm!(settings::AbstractDict{Symbol,Any})
    settings[:SolutionAlgorithm] = settings[:SolutionAlgorithm] == "Benders" ? Benders() : Monolithic()
    return nothing
end

function set_expansion_horizon!(settings::AbstractDict{Symbol,Any})
    settings[:ExpansionHorizon] = settings[:ExpansionHorizon] == "Myopic" ? Myopic() : PerfectForesight()
    return nothing
end

function configure_benders!(settings::AbstractDict{Symbol,Any})
    # use default benders settings if BendersSettings is not specified
    benders_settings = something(settings[:BendersSettings], Dict{Symbol,Any}())
    isempty(benders_settings) && @warn("No benders settings specified, using default settings")
    @info("Configuring benders")
    resolved = resolve_inputs(benders_settings_spec(), benders_settings; path="case_settings.BendersSettings")
    resolved[:ConvTol] = Float64(resolved[:ConvTol])
    resolved[:StabParam] = Float64(resolved[:StabParam])
    settings[:BendersSettings] = resolved
    return nothing
end

function configure_myopic!(settings::AbstractDict{Symbol,Any})
    # use default myopic settings if MyopicSettings is not specified
    myopic_settings = something(settings[:MyopicSettings], Dict{Symbol,Any}())
    isempty(myopic_settings) && @warn("No myopic settings specified, using default settings")
    @info("Configuring myopic")
    resolved = resolve_inputs(myopic_settings_spec(), myopic_settings; path="case_settings.MyopicSettings")
    resolved[:StopAfterPeriod] = Float64(resolved[:StopAfterPeriod])
    settings[:MyopicSettings] = resolved
    return nothing
end

"""
    translate_deprecated_settings(settings)::OrderedDict{Symbol,Any}

Return a copy of `settings` (a dictionary or `NamedTuple`) in which each renamed key is moved
to the key path that replaces it, with a deprecation warning. For example, `OutputDir` becomes
`OutputSettings.Dir`, `WriteFullTimeseries` becomes `OutputSettings.Write.FullTimeseries` and
`DualExportsEnabled` becomes `OutputSettings.Write.Duals` (see `DEPRECATED_SETTINGS`).

Setting a deprecated key and its replacement to different values is an error.
"""
function translate_deprecated_settings(settings)::OrderedDict{Symbol,Any}
    translated = drop_unset_deprecated_settings!(settings_dict(settings))
    found = [old for old in keys(DEPRECATED_SETTINGS) if haskey(translated, old)]
    isempty(found) && return translated
    for old in found
        move_setting!(translated, old, DEPRECATED_SETTINGS[old])
    end
    renames = join(["$old → $(join(DEPRECATED_SETTINGS[old], "."))" for old in found], ", ")
    @warn("""
    These settings are deprecated and were translated automatically: $renames.
    Use the new names in case_settings.json. MacroEnergy.migrate_settings("path/to/case") shows how.""", maxlog=1)
    return translated
end

# A deprecated key set to null is not set: older versions wrote that in their settings template
function drop_unset_deprecated_settings!(settings::OrderedDict{Symbol,Any})::OrderedDict{Symbol,Any}
    for old in keys(DEPRECATED_SETTINGS)
        haskey(settings, old) && isnothing(settings[old]) && delete!(settings, old)
    end
    return settings
end

function move_setting!(settings::OrderedDict{Symbol,Any}, old::Symbol, path::Tuple)
    value = pop!(settings, old)
    parent = settings
    for (depth, key) in enumerate(path[1:end-1])
        parent = get!(() -> OrderedDict{Symbol,Any}(), parent, key)
        parent isa AbstractDict || throw(InputValidationError("case_settings.$(join(path[1:depth], "."))",
            "expected an object, got $(repr(parent))"))
    end
    leaf = last(path)
    # An old default next to a new per-output map says nothing: older templates wrote every default
    spec = length(path) == 2 ? input_spec(output_settings_spec(), leaf) : nothing
    get(parent, leaf, nothing) isa AbstractDict && spec isa InputMap && isequal(value, spec.default) && return nothing
    combine_setting!(parent, leaf, value, join(path, ".")) do conflict, existing, _
        throw(InputValidationError("case_settings.$old",
            "conflicts with $conflict = $(repr(existing)). $old is deprecated: remove it and keep $(join(path, "."))"))
    end
    return nothing
end

# Set `key` in `target`, or combine `value` with what is already there: objects are combined key by
# key, and any other values must agree. `on_conflict` gets the key path and the two values.
function combine_setting!(on_conflict::Function, target::AbstractDict, key::Symbol, value, path::AbstractString)
    if !haskey(target, key)
        target[key] = value
    elseif target[key] isa AbstractDict && value isa AbstractDict
        for (entry, entry_value) in value
            combine_setting!(on_conflict, target[key], entry, entry_value, "$path.$entry")
        end
    elseif !isequal(target[key], value)
        on_conflict(path, target[key], value)
    end
    return nothing
end
