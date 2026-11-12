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
