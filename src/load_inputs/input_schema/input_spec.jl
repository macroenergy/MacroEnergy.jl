###### ###### ###### ###### ###### ###### ###### ###### ###### ###### ###### ###### ######
# Declarative input specs: fields, maps and blocks
#
# A spec describes what a valid input looks like: the accepted keys, their types,
# allowed values, bounds and defaults. Constraints are stored as data so that the same 
# spec can later be exported to JSON Schema or to the docs. Nothing in this file is 
# specific to settings.
###### ###### ###### ###### ###### ###### ###### ###### ###### ###### ###### ###### ######

"""
    InputValidationError(path::String, msg::String)

Error thrown when an input does not match its spec. `path` is the full key path of the invalid value
(e.g., `"case_settings.BendersSettings.MaxIter"`) and `msg` says what was expected.
"""
struct InputValidationError <: Exception
    path::String
    msg::String
end

Base.showerror(io::IO, e::InputValidationError) = print(io, "InputValidationError: ", e.path, ": ", e.msg)

abstract type AbstractInputSpec end

"""
    InputField(name, type, default; eltype=nothing, enum=nothing, minimum=nothing,
               exclusive_minimum=nothing, description="")

Spec of a single input value.

- `type`: the accepted Julia type, e.g. `Bool`, `Integer`, `Real`, `String` or `Union{Nothing,Integer}`.
  `Bool` values are only accepted when `type` names `Bool` explicitly, even though `Bool <: Integer`.
- `eltype`: when set, the value must be a vector whose elements are all of this type (`type` is then ignored).
- `enum`: a tuple of allowed values.
- `minimum`, `exclusive_minimum`: numeric lower bounds. For vectors, they apply to every element.
  Non-numeric values (e.g. `nothing` or `missing`) skip the bounds.
"""
struct InputField <: AbstractInputSpec
    name::Symbol
    type::Type
    default::Any
    eltype::Union{Nothing,Type}
    enum::Union{Nothing,Tuple}
    minimum::Union{Nothing,Real}
    exclusive_minimum::Union{Nothing,Real}
    description::String
end

function InputField(name::Symbol, type::Type, default;
    eltype::Union{Nothing,Type}=nothing,
    enum::Union{Nothing,Tuple}=nothing,
    minimum::Union{Nothing,Real}=nothing,
    exclusive_minimum::Union{Nothing,Real}=nothing,
    description::AbstractString="",
)
    return InputField(name, type, default, eltype, enum, minimum, exclusive_minimum, String(description))
end

"""
    InputMap(name, keys, type, default; entry_default, key_defaults=(;), allow_scalar=false,
             description="", eltype=nothing, enum=nothing, minimum=nothing, exclusive_minimum=nothing)

Spec of an input that is an object keyed by a fixed set of names (`keys`), where every entry
has the same `type` and rules (`eltype`, `enum`, `minimum`, `exclusive_minimum`, as in
`InputField`). With `allow_scalar=true`, a single value is also accepted and applies to every key.

- `default`: the value of the input when it is absent.
- `entry_default`: the value of a key that is missing from the user's object.
- `key_defaults`: per-key exceptions to `entry_default`, e.g. `(FullTimeseries=false,)`.

The user's object is kept as given: missing keys are not filled in. Use `map_entry` to read
the value of one key.

# Examples
```julia
# Keys can be Flow or StorageLevel. Accepts either one format for both:
#     "Format": "parquet"
# or a format per key, where a key that is not listed gets `entry_default`:
#     "Format": {"Flow": "parquet"}      (StorageLevel is "csv")
InputMap(:Format, (:Flow, :StorageLevel), String, "csv";
         entry_default="csv", enum=("csv", "csv.gz", "parquet"), allow_scalar=true)
```
"""
struct InputMap <: AbstractInputSpec
    name::Symbol
    keys::Tuple{Vararg{Symbol}}
    entry::InputField
    key_defaults::NamedTuple
    default::Any
    allow_scalar::Bool
    description::String
end

function InputMap(name::Symbol, keys::Tuple{Vararg{Symbol}}, type::Type, default;
    entry_default,
    key_defaults::NamedTuple=(;),
    allow_scalar::Bool=false,
    description::AbstractString="",
    rules...,
)
    unknown = setdiff(Base.keys(key_defaults), keys)
    isempty(unknown) || throw(ArgumentError("key_defaults of $name has unknown key(s) $(join(unknown, ", "))"))
    entry = InputField(name, type, entry_default; rules...)
    return InputMap(name, keys, entry, key_defaults, default, allow_scalar, String(description))
end

"""
    map_entry(map::InputMap, value, key::Symbol)

Return the value of `key` in `value`, an input described by `map`: `value` itself when it is a
single value (see `allow_scalar`), its entry for `key` when it lists one, and otherwise the
default for `key` (`key_defaults`, then `entry_default`).
"""
function map_entry(map::InputMap, value, key::Symbol)
    is_object(value) || return value
    key in object_keys(value) && return value[key]
    return get(map.key_defaults, key, map.entry.default)
end

"""
    InputBlock(name, fields; additional_properties=false, check=nothing, description="")

Spec of an input object made of named `fields` (`InputField`, `InputMap` or nested `InputBlock`).

- `additional_properties`: accept keys that are not declared in `fields`.
- `check`: an optional function of the block's values that returns `nothing` when the values
  are consistent, or a message string otherwise. Use it only for rules that relate several keys.
  It runs after every declared key has been validated.
"""
struct InputBlock <: AbstractInputSpec
    name::Symbol
    fields::Vector{AbstractInputSpec}
    additional_properties::Bool
    check::Union{Nothing,Function}
    description::String
end

function InputBlock(name::Symbol, fields::AbstractVector;
    additional_properties::Bool=false,
    check::Union{Nothing,Function}=nothing,
    description::AbstractString="",
)
    return InputBlock(name, AbstractInputSpec[fields...], additional_properties, check, String(description))
end

input_name(spec::AbstractInputSpec) = spec.name

"""
    input_keys(block::InputBlock)::Tuple{Vararg{Symbol}}

Return the names of the keys declared in `block`, in declaration order.
"""
input_keys(block::InputBlock) = Tuple(input_name(f) for f in block.fields)

function input_spec(block::InputBlock, key::Symbol)::Union{Nothing,AbstractInputSpec}
    index = findfirst(f -> input_name(f) == key, block.fields)
    return isnothing(index) ? nothing : block.fields[index]
end

"""
    input_defaults(block::InputBlock)::OrderedDict{Symbol,Any}

Return the default value of every key declared in `block`, in declaration order.
Nested blocks become nested `OrderedDict`s.
"""
function input_defaults(block::InputBlock)::OrderedDict{Symbol,Any}
    return OrderedDict{Symbol,Any}(input_name(f) => default_value(f) for f in block.fields)
end
default_value(spec::Union{InputField,InputMap}) = deepcopy(spec.default)
default_value(block::InputBlock) = input_defaults(block)

is_object(x) = x isa AbstractDict || x isa NamedTuple
object_keys(x::AbstractDict) = Symbol[Symbol(k) for k in keys(x)]
object_keys(x::NamedTuple) = collect(Symbol, keys(x))
object_pairs(x::AbstractDict) = (Symbol(k) => v for (k, v) in x)
object_pairs(x::NamedTuple) = pairs(x)

"""
    merge_defaults(block::InputBlock, values)::OrderedDict{Symbol,Any}

Return `values` (a dictionary or `NamedTuple`) on top of the defaults of `block`.
Nested blocks are merged recursively. Maps and plain values given by the user replace
their defaults entirely. Undeclared keys are kept, so that `validate_inputs` can report them.
"""
function merge_defaults(block::InputBlock, values)::OrderedDict{Symbol,Any}
    merged = input_defaults(block)
    for (key, value) in object_pairs(values)
        spec = input_spec(block, key)
        merged[key] = spec isa InputBlock && is_object(value) ? merge_defaults(spec, value) : value
    end
    return merged
end

"""
    validate_inputs(block::InputBlock, values; path=String(block.name))::Nothing

Check `values` (a dictionary or `NamedTuple`) against `block`, and throw an
`InputValidationError` naming the full key path of the first problem found.
Keys declared in `block` but absent from `values` are not checked.
"""
function validate_inputs(block::InputBlock, values; path::AbstractString=String(block.name))::Nothing
    is_object(values) || throw(InputValidationError(path, "expected an object, got $(repr(values))"))
    if !block.additional_properties
        unknown = setdiff(object_keys(values), input_keys(block))
        isempty(unknown) || throw(InputValidationError(path,
            "unknown key(s) $(join(unknown, ", ")). Valid keys are: $(join(input_keys(block), ", "))"))
    end
    for (key, value) in object_pairs(values)
        spec = input_spec(block, key)
        isnothing(spec) || validate_value(spec, value, "$path.$key")
    end
    if !isnothing(block.check)
        msg = block.check(values)
        isnothing(msg) || throw(InputValidationError(path, msg))
    end
    return nothing
end

"""
    resolve_inputs(block::InputBlock, values; path=String(block.name))::OrderedDict{Symbol,Any}

Merge `values` on top of the defaults of `block` (see `merge_defaults`), validate the
result (see `validate_inputs`) and return it.
"""
function resolve_inputs(block::InputBlock, values; path::AbstractString=String(block.name))::OrderedDict{Symbol,Any}
    merged = merge_defaults(block, values)
    validate_inputs(block, merged; path)
    return merged
end

validate_value(block::InputBlock, value, path::AbstractString) = validate_inputs(block, value; path)

function validate_value(map::InputMap, value, path::AbstractString)::Nothing
    if is_object(value)
        unknown = setdiff(object_keys(value), map.keys)
        isempty(unknown) || throw(InputValidationError(path,
            "unknown key(s) $(join(unknown, ", ")). Valid keys are: $(join(map.keys, ", "))"))
        for (key, item) in object_pairs(value)
            validate_value(map.entry, item, "$path.$key")
        end
    elseif map.allow_scalar
        validate_value(map.entry, value, path)
    else
        throw(InputValidationError(path, "expected an object with keys among $(join(map.keys, ", ")), got $(repr(value))"))
    end
    return nothing
end

function validate_value(field::InputField, value, path::AbstractString)::Nothing
    valid = if isnothing(field.eltype)
        accepts_value(field, value, field.type)
    else
        value isa AbstractVector && all(x -> accepts_value(field, x, field.eltype), value)
    end
    valid || throw(InputValidationError(path, "expected $(describe_input(field)), got $(repr(value))"))
    return nothing
end

accepts_value(field::InputField, value, type::Type) =
    matches_type(value, type) && within_enum(field, value) && within_bounds(field, value)

# Bool <: Integer in Julia, but a JSON `true` is not a number: only accept it where Bool is named
function matches_type(value, type::Type)
    value isa type || return false
    value isa Bool && return names_bool(type)
    return true
end
names_bool(type::Type) = type === Bool || (type isa Union && any(names_bool, Base.uniontypes(type)))

within_enum(field::InputField, value) = isnothing(field.enum) || any(isequal(value), field.enum)

function within_bounds(field::InputField, value)
    value isa Real || return true
    !isnothing(field.minimum) && value < field.minimum && return false
    !isnothing(field.exclusive_minimum) && value <= field.exclusive_minimum && return false
    return true
end

# Short description of the values `field` accepts, used in error messages
function describe_input(field::InputField)::String
    isnothing(field.enum) || return "one of " * join(repr.(field.enum), ", ")
    base = isnothing(field.eltype) ? describe_type(field.type) :
        "a list of $(describe_type(field.eltype; plural=true))"
    bounds = String[]
    isnothing(field.minimum) || push!(bounds, "≥ $(field.minimum)")
    isnothing(field.exclusive_minimum) || push!(bounds, "> $(field.exclusive_minimum)")
    return isempty(bounds) ? base : "$base $(join(bounds, " and "))"
end

function describe_type(type::Type; plural::Bool=false)::String
    if type isa Union
        parts = [t for t in Base.uniontypes(type) if t !== Missing]
        return join([t === Nothing ? "null" : describe_type(t; plural) for t in parts], " or ")
    end
    type === Bool && return "true or false"
    type <: Integer && return plural ? "integers" : "an integer"
    type <: Real && return plural ? "numbers" : "a number"
    type <: AbstractString && return plural ? "strings" : "a string"
    type <: AbstractDict && return plural ? "objects" : "an object"
    return plural ? "values of type $type" : "a value of type $type"
end
