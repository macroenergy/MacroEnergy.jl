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
# Configured settings hold the solution algorithm and expansion horizon as objects. Back to their
# names, so that configured settings can be configured again (e.g., after a `merge` in Julia).
settings_dict(x::Union{AbstractSolutionAlgorithm,AbstractExpansionHorizon}) = setting_to_json(x)

# Validate the settings of `case_settings.json`, fill in their defaults and return them.
# Deprecated keys and values are translated first; the algorithm names become types last.
# With `num_periods`, `PeriodLengths` must also have one length per period. Every invalid
# setting found is listed in one `InputValidationError`.
function configure_settings(settings::Union{AbstractDict,NamedTuple}; num_periods::Union{Nothing,Int}=nothing)::NamedTuple
    raw = translate_deprecated_settings(settings)
    translate_deprecated_solution_algorithm!(raw)
    resolved = merge_defaults(settings_spec(), raw)
    invalid = invalid_settings(resolved)
    isnothing(num_periods) || add_invalid_period_count!(invalid, raw, num_periods)
    isempty(invalid) || throw(InputValidationError(invalid))
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

# The invalid settings in `settings`, the settings of case_settings.json with their defaults
# filled in, as key path => message pairs. Empty if they are all valid.
# The Benders and Myopic settings are checked when they are used: if `SolutionAlgorithm` or
# `ExpansionHorizon` is itself invalid, it is not known whether they are.
function invalid_settings(settings::AbstractDict{Symbol,Any})::Vector{Pair{String,String}}
    invalid = invalid_inputs(settings_spec(), settings, "case_settings")
    for (key, spec, used) in (
        (:BendersSettings, benders_settings_spec(), isequal(settings[:SolutionAlgorithm], "Benders")),
        (:MyopicSettings, myopic_settings_spec(), isequal(settings[:ExpansionHorizon], "Myopic")),
    )
        values = something(settings[key], Dict{Symbol,Any}())
        # A value that is not an object is already reported, as an invalid `key`
        used && is_keyed(values) && add_invalid_inputs!(invalid, spec, merge_defaults(spec, values), "case_settings.$key")
    end
    return invalid
end

# A case needs one period length per period (System). Checked by `load_case`, and by
# `migrate_settings` before it writes anything. `settings` are the settings as written, without
# their defaults, so that a missing `PeriodLengths` can be named as such.
function add_invalid_period_count!(invalid::Vector{Pair{String,String}}, settings::AbstractDict{Symbol,Any}, num_periods::Int)
    periods = num_periods == 1 ? "1 period" : "$num_periods periods"
    if !haskey(settings, :PeriodLengths)
        num_periods == 1 || push!(invalid, "case_settings.PeriodLengths" =>
            "is not set, so the case would have one 1-year period, but it has $periods. Give one length per period.")
        return invalid
    end
    lengths = settings[:PeriodLengths]
    # A value that is not a list, null included, is already reported as an invalid PeriodLengths
    if lengths isa AbstractVector && length(lengths) != num_periods
        given = length(lengths) == 1 ? "1 length" : "$(length(lengths)) lengths"
        push!(invalid, "case_settings.PeriodLengths" =>
            "has $given, but the case has $periods. Give one length per period.")
    end
    return invalid
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
