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
    set_period_lengths!(resolved)
    set_solution_algorithm!(resolved)
    set_expansion_horizon!(resolved)
    isa(resolved[:SolutionAlgorithm], Benders) && configure_benders!(resolved)
    isa(resolved[:ExpansionHorizon], Myopic) && configure_myopic!(resolved)
    return namedtuple(resolved)
end

function set_period_lengths!(settings::AbstractDict{Symbol,Any})
    settings[:PeriodLengths] = copy(settings[:PeriodLengths])
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
    settings[:BendersSettings] = resolve_inputs(benders_settings_spec(), benders_settings;
        path="case_settings.BendersSettings")
    return nothing
end

function configure_myopic!(settings::AbstractDict{Symbol,Any})
    # use default myopic settings if MyopicSettings is not specified
    myopic_settings = something(settings[:MyopicSettings], Dict{Symbol,Any}())
    isempty(myopic_settings) && @warn("No myopic settings specified, using default settings")
    @info("Configuring myopic")
    settings[:MyopicSettings] = resolve_inputs(myopic_settings_spec(), myopic_settings;
        path="case_settings.MyopicSettings")
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
    translated = settings_dict(settings)
    found = [old for old in keys(DEPRECATED_SETTINGS) if haskey(translated, old)]
    isempty(found) && return translated
    for old in found
        move_setting!(translated, old, DEPRECATED_SETTINGS[old])
    end
    renames = join(["$old → $(join(DEPRECATED_SETTINGS[old], "."))" for old in found], ", ")
    @warn("""
    These settings are deprecated and were translated automatically: $renames.
    Use the new names in case_settings.json.""", maxlog=1)
    return translated
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
    if haskey(parent, leaf) && !isequal(parent[leaf], value)
        throw(InputValidationError("case_settings.$old",
            "conflicts with $(join(path, ".")) = $(repr(parent[leaf])). $old is deprecated: remove it and keep $(join(path, "."))"))
    end
    parent[leaf] = value
    return nothing
end
