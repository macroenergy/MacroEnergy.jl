# User Variables

User-defined variables let you attach additional JuMP variables to constituent
components of an asset, such as its nodes, edges, storage components, or
transformations. These variables can then be used in user-defined constraints,
expressions, and custom model logic.

For a worked asset example, see [Creating and Using User Variables](@ref modeler_user_variables).

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

- `name`: Required, nonempty `String` or `Symbol`, unique within the component
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

Bounds are scalar numbers applied to every entry in the variable container.
Time series or vectors of bounds are not accepted.

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
MacroEnergy.user_variable(component, :my_variable)
```

This returns the `variable_ref` field for the matching user variable. Access before
creation or after model release throws an error. Time-varying variables are indexed
as `[t, segment]`; time-independent variables are indexed as `[segment]`. The
segment index is required even when `number_segments` is one.

If you need the full specification, use:

```julia
MacroEnergy.user_variable_spec(component, :my_variable)
```

This returns the full `UserVariable` object, including metadata such as
`time_varying`, `number_segments`, `variable_type`, and bounds.

## Notes on Naming

Macro stores user variables in a dictionary keyed by their declared names.
Missing, empty, and duplicate names are rejected. The same name may be used on
different components. JuMP names include the variable name, component ID, and period.

## Model Release

`MacroEnergy.release_user_variable_references!(component)` clears each stored
user-variable reference while retaining the immutable specification for rebuilding.
This branch does not include automatic system-wide model release; call the helper
on each component when discarding a model. Other component references and the
JuMP model itself require their own cleanup. Read results before release, and retrieve new
references after rebuilding. A previously saved `UserVariable` or JuMP reference
still refers to the old model; it is not updated when a dictionary entry is replaced.

## Typical Workflow

1. Add a `variables` field to the relevant component input data.
2. Build the asset as usual.
3. Let Macro create the variables during planning or operational model
   construction, depending on `operation_variable`.
4. Use `MacroEnergy.user_variable(component, :name)` in constraints or expressions
   after the corresponding variables have been created.
