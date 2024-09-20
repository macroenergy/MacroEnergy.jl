function process_data(data::AbstractDict{Symbol,Any})
    if isa(data, JSON3.Object)
        data = copy(data) # this makes sure that data is a mutable object
    end
    validate_data(data)
    check_and_convert_inf!(data)
    check_and_convert_symbol!(data, :startup_fuel_balance_id)
    haskey(data, :demand) && check_and_convert_demand!(data)
    haskey(data, :constraints) && check_and_convert_constraints!(data)
    haskey(data, :rhs_policy) && check_and_convert_rhs_policy!(data)
    haskey(data, :price_unmet_policy) && check_and_convert_price_unmet_policy!(data)
    return data
end

function validate_id!(data::AbstractDict{Symbol,Any})
    if !haskey(data, :id)
        throw(ArgumentError("Assets/nodes must have an id."))
    end
    return nothing
end

function validate_constraints_data!(data::AbstractDict{Symbol,Any})
    valid_constraints = keys(constraint_types())
    constraints = get(data, :constraints, Dict{Symbol,Bool}())

    invalid_constraints = setdiff(keys(constraints), valid_constraints)
    if !isempty(invalid_constraints)
        throw(
            ArgumentError(
                "Invalid constraint(s) found: $(join(invalid_constraints, ", "))",
            ),
        )
    end
    return nothing
end

function validate_type_attribute(asset_type::Symbol, m::Module = Macro)
    if !isdefined(m, asset_type)
        throw(ArgumentError("Type $(asset_type) not found in module $m"))
    end
    return nothing
end

function validate_data(data::AbstractDict{Symbol,Any})
    # validate_id!(data)
    validate_constraints_data!(data)
    return nothing
end

function convert_inf_string_to_value(data::AbstractDict{Symbol,Any}, key::Symbol)
    data[key] = get(data, key, "Inf")
    if data[key] == "Inf"
        data[key] = Inf
    end
    return nothing
end

function check_and_convert_inf!(data::AbstractDict{Symbol,Any})
    convert_inf_string_to_value(data, :max_line_reinforcement)
    convert_inf_string_to_value(data, :max_capacity)
    convert_inf_string_to_value(data, :max_capacity_storage)
    return nothing
end

function check_and_convert_demand!(data::AbstractDict{Symbol,Any})
    data[:demand] = Float64.(data[:demand])
end

function check_and_convert_constraints!(data::AbstractDict{Symbol,Any})
    contraint_library = constraint_types()
    constraints = Vector{AbstractTypeConstraint}()
    for (name, flag) in data[:constraints]
        if flag == true
            push!(constraints, contraint_library[name]()) # Note: This is a constructor call, not a type (e.g., BalanceConstraint())
        end
    end
    data[:constraints] = constraints
    return nothing
end

function check_and_convert_rhs_policy!(data::AbstractDict{Symbol,Any})
    rhs_policy = Dict{DataType,Float64}()
    constraints = constraint_types()
    for (k, v) in data[:rhs_policy]
        new_k = constraints[Symbol(k)]
        rhs_policy[new_k] = v
    end
    data[:rhs_policy] = rhs_policy
    return nothing
end

function check_and_convert_price_unmet_policy!(data::AbstractDict{Symbol,Any})
    price_unmet_policy = Dict{DataType,Float64}()
    constraints = constraint_types()
    for (k, v) in data[:price_unmet_policy]
        new_k = constraints[Symbol(k)]
        price_unmet_policy[new_k] = v
    end
    data[:price_unmet_policy] = price_unmet_policy
    return nothing
end

function check_and_convert_symbol!(data::AbstractDict{Symbol,Any}, key::Symbol)
    if haskey(data, key) && isa(data[key], AbstractString)
        data[key] = Symbol(data[key])
    end
    return nothing
end