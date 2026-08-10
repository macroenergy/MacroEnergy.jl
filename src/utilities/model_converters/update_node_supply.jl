function update_node_supply_inputs(
    file_path::AbstractString;
    output_path::Union{Nothing,AbstractString}=nothing,
)
    data = copy(read_json(file_path)) # This converts JSON3 -> Dict{Symbol,Any}
    if !isa(data, AbstractDict{Symbol,Any})
        throw(ArgumentError("Expected a JSON object at the top level of $(file_path)"))
    end

    # In theory, the Nodes file can have multiple entries
    for (group_name, node_group) in data
        data[group_name] = update_node_supply_inputs(node_group)
    end

    destination = isnothing(output_path) ? file_path : output_path
    write_json(destination, data)

    println("Updated node supply schema in $(file_path) and saved to $(destination)")
    println(" ++ This update script does not modify BalanceConstraint inputs. ++
    BalanceConstraint are now added to all Nodes by default.
    If you have an infinite sink (e.g. a co2_sink) or source (e.g. an uncosted fuel source), 
    then you must set constraints: {BalanceConstraint : false} in the input
    ")
    return destination
end

function update_node_supply_inputs(data::AbstractDict{Symbol,Any})
    if !haskey(data, :type) || !haskey(data, :instance_data)
        return data
    end

    if isa(data[:instance_data], AbstractDict{Symbol,Any})
        convert_node_supply_schema!(data[:instance_data])
    else
        convert_node_supply_schema!.(data[:instance_data])
    end

    if haskey(data, :global_data)
        convert_node_supply_schema!(data[:global_data])
    end
    return data
end

function update_node_supply_inputs(data::Vector{Dict{Symbol,Any}})
    for (idx, node) in enumerate(data)
        if isa(node, AbstractDict{Symbol,Any})
            data[idx] = update_node_supply_inputs(node)
        end
    end
    return data
end

function update_node_supply_inputs(data)
    @warn("Unexpected data format for $(data). Skipping conversion.")
    return data
end

function convert_node_supply_schema!(data::AbstractDict{Symbol,Any})
    convert_price_2_supply_schema!(data)

    if haskey(data, :price_supply)
        convert_legacy_supply_to_new_schema!(data)
        remove_legacy_supply_schema!(data)
    elseif haskey(data, :supply)
        remove_legacy_supply_schema!(data)
    end
    return nothing
end

function convert_legacy_supply_to_new_schema!(data::AbstractDict{Symbol,Any})
    price_supply = asnothing(get(data, :price_supply, nothing))
    min_supply = asnothing(get(data, :min_supply, nothing))
    max_supply = asnothing(get(data, :max_supply, nothing))
    supply_segment_names = asnothing(get(data, :supply_segment_names, nothing))

    if isnothing(price_supply)
        data[:supply] = OrderedDict{Symbol,Any}()
        return nothing
    end

    supply_segment_names = parse_raw_supply_names(price_supply, max_supply, supply_segment_names)
    price_supply, max_supply, supply_segment_names = parse_raw_supply(price_supply, max_supply, supply_segment_names)
    min_supply = normalize_raw_min_supply(min_supply, supply_segment_names)
    validate_raw_min_max_supply!(min_supply, max_supply)

    data[:supply] = OrderedDict{Symbol,Any}(
        segment_name => OrderedDict(
            :price => price_supply[segment_name],
            :min => min_supply[segment_name],
            :max => max_supply[segment_name],
        ) for segment_name in supply_segment_names
    )
    return nothing
end

function raw_supply_value(value)
    if isa(value, Number)
        return [Float64(value)]
    elseif isa(value, AbstractVector)
        return Float64.(value)
    elseif isa(value, AbstractDict)
        return copy(value)
    end

    throw(ArgumentError("Unexpected legacy supply value type $(typeof(value))."))
end

function raw_supply_value(dict::AbstractDict, key::Symbol, default)
    if haskey(dict, key)
        return raw_supply_value(dict[key])
    elseif haskey(dict, String(key))
        return raw_supply_value(dict[String(key)])
    end

    return raw_supply_value(default)
end

function parse_raw_supply_names(price_supply, max_supply, supply_segment_names)
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

function parse_raw_supply(price_supply, max_supply::Nothing, supply_segment_names::Vector{Symbol})
    if length(supply_segment_names) != 1
        throw(ArgumentError("If max_supply is not defined then exactly one supply segment name must be supplied or inferred. Current input is: $(supply_segment_names)"))
    end

    segment_name = supply_segment_names[1]
    if !(isa(price_supply, AbstractDict) || isa(price_supply, AbstractVector) || isa(price_supply, Number))
        throw(ArgumentError("price_supply must be either a number, vector, or dictionary. Current input is: $(typeof(price_supply))"))
    end

    if isa(price_supply, AbstractVector) || isa(price_supply, Number)
        price_supply_dict = OrderedDict{Symbol,Any}(segment_name => raw_supply_value(price_supply))
    elseif isa(price_supply, AbstractDict) && length(price_supply) == 1
        price_supply_dict = OrderedDict{Symbol,Any}(Symbol(k) => raw_supply_value(v) for (k, v) in price_supply)
    else
        throw(ArgumentError("If max_supply is not defined then we will assume that the supply has only one segment. In that case, the price_supply must be either a vector, a scalar, or a single-segment dictionary. Define more segment maxes if needed. Current input is: $(typeof(price_supply))"))
    end

    return (
        price_supply_dict,
        OrderedDict{Symbol,Any}(segment_name => [Inf]),
        [segment_name],
    )
end

function parse_raw_supply(price_supply::AbstractVector, max_supply::AbstractVector, supply_segment_names::Vector{Symbol})
    if length(price_supply) != length(max_supply)
        throw(ArgumentError("Length of price_supply vector must match length of max_supply vector. Current inputs are $(price_supply) and $(max_supply)"))
    end

    if length(supply_segment_names) < length(price_supply)
        supply_segment_names = vcat(supply_segment_names, default_segment_names(length(price_supply) - length(supply_segment_names)))
    elseif length(supply_segment_names) > length(price_supply)
        supply_segment_names = supply_segment_names[1:length(price_supply)]
    end

    price_supply_dict = OrderedDict{Symbol,Any}()
    max_supply_dict = OrderedDict{Symbol,Any}()
    for (i, segment_name) in enumerate(supply_segment_names)
        price_supply_dict[segment_name] = raw_supply_value(price_supply[i])
        max_supply_dict[segment_name] = raw_supply_value(max_supply[i])
    end
    return price_supply_dict, max_supply_dict, supply_segment_names
end

function parse_raw_supply(price_supply::AbstractVector, max_supply::AbstractDict, supply_segment_names::Vector{Symbol})
    if length(price_supply) != length(max_supply)
        throw(ArgumentError("Length of price_supply vector must match length of max_supply vector. Current inputs are $(price_supply) and $(max_supply)"))
    end

    price_supply_dict = OrderedDict{Symbol,Any}()
    for (i, segment_name) in enumerate(supply_segment_names)
        price_supply_dict[segment_name] = raw_supply_value(price_supply[i])
    end

    max_supply_dict = OrderedDict{Symbol,Any}()
    for (k, v) in max_supply
        max_supply_dict[Symbol(k)] = raw_supply_value(v)
    end
    return price_supply_dict, max_supply_dict, supply_segment_names
end

function parse_raw_supply(price_supply::AbstractDict, max_supply::AbstractVector, supply_segment_names::Vector{Symbol})
    if length(price_supply) != length(max_supply)
        throw(ArgumentError("Length of price_supply vector must match length of max_supply vector. Current inputs are $(price_supply) and $(max_supply)"))
    end

    price_supply_dict = OrderedDict{Symbol,Any}(Symbol(k) => raw_supply_value(v) for (k, v) in price_supply)
    max_supply_dict = OrderedDict{Symbol,Any}()
    for (i, segment_name) in enumerate(supply_segment_names)
        max_supply_dict[segment_name] = raw_supply_value(max_supply[i])
    end
    return price_supply_dict, max_supply_dict, supply_segment_names
end

function parse_raw_supply(price_supply::AbstractDict, max_supply::AbstractDict, supply_segment_names::Vector{Symbol})
    if length(price_supply) != length(max_supply)
        throw(ArgumentError("Length of price_supply vector must match length of max_supply vector. Current inputs are $(price_supply) and $(max_supply)"))
    end

    price_supply_dict = OrderedDict{Symbol,Any}(Symbol(k) => raw_supply_value(v) for (k, v) in price_supply)
    max_supply_dict = OrderedDict{Symbol,Any}(Symbol(k) => raw_supply_value(v) for (k, v) in max_supply)
    return price_supply_dict, max_supply_dict, supply_segment_names
end

function normalize_raw_min_supply(min_supply::Nothing, supply_segment_names::Vector{Symbol})
    return OrderedDict{Symbol,Any}(segment_name => [0.0] for segment_name in supply_segment_names)
end

function normalize_raw_min_supply(min_supply::AbstractVector, supply_segment_names::Vector{Symbol})
    throw(ArgumentError("min_supply must be provided as a dictionary keyed by supply segment names. Vector inputs are not supported."))
end

function normalize_raw_min_supply(min_supply::AbstractDict, supply_segment_names::Vector{Symbol})
    normalized_min_supply = OrderedDict{Symbol,Any}()

    segment_names_set = Set(supply_segment_names)
    for k in keys(min_supply)
        segment_name = Symbol(k)
        if !(segment_name in segment_names_set)
            throw(ArgumentError("min_supply contains segment $(segment_name), which is not present in supply_segment_names."))
        end
    end

    for segment_name in supply_segment_names
        normalized_min_supply[segment_name] = raw_supply_value(min_supply, segment_name, 0.0)
    end
    return normalized_min_supply
end

is_numeric_supply_value(value::Number) = true
is_numeric_supply_value(value::AbstractVector) = all(x -> isa(x, Number), value)
is_numeric_supply_value(value) = false

function validate_raw_min_max_supply!(min_supply::OrderedDict{Symbol,Any}, max_supply::OrderedDict{Symbol,Any})
    for (segment_name, min_values) in min_supply
        if !haskey(max_supply, segment_name)
            throw(ArgumentError("Segment $(segment_name) exists in min_supply but not in max_supply."))
        end

        max_values = max_supply[segment_name]
        if !(is_numeric_supply_value(min_values) && is_numeric_supply_value(max_values))
            continue
        end

        min_values_vec = Float64.(min_values)
        max_values_vec = Float64.(max_values)

        if length(min_values_vec) > 1 && length(max_values_vec) > 1 && length(min_values_vec) != length(max_values_vec)
            throw(ArgumentError("min_supply and max_supply time series lengths must match when both are time-varying for segment $(segment_name). Found lengths $(length(min_values_vec)) and $(length(max_values_vec))."))
        end

        comparison_length = max(length(min_values_vec), length(max_values_vec))
        expanded_min_values = expand_supply_values(min_values_vec, comparison_length)
        expanded_max_values = expand_supply_values(max_values_vec, comparison_length)

        if any(expanded_min_values .> expanded_max_values)
            failing_step = findfirst(expanded_min_values .> expanded_max_values)
            throw(ArgumentError("min_supply must be <= max_supply for all segments and time steps. Segment $(segment_name), step $(failing_step) has min $(expanded_min_values[failing_step]) > max $(expanded_max_values[failing_step])."))
        end
    end
    return nothing
end

function remove_legacy_supply_schema!(data::AbstractDict{Symbol,Any})
    for key in (:price_supply, :min_supply, :max_supply, :supply_segment_names)
        if haskey(data, key)
            delete!(data, key)
        end
    end
    return nothing
end

function convert_price_2_supply_schema!(data::AbstractDict{Symbol,Any}; max_print_length::Int=5)
    if haskey(data, :price)
        price_data = data[:price]
        if haskey(data, :price_supply) || haskey(data, :supply)
            if length(price_data) > max_print_length
                price_preview = string(price_data[1:max_print_length], "...")
            else
                price_preview = string(price_data)
            end
            @warn("Data has both :price and an existing supply schema. :price = $(price_preview). This entry will be skipped to avoid overwriting existing supply data.")
            return nothing
        end
        data[:supply] = OrderedDict(
            :segment1 => OrderedDict(
                :price => raw_supply_value(data[:price]),
                :min => [0.0],
                :max => [Inf],
            ),
        )
        delete!(data, :price)
    end
    return nothing
end
