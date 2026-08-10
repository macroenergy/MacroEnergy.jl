"""
    check_and_convert_supply!(data)

Normalize user inputs related to supply into `OrderedDict{Symbol,SupplySegment}`. This function serves as a wrapper that dispatches to either the legacy or typed parser based on the presence of certain keys in the input data dictionary.

"""
function check_and_convert_supply!(data)
    if haskey(data, :price_supply)
        @info("Using legacy parser for supply inputs of $(get(data, :id, :unknown)).")
        return check_and_convert_supply_legacy!(data)
    elseif haskey(data, :supply)
        return check_and_convert_supply_typed!(data)
    end
    return nothing
end

"""
    check_and_convert_supply_typed!(data)

Normalize the preferred node `supply` input into
`OrderedDict{Symbol,SupplySegment}`.

Expected input shape:
```julia
supply = OrderedDict(
    :cheap => Dict(:price => [1.0, 1.5], :min => [0.0], :max => [15.0]),
    :firm => Dict(:price => [4.0], :max => [5.0]),
)
```

Rules:
- each segment must define `price`
- missing `min` defaults to `[0.0]`
- missing `max` defaults to `[Inf]`
"""
function check_and_convert_supply_typed!(data)
    raw_supply = asnothing(get(data, :supply, nothing))

    if isnothing(raw_supply)
        data[:supply] = OrderedDict{Symbol,SupplySegment}()
        return nothing
    end

    if !(raw_supply isa AbstractDict)
        throw(ArgumentError("supply must be provided as a dictionary keyed by segment names. Current input is $(typeof(raw_supply))."))
    end

    supply = OrderedDict{Symbol,SupplySegment}()
    min_supply = OrderedDict{Symbol,Vector{Float64}}()
    max_supply = OrderedDict{Symbol,Vector{Float64}}()

    for (raw_segment_name, raw_segment) in pairs(raw_supply)
        if !(raw_segment isa AbstractDict)
            throw(ArgumentError("Each supply segment must be a dictionary containing at least a price entry. Segment $(raw_segment_name) has type $(typeof(raw_segment))."))
        end

        segment_name = Symbol(raw_segment_name)
        price = get_supply_field(raw_segment, :price, nothing)
        min = get_supply_field(raw_segment, :min, 0.0)
        max = get_supply_field(raw_segment, :max, Inf)

        if isnothing(price)
            throw(ArgumentError("Supply segment $(segment_name) is missing a price entry."))
        end

        price_values = as_vector(price)
        min_values = as_vector(min)
        max_values = as_vector(max)

        if any(x -> !isfinite(x), min_values)
            throw(ArgumentError("min supply must be finite for all segments and time steps. Segment $(segment_name) has non-finite values $(min_values)."))
        end

        supply[segment_name] = SupplySegment(
            price = price_values,
            min = min_values,
            max = max_values,
        )
        min_supply[segment_name] = min_values
        max_supply[segment_name] = max_values
    end

    validate_min_max_supply!(min_supply, max_supply)
    data[:supply] = supply
    return nothing
end

function make_supply_segments(
    price_supply::OrderedDict{Symbol,Vector{Float64}},
    min_supply::OrderedDict{Symbol,Vector{Float64}},
    max_supply::OrderedDict{Symbol,Vector{Float64}},
    supply_segment_names::Vector{Symbol},
)
    supply = OrderedDict{Symbol,SupplySegment}()
    for segment_name in supply_segment_names
        supply[segment_name] = SupplySegment(
            price = price_supply[segment_name],
            min = min_supply[segment_name],
            max = max_supply[segment_name],
        )
    end
    return supply
end

function get_supply_field(segment::AbstractDict, key::Symbol, default)
    if haskey(segment, key)
        return segment[key]
    elseif haskey(segment, String(key))
        return segment[String(key)]
    end

    return default
end

"""
    check_and_convert_supply_legacy!(data)

Normalize legacy node supply inputs into the older segmented representation:

`price_supply::OrderedDict{Symbol,Vector{Float64}}`
`min_supply::OrderedDict{Symbol,Vector{Float64}}`
`max_supply::OrderedDict{Symbol,Vector{Float64}}`
`supply_segment_names::Vector{Symbol}`

Ideally, users should provide the inputs as dictionaries with segment names and single values or time series of values.
For example:
```julia
price_supply = OrderedDict(:cheap => [1.0, 1.5], :expensive => [4.0, 6.0])
max_supply = OrderedDict(:cheap => 15.0, :expensive => 5.0)
supply_segment_names = [:cheap, :expensive]
```

However, MacroEnergy will support a variety of alternative formats for user convenience. These include:
1. Two vectors:
```julia
price_supply = [1.0, 4.0]
max_supply = [15.0, 5.0]
supply_segment_names = [:cheap, :expensive] # optional, will default to segment1, segment2, etc. if not provided
```
This will be converted to:
```julia
price_supply = OrderedDict(:cheap => [1.0], :expensive => [4.0])
max_supply = OrderedDict(:cheap => [15.0], :expensive => [5.0])
supply_segment_names = [:cheap, :expensive]
```
2. A vector or single-segment dictionary for price_supply with no max_supply:
```julia
price_supply = [1.0, 1.5] # or price_supply = OrderedDict(:gas => [1.0, 1.5])
```
This will be converted to:
```julia
price_supply = OrderedDict(:segment1 => [1.0, 1.5]) 
max_supply = OrderedDict(:segment1 => [Inf])
supply_segment_names = [:segment1] # or [:gas] if the original price_supply was a single-segment dictionary with the name "gas"
```

3. A mix of vector and dictionary inputs:
```julia
price_supply = [1.0, 1.5]
max_supply = OrderedDict(:cheap => 15.0, :expensive => 5.0)
supply_segment_names = [:cheap, :expensive]
```
This will be converted to:
```julia
price_supply = OrderedDict(:cheap => [1.0], :expensive => [1.5])
max_supply = OrderedDict(:cheap => [15.0], :expensive => [5.0])
supply_segment_names = [:cheap, :expensive]
```
Alternatively, the max_supply may be a vector and price_supply a dictionary:
```julia
price_supply = OrderedDict(:cheap => [1.0], :expensive => [1.5])
max_supply = [15.0, 5.0]
supply_segment_names = [:cheap, :expensive]
```
This will be converted to:
```julia
price_supply = OrderedDict(:cheap => [1.0], :expensive => [1.5])
max_supply = OrderedDict(:cheap => [15.0], :expensive => [5.0])
supply_segment_names = [:cheap, :expensive]
```

4. Just a price_supply vector with no max_supply:
```julia
price_supply = [1.0, 1.5]
```
This will be converted to:
```julia
price_supply = OrderedDict(:segment1 => [1.0, 1.5])
max_supply = OrderedDict(:segment1 => [Inf])
supply_segment_names = [:segment1]
```

The function will throw errors for unsupported formats, such as mismatched lengths of vectors, or if there are multiple price segments but no max_supply provided.
"""
function check_and_convert_supply_legacy!(data)
    # We'll convert inputs to nothing if they're empty,
    # making it easier to parse by type
    price_supply = asnothing(data[:price_supply])
    min_supply = asnothing(get(data, :min_supply, nothing))
    max_supply = asnothing(get(data, :max_supply, nothing))
    supply_segment_names = asnothing(get(data, :supply_segment_names, nothing))

    if isnothing(price_supply)
        # If not prices are supplied, we return empty inputs.
        data[:supply] = OrderedDict{Symbol,SupplySegment}()
        data[:price_supply] = OrderedDict{Symbol,Vector{Float64}}()
        data[:min_supply] = OrderedDict{Symbol,Vector{Float64}}()
        data[:max_supply] = OrderedDict{Symbol,Vector{Float64}}()
        data[:supply_segment_names] = Symbol[]
        return nothing
    end

    supply_segment_names = parse_supply_names(price_supply, max_supply, supply_segment_names)
    price_supply, max_supply, supply_segment_names = parse_supply(price_supply, max_supply, supply_segment_names)
    min_supply = normalize_min_supply(min_supply, supply_segment_names)
    validate_min_max_supply!(min_supply, max_supply)

    data[:price_supply] = price_supply
    data[:min_supply] = min_supply
    data[:max_supply] = max_supply
    data[:supply_segment_names] = supply_segment_names
    data[:supply] = make_supply_segments(price_supply, min_supply, max_supply, supply_segment_names)
    return nothing
end

function normalize_min_supply(min_supply::Nothing, supply_segment_names::Vector{Symbol})
    return OrderedDict{Symbol,Vector{Float64}}(
        segment_name => [0.0] for segment_name in supply_segment_names
    )
end

function normalize_min_supply(min_supply::AbstractVector, supply_segment_names::Vector{Symbol})
    throw(ArgumentError("min_supply must be provided as a dictionary keyed by supply segment names. Vector inputs are not supported."))
end

function normalize_min_supply(min_supply::AbstractDict, supply_segment_names::Vector{Symbol})
    normalized_min_supply = OrderedDict{Symbol,Vector{Float64}}()

    segment_names_set = Set(supply_segment_names)
    for k in keys(min_supply)
        segment_name = Symbol(k)
        if !(segment_name in segment_names_set)
            throw(ArgumentError("min_supply contains segment $(segment_name), which is not present in supply_segment_names."))
        end
    end

    for segment_name in supply_segment_names
        raw_value = if haskey(min_supply, segment_name)
            min_supply[segment_name]
        elseif haskey(min_supply, string(segment_name))
            min_supply[string(segment_name)]
        else
            0.0
        end

        if !(isa(raw_value, Number) || isa(raw_value, AbstractVector))
            throw(ArgumentError("min_supply values must be numbers or vectors. Current input for segment $(segment_name) is $(typeof(raw_value))."))
        end

        min_values = as_vector(raw_value)
        if any(x -> !isfinite(x), min_values)
            throw(ArgumentError("min_supply must be finite for all segments and time steps. Segment $(segment_name) has non-finite values $(min_values)."))
        end
        normalized_min_supply[segment_name] = min_values
    end

    return normalized_min_supply
end

function validate_min_max_supply!(min_supply::OrderedDict{Symbol,Vector{Float64}}, max_supply::OrderedDict{Symbol,Vector{Float64}})
    for (segment_name, min_values) in min_supply
        if !haskey(max_supply, segment_name)
            throw(ArgumentError("Segment $(segment_name) exists in min_supply but not in max_supply."))
        end
        max_values = max_supply[segment_name]

        if length(min_values) > 1 && length(max_values) > 1 && length(min_values) != length(max_values)
            throw(ArgumentError("min_supply and max_supply time series lengths must match when both are time-varying for segment $(segment_name). Found lengths $(length(min_values)) and $(length(max_values))."))
        end

        comparison_length = max(length(min_values), length(max_values))
        expanded_min_values = expand_supply_values(min_values, comparison_length)
        expanded_max_values = expand_supply_values(max_values, comparison_length)

        if any(expanded_min_values .> expanded_max_values)
            failing_step = findfirst(expanded_min_values .> expanded_max_values)
            throw(ArgumentError("min_supply must be <= max_supply for all segments and time steps. Segment $(segment_name), step $(failing_step) has min $(expanded_min_values[failing_step]) > max $(expanded_max_values[failing_step])."))
        end
    end
    return nothing
end

function expand_supply_values(values::Vector{Float64}, target_length::Int)
    if length(values) == target_length
        return values
    elseif length(values) == 1
        return fill(values[1], target_length)
    end

    throw(ArgumentError("Cannot expand supply values of length $(length(values)) to target length $(target_length)."))
end

function parse_supply_names(price_supply, max_supply, supply_segment_names)
    if price_supply isa AbstractDict
        return collect(Symbol.(keys(price_supply)))
    elseif max_supply isa AbstractDict
        return collect(Symbol.(keys(max_supply)))
    elseif supply_segment_names !== nothing
        return collect(Symbol.(supply_segment_names))
    elseif max_supply isa AbstractVector
        return default_segment_names(length(max_supply))
    else
        return default_segment_names(1)
    end
end

function parse_supply(price_supply, max_supply::Nothing, supply_segment_names::Vector{Symbol})
    if length(supply_segment_names) != 1
        throw(ArgumentError("If max_supply is not defined then exactly one supply segment name must be supplied or inferred. Current input is: $(supply_segment_names)"))
    end
    segment_name = supply_segment_names[1]
    if !(isa(price_supply, AbstractDict) || isa(price_supply, AbstractVector))
        throw(ArgumentError("price_supply must be either a vector or a dictionary. Current input is: $(typeof(price_supply))"))
    end
    if isa(price_supply, AbstractVector) || isa(price_supply, Number)
        price_supply_dict = OrderedDict{Symbol,Vector{Float64}}(
            segment_name => as_vector(price_supply)
        )
    elseif isa(price_supply, AbstractDict) && length(price_supply) == 1
        price_supply_dict = OrderedDict{Symbol,Vector{Float64}}(
            k => as_vector(v) for (k, v) in price_supply
        )
    else
        throw(ArgumentError("If max_supply is not defined then we will assume that the supply has only one segment. In that case, the price_supply must be either a vector or a single-segment dictionary. Define more segment maxes if needed. Current input is: $(typeof(price_supply))"))
    end
    return (
        price_supply_dict,
        OrderedDict{Symbol,Vector{Float64}}(
            segment_name => Float64[Inf]
        ),
        [segment_name]
    )
end

function parse_supply(price_supply::AbstractVector, max_supply::AbstractVector, supply_segment_names::Vector{Symbol})
    if length(price_supply) != length(max_supply)
        throw(ArgumentError("Length of price_supply vector must match length of max_supply vector. Current inputs are $(price_supply) and $(max_supply)"))
    end
    # Convert each entry in price_supply and max_supply into a segment with the name in supply_segment_names
    price_supply_dict = OrderedDict{Symbol,Vector{Float64}}()
    max_supply_dict = OrderedDict{Symbol,Vector{Float64}}()
    # Make sure supply_segment_names is the same length as price_supply, fill with default names if not provided, trim if too long
    if length(supply_segment_names) < length(price_supply)
        supply_segment_names = vcat(supply_segment_names, default_segment_names(length(price_supply) - length(supply_segment_names)))
    elseif length(supply_segment_names) > length(price_supply)
        supply_segment_names = supply_segment_names[1:length(price_supply)]
    end
    for (i, segment_name) in enumerate(supply_segment_names)
        price_supply_dict[segment_name] = as_vector(price_supply[i])
        max_supply_dict[segment_name] = as_vector(max_supply[i])
    end
    return price_supply_dict, max_supply_dict, supply_segment_names
end

function parse_supply(price_supply::AbstractVector, max_supply::AbstractDict, supply_segment_names::Vector{Symbol})
    if length(price_supply) != length(max_supply)
        throw(ArgumentError("Length of price_supply vector must match length of max_supply vector. Current inputs are $(price_supply) and $(max_supply)"))
    end
    # Use the entries in price_supply as the price for each segment
    price_supply_dict = OrderedDict{Symbol,Vector{Float64}}()
    for (i, segment_name) in enumerate(supply_segment_names)
        price_supply_dict[segment_name] = as_vector(price_supply[i])
    end
    # Make sure that max_supply is formatted correctly
    max_supply_dict = OrderedDict{Symbol,Vector{Float64}}()
    for (k, v) in max_supply
        if isa(v, Number) || isa(v, AbstractVector)
            max_supply_dict[k] = as_vector(v)
        else
            throw(ArgumentError("max_supply values must be either numbers or vectors. Current input for segment $(k) is: $(typeof(v))"))
        end
    end
    return price_supply_dict, max_supply_dict, supply_segment_names
end

function parse_supply(price_supply::AbstractDict, max_supply::AbstractVector, supply_segment_names::Vector{Symbol})
    if length(price_supply) != length(max_supply)
        throw(ArgumentError("Length of price_supply vector must match length of max_supply vector. Current inputs are $(price_supply) and $(max_supply)"))
    end
    # Use the entries in max_supply as the maximum supply for each segment
    max_supply_dict = OrderedDict{Symbol,Vector{Float64}}()
    for (i, segment_name) in enumerate(supply_segment_names)
        max_supply_dict[segment_name] = as_vector(max_supply[i])
    end
    return price_supply, max_supply_dict, supply_segment_names
end

function parse_supply(price_supply::AbstractDict, max_supply::AbstractDict, supply_segment_names::Vector{Symbol})
    if length(price_supply) != length(max_supply)
        throw(ArgumentError("Length of price_supply vector must match length of max_supply vector. Current inputs are $(price_supply) and $(max_supply)"))
    end
    price_supply_dict = OrderedDict{Symbol,Vector{Float64}}(
        k => as_vector(v) for (k, v) in price_supply
    )
    max_supply_dict = OrderedDict{Symbol,Vector{Float64}}(
        k => as_vector(v) for (k, v) in max_supply
    )
    return price_supply_dict, max_supply_dict, supply_segment_names
end