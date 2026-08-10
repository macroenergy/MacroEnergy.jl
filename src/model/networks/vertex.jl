"""
    @AbstractVertexBaseAttributes()

    A macro that defines the base attributes for all vertex types in the network model.

    # Generated Fields
    - id::Symbol: Unique identifier for the vertex
    - timedata::TimeData: Time-related data for the vertex
    - balance_data::Dict{Symbol,Any}: Dictionary mapping balance equation IDs to balance definitions
    - constraints::Vector{AbstractTypeConstraint}: List of constraints applied to the vertex
    - operation_expr::Dict: Dictionary storing operational JuMP expressions for the vertex

    This macro is used to ensure consistent base attributes across all vertex types in the network.
"""
macro AbstractVertexBaseAttributes()
    esc(
        quote
            id::Symbol
            timedata::TimeData
            location::Union{Missing, Symbol} = missing
            balance_data::Dict{Symbol, Any} = Dict{Symbol, Any}()
            constraints::Vector{AbstractTypeConstraint} = Vector{AbstractTypeConstraint}()
            operation_expr::Dict = Dict()
        end,
    )
end

"""
    id(v::AbstractVertex)

Get the unique identifier (ID) of a vertex.

# Arguments
- `v`: A vertex object that is a subtype of AbstractVertex (i.e., `Node`, `Storage`, `Transformation`)

# Returns
- A Symbol representing the vertex's unique identifier

# Examples
```julia
vertex_id = id(elec_node)
```
"""
id(v::AbstractVertex) = v.id

"""
    balance_ids(v::AbstractVertex)

Get the IDs of all balance equations in a vertex.

# Arguments
- `v`: A vertex object that is a subtype of AbstractVertex

# Returns
- A vector of Symbols representing the IDs of all balance equations

# Examples
```julia
balance_ids = balance_ids(elec_node)
```
"""
balance_ids(v::AbstractVertex) = collect(keys(v.balance_data))

"""
    balance_data(v::AbstractVertex, i::Symbol)

Get the normalized balance definition for a specific balance equation in a vertex.

# Arguments
- `v`: A vertex object that is a subtype of AbstractVertex
- `i`: Symbol representing the ID of the balance equation

# Returns
- A `BalanceData` object for the specified balance equation

# Examples
```julia
demand_data = balance_data(elec_node, :demand)
```
"""
function balance_data(v::AbstractVertex, i::Symbol)
    data = v.balance_data[i]
    if data isa BalanceData
        return data
    end
    normalized = normalize_balance_data(data)
    v.balance_data[i] = normalized
    return normalized
end

function normalize_balance_data!(v::AbstractVertex)
    for balance_id in keys(v.balance_data)
        data = v.balance_data[balance_id]
        if !(data isa BalanceData)
            v.balance_data[balance_id] = normalize_balance_data(data)
        end
    end
    return nothing
end

balance_sense(v::AbstractVertex, i::Symbol) = balance_data(v, i).sense
balance_terms(v::AbstractVertex, i::Symbol) = balance_data(v, i).terms

"""
    get_balance(v::AbstractVertex, i::Symbol)

Get the mathematical expression of a balance equation in a vertex.

# Arguments
- `v`: A vertex object that is a subtype of AbstractVertex
- `i`: Symbol representing the ID of the balance equation

# Returns
- The mathematical expression of the balance equation

# Examples
```julia
# Get the demand balance expression
demand_expr = get_balance(elec_node, :demand)
```
"""
get_balance(v::AbstractVertex, i::Symbol) = v.operation_expr[i]
get_balance(v::AbstractVertex, i::Symbol, t::Int64) = get_balance(v, i)[t]

"""
    all_constraints(v::AbstractVertex)

Get all constraints on a vertex.

# Arguments
- `v`: A vertex object that is a subtype of AbstractVertex

# Returns
- A vector of all constraint objects on the vertex

# Examples
```julia
constraints = all_constraints(elec_node)
```
"""
all_constraints(v::AbstractVertex) = v.constraints

"""
    all_constraints_types(v::AbstractVertex)

Get the types of all constraints on a vertex.

# Arguments
- `v`: A vertex object that is a subtype of AbstractVertex

# Returns
- A vector of types of all constraints on the vertex

# Examples
```julia
constraint_types = all_constraints_types(elec_node)
```
"""
all_constraints_types(v::AbstractVertex) = [typeof(c) for c in all_constraints(v)]

"""
    get_constraint_by_type(v::AbstractVertex, constraint_type::Type{<:AbstractTypeConstraint})

Get a constraint on a vertex by its type.

# Arguments
- `v`: A vertex object that is a subtype of AbstractVertex
- `constraint_type`: The type of constraint to find

# Returns
- If exactly one constraint of the specified type exists: returns that constraint
- If multiple constraints of the specified type exist: returns a vector of those constraints
- If no constraints of the specified type exist: returns `nothing`

# Examples
```julia
balance_constraint = get_constraint_by_type(elec_node, BalanceConstraint)
```
"""
function get_constraint_by_type(v::AbstractVertex, constraint_type::Type{<:AbstractTypeConstraint})
    constraints = all_constraints(v)
    matches = filter(c -> typeof(c) == constraint_type, constraints)
    return length(matches) == 1 ? matches[1] : length(matches) > 1 ? matches : nothing
end

location(v::AbstractVertex) = v.location;

function normalize_balance_sense(sense::Symbol)
    if sense in (:eq, :(==), :(=))
        return :eq
    elseif sense in (:le, :(<=), :(<))
        return :le
    elseif sense in (:ge, :(>=), :(>))
        return :ge
    end
    error("Unsupported balance sense: $sense")
end

function normalize_balance_data(data::BalanceData)
    return BalanceData(
        sense = normalize_balance_sense(data.sense),
        terms = data.terms,
        constant = data.constant,
    )
end

function normalize_balance_data(data::Dict{Symbol,<:Number})
    return BalanceData(
        terms = BalanceTerm[
            BalanceTerm(obj = k, var = :flow, coeff = Float64(v)) for (k, v) in data
        ],
    )
end

function normalize_balance_data(data::Vector{BalanceTerm})
    return BalanceData(terms = data)
end

function normalize_balance_data(data::AbstractVector{<:NamedTuple{(:id, :var, :coeff)}})
    constant = 0.0
    terms = BalanceTerm[]
    for term in data
        coeff = normalize_balance_coeff(term.coeff)
        if term.id == :constant
            coeff isa Vector{Float64} &&
                error("Vector-valued constants are not supported in balance data")
            constant += coeff
        else
            push!(terms, BalanceTerm(obj = term.id, var = term.var, coeff = coeff))
        end
    end
    return BalanceData(terms = terms, constant = constant)
end

function merge_balance_data(lhs::BalanceData, rhs::BalanceData)
    lhs_sense = normalize_balance_sense(lhs.sense)
    rhs_sense = normalize_balance_sense(rhs.sense)
    if lhs_sense != rhs_sense
        error("Cannot merge balance data with senses $lhs_sense and $rhs_sense")
    end
    return BalanceData(
        sense = lhs_sense,
        terms = vcat(lhs.terms, rhs.terms),
        constant = lhs.constant + rhs.constant,
    )
end

function add_balance(v::AbstractVertex, balance_id::Symbol, data)
    normalized = normalize_balance_data(data)
    if haskey(v.balance_data, balance_id)
        v.balance_data[balance_id] = merge_balance_data(balance_data(v, balance_id), normalized)
    else
        v.balance_data[balance_id] = normalized
    end
    return nothing
end

function balance_term_incidence(v::AbstractVertex, e::AbstractEdge)
    if start_vertex(e) === v
        return -1.0
    elseif end_vertex(e) === v
        return 1.0
    end
    error("Edge $(id(e)) is not connected to vertex $(id(v))")
end

function balance_macro_coeff(v::AbstractVertex, obj, var::Symbol, coeff)
    if var == :flow && obj isa AbstractEdge
        return balance_term_incidence(v, obj) * coeff
    end
    return coeff
end

function initialize_balance_expression(v::AbstractVertex, balance_id::Symbol, model::Model)
    return @expression(model, [t in time_interval(v)], 0 * model[:vREF])
end

function balance_term_added_by_edge_updates(term::BalanceTerm)
    return term.var == :flow && (term.obj isa AbstractEdge || term.obj isa Symbol)
end

function shifted_balance_time_index(obj, t::Int64, lag::Int)
    if lag == 0
        return t
    elseif lag < 0
        error("Negative balance lags are not supported: $lag")
    end
    return timestepbefore(t, lag, subperiods(obj))
end

resolve_balance_property(value, ::Int64) = value
resolve_balance_property(value::AbstractArray, t::Int64) = value[t]

resolve_balance_coeff(coeff::Float64, ::AbstractVertex, ::Int64) = coeff

function resolve_balance_coeff(coeff::Vector{Float64}, v::AbstractVertex, time_index::Int64)
    expected_length = length(time_interval(v))
    if length(coeff) != expected_length
        error(
            "Balance coefficient vector length $(length(coeff)) does not match time interval length $expected_length on vertex $(id(v))",
        )
    end
    return coeff[time_index]
end

resolve_balance_coeff(term::BalanceTerm, v::AbstractVertex, time_index::Int64) =
    resolve_balance_coeff(term.coeff, v, time_index)

function resolve_balance_var(obj::AbstractEdge, var::Symbol, t::Int64, lag::Int = 0)
    tt = shifted_balance_time_index(obj, t, lag)
    if var == :flow
        return flow(obj, tt)
    elseif var == :capacity
        return capacity(obj)
    elseif var == :existing_capacity
        return existing_capacity(obj)
    elseif var == :new_capacity
        return new_capacity(obj)
    elseif var == :retired_capacity
        return retired_capacity(obj)
    elseif hasproperty(obj, var)
        return resolve_balance_property(getproperty(obj, var), tt)
    end
    error("Unsupported balance variable $var on edge $(id(obj))")
end

function resolve_balance_var(obj::AbstractStorage, var::Symbol, t::Int64, lag::Int = 0)
    tt = shifted_balance_time_index(obj, t, lag)
    if var == :capacity
        return capacity(obj)
    elseif var == :existing_capacity
        return existing_capacity(obj)
    elseif var == :new_capacity
        return new_capacity(obj)
    elseif var == :retired_capacity
        return retired_capacity(obj)
    elseif var == :storage_level
        return storage_level(obj, tt)
    elseif hasproperty(obj, var)
        return resolve_balance_property(getproperty(obj, var), tt)
    end
    error("Unsupported balance variable $var on storage $(id(obj))")
end

function resolve_balance_var(obj::AbstractVertex, var::Symbol, t::Int64, lag::Int = 0)
    tt = shifted_balance_time_index(obj, t, lag)
    if hasproperty(obj, var)
        return resolve_balance_property(getproperty(obj, var), tt)
    end
    error("Unsupported balance variable $var on vertex $(id(obj))")
end

function add_balance_term_to_expression!(expr, term::BalanceTerm, v::AbstractVertex, t::Int64, time_index::Int64)
    resolved = resolve_balance_var(term.obj, term.var, t, term.lag)
    coeff = resolve_balance_coeff(term, v, time_index)
    if resolved isa Number
        add_to_expression!(expr, coeff * resolved)
    else
        add_to_expression!(expr, coeff, resolved)
    end
    return nothing
end

function local_balance_terms(data::BalanceData)
    return [term for term in data.terms if !balance_term_added_by_edge_updates(term)]
end

function compile_balance_data!(v::AbstractVertex, balance_id::Symbol, model::Model)
    expr = v.operation_expr[balance_id]
    data = balance_data(v, balance_id)
    terms = local_balance_terms(data)
    for (time_index, t) in enumerate(time_interval(v))
        for term in terms
            add_balance_term_to_expression!(expr[t], term, v, t, time_index)
        end
        if data.constant != 0.0
            add_to_expression!(expr[t], data.constant)
        end
    end
    return nothing
end

function build_balance_expressions!(v::AbstractVertex, model::Model)
    normalize_balance_data!(v)
    for balance_id in keys(v.balance_data)
        v.operation_expr[balance_id] = initialize_balance_expression(v, balance_id, model)
        compile_balance_data!(v, balance_id, model)
    end
    return nothing
end

balance_variable_functions() = (:flow,)

function is_balance_variable_call(ex)
    return ex isa Expr && ex.head == :call && ex.args[1] in balance_variable_functions()
end

function contains_balance_variable_call(ex)
    if is_balance_variable_call(ex)
        return true
    elseif ex isa Expr
        return any(contains_balance_variable_call, ex.args)
    end
    return false
end

function parse_balance_eq(ex)
    if isa(ex, Number)
        return [(obj = nothing, var = :constant, coeff = Float64(ex))]

    elseif isa(ex, Symbol)
        return [(obj = nothing, var = :constant, coeff = 0.0)]  # Just in case

    elseif isa(ex, Expr)
        if ex.head == :call
            args = ex.args
            len = length(args)
            f = args[1]
            if len == 1
                error("Functions with no arguments are not supported: $ex")
            elseif len == 2
                if f == :-
                    term = only(parse_balance_eq(args[2]))
                    return [(obj = term.obj, var = term.var, coeff = -term.coeff)]
                else
                    return [(obj = args[2], var = args[1], coeff = 1.0)]
                end
            else
                if f == :+
                    # Addition, where we must allow for associativity leading to 
                    # any number of terms
                    term_vectors = [parse_balance_eq(args[i]) for i in 2:len]
                    return vcat(term_vectors...) 
                elseif f == :-
                    # Subtraction, will always have 3 args as its non-associative
                    # We need to negate the right-hand side
                    lhs = parse_balance_eq(ex.args[2])
                    rhs = parse_balance_eq(ex.args[3])
                    
                    rhs = [
                        (
                            obj = t.obj,
                            var = t.var, 
                            coeff = (isa(t.coeff, Number)) ? -t.coeff : Expr(:call, :-, t.coeff)
                        ) for t in rhs
                    ]
                    return vcat(lhs, rhs)
                elseif f == :* || f == :/
                    # Multiplication, where we assume the last term is the variable
                    # as associativity means we can have any number of terms
                    if len == 3
                        term1 = ex.args[2]
                    else
                        term1 = Expr(:call, f, ex.args[2:end-1]...)
                    end 
                    term2 = ex.args[end]
                    if contains_balance_variable_call(term1) || (f == :/ && contains_balance_variable_call(term2))
                        error(
                            "@add_balance expects linear terms with coefficients before balance variables, e.g. coeff * flow(edge). Products or divisions involving balance variables are not supported.",
                        )
                    end
                    if isa(term1, Number) || isa(term2, Number)
                        if isa(ex.args[2], Number)
                            coeff = Float64(ex.args[2])
                            terms = parse_balance_eq(ex.args[3])
                        elseif isa(ex.args[3], Number)
                            coeff = f == :/ ? 1 / Float64(ex.args[3]) : Float64(ex.args[3])
                            terms = parse_balance_eq(ex.args[2])
                        end
                        return [(obj = t.obj, var = t.var, coeff = coeff * t.coeff) for t in terms]
                    end
                    terms = parse_balance_eq(term2)
                    return [
                        t.coeff == 1.0 ?
                        (obj = t.obj, var = t.var, coeff = term1) :
                        (obj = t.obj, var = t.var, coeff = Expr(:call, :*, term1, t.coeff))
                        for t in terms
                    ]
                end
            end
            error("Unrecognized expression format: $ex")
        end
    end
    error("Unrecognized expression: $ex")
end

function combine_constants!(constant_terms::Vector{<:NamedTuple{(:obj, :var, :coeff)}})
    if !isempty(constant_terms)
        constant_value = sum(t.coeff for t in constant_terms)
        if constant_value != 0.0
            return constant_value
        end
    end
    return 0.0
end

function validate_add_balance_terms(
    terms::Vector{<:NamedTuple{(:obj, :var, :coeff)}},
)
    invalid_vars = unique(term.var for term in terms if !isnothing(term.obj) && term.var != :flow)
    if !isempty(invalid_vars)
        invalid_terms = join(string.(invalid_vars), ", ")
        error(
            "@add_balance only supports flow(...) terms. Found unsupported balance terms: $invalid_terms",
        )
    end
    return nothing
end

"""
    @add_balance(component, balance_id, equation)

A macro to add a balance definition to a `Node`, `Transformation`, or `Storage`.

`@add_balance` is the primary balance-definition interface for asset modelers. It
supports equality and inequality balances with `flow(...)` terms and scalar or
time-varying coefficients.

`@add_balance` lets a modeler write a named flow relationship
in ordinary algebraic form and attach it to a vertex. Macro stores that
relationship as normalized balance data, which `BalanceConstraint` later
enforces at each time step.

# Arguments
- `component`: The component object to add balance data to
- `balance_id`: Symbol key for the balance equation (e.g., `:energy`, `:mass`)
- `equation`: Balance equation with operators: `==`, `=`, `<=`, `<`, `>=`, `>`

# Supported terms
- `flow(edge)`

# Coefficients
Coefficients may be:
- a scalar number
- a length-1 vector
- a vector with one coefficient per time step of the host vertex

Coefficients should be written before `flow(edge)`, for example
`heat_rate * flow(edge)`.

`@add_balance` expects linear terms. Expressions such as `c / flow(edge)` are
nonlinear because they divide by a decision variable. Write every flow term as a
coefficient multiplied by a flow, such as `(1 / efficiency) * flow(edge)`.

# Examples
```julia
@add_balance(transform, :energy, flow(elec_edge) == 0.5 * flow(h2_edge))
@add_balance(transform, :energy_lb, flow(elec_edge) >= eff * flow(h2_edge))
```

# Method
`@add_balance` parses the equation, moves all terms onto the left-hand side,
records the constraint sense (`:eq`, `:le`, or `:ge`), and converts each
`flow(...)` term into a `BalanceTerm`. For flow terms, the stored coefficient is
pre-adjusted using the edge incidence at the host vertex so that the compiled
balance reproduces the algebraic equation the user wrote.
"""
macro add_balance(component, balance_id, equation)
    add_balance_fn = GlobalRef(@__MODULE__, :add_balance)
    operator, normalized_expr = parse_balance_equation(equation)
    data_expr = build_balance_data_expr(
        normalized_expr,
        operator,
        :algebraic;
        component = component,
    )

    # Embed the computed terms directly into the generated code
    return esc(quote
        $add_balance_fn(
            $component,
            $balance_id,
            $data_expr
        )
    end)
end

function validate_add_to_balance_expression(expression)
    if isa(expression, Expr) && expression.head == :call
        operator = expression.args[1]
        supported_ops = [:(==), :(=), :(<=), :(<), :(>=), :(>)]
        if operator in supported_ops
            error(
                "@add_to_balance expects a term expression, not an equation with operator $operator",
            )
        end
    end
    return nothing
end

function parse_balance_equation(equation)
    if !isa(equation, Expr) || equation.head != :call
        error("Expected an equation expression, got: $equation")
    end

    operator = equation.args[1]
    left_side = equation.args[2]
    right_side = equation.args[3]

    supported_ops = [:(==), :(=), :(<=), :(<), :(>=), :(>)]
    if operator ∉ supported_ops
        error(
            "Your balance constraint has an unsupported operator: $operator. Supported operators: $supported_ops",
        )
    end

    sense =
        if operator == :(>=) || operator == :(>)
            :ge
        elseif operator == :(<=) || operator == :(<)
            :le
        else
            :eq
        end

    normalized_expr = :($left_side - $right_side)
    return sense, normalized_expr
end

function build_balance_data_expr(
    expression,
    sense::Symbol,
    coeff_mode::Symbol;
    component = nothing,
)
    balance_macro_coeff_fn = GlobalRef(@__MODULE__, :balance_macro_coeff)
    balance_data_type = GlobalRef(@__MODULE__, :BalanceData)
    balance_term_type = GlobalRef(@__MODULE__, :BalanceTerm)

    terms = parse_balance_eq(expression)
    validate_add_balance_terms(terms)
    constant = combine_constants!(filter(t -> isnothing(t.obj), terms))
    term_exprs = [
        :($balance_term_type(
            obj = $(t.obj),
            var = $(QuoteNode(t.var)),
            coeff = $(
                if coeff_mode == :raw
                    t.coeff
                elseif coeff_mode == :algebraic
                    isnothing(component) &&
                        error("component is required when coeff_mode == :algebraic")
                    :($balance_macro_coeff_fn($component, $(t.obj), $(QuoteNode(t.var)), $(t.coeff)))
                else
                    error("Unsupported coeff_mode $coeff_mode")
                end
            ),
        )) for t in terms if !isnothing(t.obj)
    ]

    return :($balance_data_type(
        sense = $(QuoteNode(sense)),
        terms = [$(term_exprs...)],
        constant = $constant,
    ))
end

"""
    @add_to_balance(component, balance_id, expression)

Add one or more terms to an existing named balance without writing an explicit
constraint sense. This stores the provided `expression` as a raw additive
contribution to `balance_id`.

Modelers should usually write positive coefficients for both incoming and
outgoing `flow(...)` terms. MacroEnergy applies edge-direction handling later
when compiling the balance, so outgoing flows contribute with a negative sign in
the common case.

# Example
```julia
@add_to_balance(transform, :energy, flow(fuel_edge))
@add_to_balance(transform, :energy, 0.5 * flow(elec_edge))
```
"""
macro add_to_balance(component, balance_id, expression)
    validate_add_to_balance_expression(expression)
    add_balance_fn = GlobalRef(@__MODULE__, :add_balance)
    data_expr = build_balance_data_expr(expression, :eq, :raw)
    return esc(quote
        $add_balance_fn($component, $balance_id, $data_expr)
    end)
end

"""
    @add_to_storage_balance(storage, expression)
    @add_to_storage_balance(storage, :storage, expression)

Add terms to the reserved `:storage` balance on a storage component. This macro
is a convenience wrapper around `@add_to_balance` that defaults the balance ID
to `:storage`.

Modelers should usually write positive coefficients for both inflow and outflow
terms. MacroEnergy applies edge-direction handling later when compiling the
final storage balance, so outgoing storage flows reduce storage in the common
case.

# Example
```julia
@add_to_storage_balance(storage, charge_efficiency * flow(charge_edge))
@add_to_storage_balance(storage, 1 / discharge_efficiency * flow(discharge_edge))
```
"""
macro add_to_storage_balance(storage, expression)
    validate_add_to_balance_expression(expression)
    return esc(quote
        @add_to_balance($storage, :storage, $expression)
    end)
end

macro add_to_storage_balance(storage, balance_id, expression)
    validate_add_to_balance_expression(expression)
    if balance_id isa QuoteNode
        balance_id.value == :storage ||
            error("@add_to_storage_balance only supports the :storage balance id")
    end
    return esc(quote
        local _balance_id = $balance_id
        _balance_id == :storage ||
            error("@add_to_storage_balance only supports the :storage balance id, got $(_balance_id)")
        @add_to_balance($storage, _balance_id, $expression)
    end)
end

function inexpr(large_expr::Expr, target_expr::Expr)::Bool
    if target_expr == large_expr
        return true
    end
    if target_expr in large_expr.args
        return true
    end
    for term in large_expr.args
        if isa(term, Expr)
            if inexpr(term, target_expr)
                return true
            end
        end
    end
    return false
end

function stoichiometric_flow_edge(term)
    return nothing
end

function stoichiometric_flow_edge(term::Expr)
    # Orientation checks need the edge itself. For a term like flow(elec_edge),
    # extract and return elec_edge so the caller can inspect its incidence.
    if term.head == :call && term.args[1] == :flow && length(term.args) == 2
        return term.args[2]
    end
    return nothing
end

function validate_stoichiometric_edge_orientation(
    v::AbstractVertex,
    e::AbstractEdge,
    expected_incidence::Float64,
    side::Symbol,
)
    incidence = balance_term_incidence(v, e)
    if incidence != expected_incidence
        expected_direction = expected_incidence > 0 ? "incoming" : "outgoing"
        actual_direction = incidence > 0 ? "incoming" : "outgoing"
        error(
            "@add_stoichiometric_balance expects $side-hand terms to be $expected_direction relative to $(id(v)); edge $(id(e)) is $actual_direction",
        )
    end
    return nothing
end

const EXPR_COEFF = Union{Real, Symbol, Expr}

function find_expr_terms(equation::Any, negative_term::Bool=false)::Vector{Tuple{EXPR_COEFF, Expr}}
    error("Unsupported stoichiometric term $equation in @add_stoichiometric_balance")
end

function find_expr_terms(equation::Number, negative_term::Bool=false)::Vector{Tuple{EXPR_COEFF, Expr}}
    error(
        "Constants are not supported in @add_stoichiometric_balance. Move all recipe quantities onto explicit terms like coeff * flow(edge).",
    )
end

function find_expr_terms(equation::Symbol, negative_term::Bool=false)::Vector{Tuple{EXPR_COEFF, Expr}}
    error(
        "Bare symbols like $equation are not supported in @add_stoichiometric_balance. Attach coefficients to an explicit term like coeff * flow(edge).",
    )
end

function find_expr_terms(equation::Expr, negative_term::Bool=false)::Vector{Tuple{EXPR_COEFF, Expr}}
    coeff_multiplier = negative_term ? -1.0 : 1.0
    if equation.args[1] == :* || equation.args[1] == :/
        if length(equation.args) == 3
            return [(:($coeff_multiplier * $(equation.args[2])), equation.args[3])]
        else
            return [(Expr(:call, equation.args[1], coeff_multiplier, equation.args[2:end-1]...), equation.args[end])]
        end
    elseif equation.args[1] == :+
        terms = Tuple{EXPR_COEFF, Expr}[]
        for arg in equation.args[2:end]
            sub_terms = find_expr_terms(arg, negative_term)
            append!(terms, sub_terms)
        end
        return terms
    elseif equation.args[1] == :-
        error(
            "Negative stoichiometric terms are not supported in @add_stoichiometric_balance. Move subtracted terms to the other side of the --> expression.",
        )
    else
        return [(1.0, equation)]
    end
end

function find_term_coeff(terms::Vector{Tuple{EXPR_COEFF, Expr}}, target_term::Expr)
    for term in terms
        if term[2] == target_term
            return term[1]
        end
    end
    return nothing
end

function simplify_stoichiometric_coeff(coeff::EXPR_COEFF)
    if coeff isa Expr && coeff.head == :call && coeff.args[1] == :* && length(coeff.args) == 3
        if coeff.args[2] == 1.0
            return coeff.args[3]
        elseif coeff.args[3] == 1.0
            return coeff.args[2]
        end
    end
    return coeff
end

function build_stoichiometric_balance_equations(
    balance_id_value::Symbol,
    equation::Expr,
    base_term::Expr,
)
    if equation.head != :-->
        error("@add_stoichiometric_balance expected a balance equation with --> operator, got: $equation")
    end

    input_equation = equation.args[1]
    output_equation = equation.args[2]

    input_terms = find_expr_terms(input_equation)
    output_terms = find_expr_terms(output_equation)

    base_coeff =
        if inexpr(input_equation, base_term)
            find_term_coeff(input_terms, base_term)
        else
            find_term_coeff(output_terms, base_term)
        end
    if isnothing(base_coeff)
        error("Base term $base_term was not found in balance equation $equation")
    end
    base_coeff = simplify_stoichiometric_coeff(base_coeff)

    equations = Tuple{Symbol, Expr}[]
    all_terms = vcat(input_terms, output_terms)

    for (term_coeff, term_variable) in all_terms
        if term_variable == base_term
            continue
        end
        term_coeff = simplify_stoichiometric_coeff(term_coeff)
        # Express every pairwise relation against the same recipe basis:
        # flow(term) / term_coeff == flow(base_term) / base_coeff
        balance_equation = :($base_coeff * $term_variable - $term_coeff * $base_term == 0)
        new_balance_id = Symbol(balance_id_value, "_", length(equations) + 1)
        push!(equations, (new_balance_id, balance_equation))
    end

    return equations, input_terms, output_terms
end

function build_stoichiometric_validation_calls(
    component::Any,
    input_terms::Vector{Tuple{EXPR_COEFF, Expr}},
    output_terms::Vector{Tuple{EXPR_COEFF, Expr}},
)
    validate_orientation_fn = GlobalRef(@__MODULE__, :validate_stoichiometric_edge_orientation)
    validation_calls = Expr[]

    # The --> syntax is directional: left-hand terms are interpreted as
    # incoming recipe terms and right-hand terms as outgoing recipe terms.
    for (_, term_variable) in input_terms
        edge_expr = stoichiometric_flow_edge(term_variable)
        if !isnothing(edge_expr)
            push!(validation_calls, :($validate_orientation_fn($component, $edge_expr, 1.0, :left)))
        end
    end
    for (_, term_variable) in output_terms
        edge_expr = stoichiometric_flow_edge(term_variable)
        if !isnothing(edge_expr)
            push!(validation_calls, :($validate_orientation_fn($component, $edge_expr, -1.0, :right)))
        end
    end

    return validation_calls
end

"""
    @add_stoichiometric_balance(component, balance_id, equation, base_term)

Expand a stoichiometric-style balance written with the `-->` operator into
multiple pairwise balances anchored on `base_term`.

This macro is a convenience wrapper for recipe-style or chemical-style
relationships. For general balances, `@add_balance` is the preferred interface.

`@add_stoichiometric_balance` lets a modeler describe a recipe
using `incoming_terms --> outgoing_terms`, then expands that shorthand into one
or more ordinary balances that Macro can store and enforce.

# Example
```julia
@add_stoichiometric_balance(
    electrolyzer,
    :energy,
    flow(elec_edge) --> efficiency * flow(h2_edge),
    flow(h2_edge),
)
```

# Method
The macro parses the left and right sides of `-->` into weighted `flow(...)`
terms, validates that left-hand terms are incoming and right-hand terms are
outgoing relative to the host component, identifies the coefficient on
`base_term`, and generates one pairwise `@add_balance` call for each remaining
term using the proportional rule `base_coeff * flow(term) - term_coeff *
flow(base_term) == 0`. This keeps the recipe syntax compact while delegating
final balance construction to `@add_balance`.
"""
macro add_stoichiometric_balance(component, balance_id, equation, base_term)
    balance_id_value = balance_id isa QuoteNode ? balance_id.value : balance_id

    if !isa(equation, Expr)
        error("@add_stoichiometric_balance expected a balance equation with --> operator, got: $equation")
    end

    equations, input_terms, output_terms =
        build_stoichiometric_balance_equations(balance_id_value, equation, base_term)
    validation_calls = build_stoichiometric_validation_calls(component, input_terms, output_terms)
    balance_calls = [
        :(@add_balance($component, $(QuoteNode(generated_balance_id)), $balance_equation)) for
        (generated_balance_id, balance_equation) in equations
    ]

    return esc(quote
        $(validation_calls...)
        $(balance_calls...)
    end)
end

"""
    @inspect_stoichiometric_balance(component, balance_id, equation, base_term)
    @inspect_stoichiometric_balance(component, balance_id, equation, base_term, verify_edge_directions = true)

Return the pairwise algebraic balance equations that
`@add_stoichiometric_balance` would generate.

This is a debugging helper for understanding the recipe expansion without
reading the lower-level `BalanceTerm` machinery. The macro returns a vector of
`Pair{Symbol, Expr}` values mapping each generated balance ID to the plain
algebraic equation that would be passed to `@add_balance`.

By default the macro skips orientation validation so the algebraic expansion can
be inspected without requiring live component and edge objects. Pass
`verify_edge_directions = true` to reuse the same orientation validation as
`@add_stoichiometric_balance`.
"""
macro inspect_stoichiometric_balance(component, balance_id, equation, base_term)
    return esc(:(
        @inspect_stoichiometric_balance(
            $component,
            $balance_id,
            $equation,
            $base_term,
            verify_edge_directions = false,
        )
    ))
end

macro inspect_stoichiometric_balance(component, balance_id, equation, base_term, option)
    balance_id_value = balance_id isa QuoteNode ? balance_id.value : balance_id
    if !isa(equation, Expr)
        error("@inspect_stoichiometric_balance expected a balance equation with --> operator, got: $equation")
    end
    verify_edge_directions_expr =
        if option isa Expr && option.head == :(=)
            if option.args[1] != :verify_edge_directions
                error("@inspect_stoichiometric_balance only supports the option verify_edge_directions = true/false")
            end
            option.args[2]
        else
            option
        end

    equations, input_terms, output_terms =
        build_stoichiometric_balance_equations(balance_id_value, equation, base_term)
    validation_calls = build_stoichiometric_validation_calls(component, input_terms, output_terms)
    pair_exprs = [
        :($(QuoteNode(generated_balance_id)) => $(Meta.quot(balance_equation))) for
        (generated_balance_id, balance_equation) in equations
    ]

    return esc(quote
        if $verify_edge_directions_expr
            $(validation_calls...)
        end
        [$(pair_exprs...)]
    end)
end
