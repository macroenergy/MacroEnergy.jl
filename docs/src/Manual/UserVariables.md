# User Variables

User-defined variables let you attach additional JuMP variables to constituent
components of an asset, such as its nodes, edges, storage components, or
transformations. These variables can then be used in user-defined constraints,
expressions, and custom model logic.

## What This Feature Does

Each component may define a `variables` entry in its input data. Macro parses
that specification into `UserVariable` objects and creates the corresponding
JuMP variables when the planning or operational model is built.

This is intended for cases where users want to:

- introduce additional decision variables in custom assets
- reference those variables in custom constraints
- keep custom model logic attached to the same component that owns the variable

## Input Format

The `variables` field should be a vector of dictionaries. Each dictionary
defines one user variable.

```julia
:variables => [
    Dict(
        :name => "build_slack",
        :time_varying => false,
        :operation_variable => false,
        :number_segments => 1,
        :type => "Continuous",
        :lower_bound => 0.0,
    ),
    Dict(
        :name => "dispatch_mode",
        :time_varying => true,
        :operation_variable => true,
        :number_segments => 2,
        :type => "Bin",
    ),
]
```

Supported fields are:

- `name`: Optional `String` or `Symbol`
- `time_varying`: Required `Bool`
- `operation_variable`: Optional `Bool`, default `true`
- `number_segments`: Optional positive `Int`, default `1`
- `type`: Optional `String` or `Symbol`, default `Continuous`
- `lower_bound`: Optional numeric bound
- `upper_bound`: Optional numeric bound

Supported variable types are:

- `Continuous`
- `Bin`
- `Int`
- `Semiinteger`
- `Semicontinuous`

For `Semiinteger` and `Semicontinuous`, both `lower_bound` and `upper_bound`
must be provided.

Bounds can also be supplied through the usual Macro input-loading patterns
instead of being written directly as literals. For example, a user may point
`lower_bound` or `upper_bound` to data loaded from JSON using the same
distributed-input conventions used elsewhere in Macro input files. This can be
useful when a user wants variable bounds to be configured from external case
data rather than hard-coded in an asset definition.

## Planning vs Operational Variables

Use `operation_variable` to choose when a variable is created:

- `false`: variable is created in `planning_model!`
- `true`: variable is created in `operation_model!`

Examples:

```julia
Dict(
    :name => "build_choice",
    :time_varying => false,
    :operation_variable => false,
    :type => "Int",
    :lower_bound => 0,
)
```

```julia
Dict(
    :name => "dispatch_slack",
    :time_varying => true,
    :operation_variable => true,
    :lower_bound => 0.0,
)
```

## Accessing User Variables

Most user-defined constraints will want the JuMP variable reference directly.
Use:

```julia
user_variable(component, :my_variable)
```

This returns the `variable_ref` field for the matching user variable.

If you need the full specification, use:

```julia
user_variable_spec(component, :my_variable)
```

This returns the full `UserVariable` object, including metadata such as
`time_varying`, `number_segments`, `variable_type`, and bounds.

## Notes on Naming

Macro stores user variables in a dictionary keyed by a unique identifier. If a
variable is unnamed, or if duplicate names are provided, Macro generates unique
fallback keys such as `:variable1` and `:variable2`.

JuMP variable names are built from these stored keys so that unnamed and
duplicate user variables still receive stable, unique names in the model.

## Typical Workflow

1. Add a `variables` field to the relevant component input data.
2. Build the asset as usual.
3. Use `user_variable(component, :name)` inside custom constraints or
   expressions.
4. Let Macro create the variables automatically during planning or operational
   model construction, depending on `operation_variable`.
