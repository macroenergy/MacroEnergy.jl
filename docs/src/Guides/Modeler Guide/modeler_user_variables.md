# [Creating and Using User Variables](@id modeler_user_variables)

User variables let an asset attach additional JuMP variables to its nodes, edges,
storage, or transformations. Declare them in the component's `variables` input,
then retrieve them by name when building constraints.

This guide uses a made-up **ToyWorkshop** asset. It chooses how many workstations
to install and how many items to produce each hour. Each workstation can produce
two items per hour. The example builds a small monolithic model directly so that
the variable declarations and their use are visible together.

## 1. Declare the variables on a component

The asset contains one `Transformation`. Its input declares a planning variable,
`workstations`, and an operational variable, `production`:

```@example user_variables_guide
using MacroEnergy
using JuMP
using HiGHS

struct ToyWorkshop <: MacroEnergy.AbstractAsset
    id::Symbol
    workshop::MacroEnergy.Transformation
end

function ToyWorkshop(id::Symbol, timedata::MacroEnergy.TimeData)
    data = Dict{Symbol,Any}(
        :id => Symbol(id, "_workshop"),
        :variables => [
            Dict(
                :name => "workstations",
                :time_varying => false,
                :operation_variable => false,
                :type => "Int",
                :lower_bound => 0.0,
                :upper_bound => 3.0,
            ),
            Dict(
                :name => "production",
                :time_varying => true,
                :operation_variable => true,
                :lower_bound => 0.0,
            ),
        ],
    )
    parsed = MacroEnergy.process_data(data)
    workshop = MacroEnergy.Transformation(;
        id = parsed[:id],
        timedata = timedata,
        variables = parsed[:variables],
    )
    return ToyWorkshop(id, workshop)
end
nothing # hide
```

`process_data` converts the input dictionaries to immutable `UserVariable`
objects. At this point they contain the specifications, but no JuMP references.
For an asset loaded from case inputs, put the same `:variables` list in the
appropriate `@transform_data`, `@edge_data`, or `@storage_data` entry in
`full_default_data`, and pass it through the asset's usual data-processing and
component-construction steps. See [Creating a New Asset](@ref modeler_create_asset)
for the `make` function and case-input workflow. The declaration works in both
source-defined assets and user asset files.

Names must be nonempty and unique **within each component**. Different components
may each have a variable named `production`.

## 2. Use the variables in an asset constraint

The standard asset planning method visits the asset's components and creates
`workstations`. We specialize the operational method to first build the component's
operational variables, then add the workshop's production limit:

```@example user_variables_guide
function MacroEnergy.operation_model!(asset::ToyWorkshop, model::JuMP.Model)
    MacroEnergy.operation_model!(asset.workshop, model)

    workstations = MacroEnergy.user_variable(asset.workshop, :workstations)
    production = MacroEnergy.user_variable(asset.workshop, :production)
    @constraint(model, [t in MacroEnergy.time_interval(asset.workshop)],
        production[t, 1] <= 2 * workstations[1]
    )
    return nothing
end
nothing # hide
```

Retrieve the containers once, then index them inside your constraints. The
accessors are qualified with `MacroEnergy.` because they are not exported.

With the default `number_segments = 1`, a time-independent variable is still a
one-element container (`workstations[1]`), and a time-varying variable has both
time and segment indices (`production[t, 1]`). Setting `number_segments = 2`
would create two entries per time step. Timing and model stage are independent:
`time_varying` chooses the indices; `operation_variable` chooses when creation
happens.

## 3. Build and solve a three-hour example

Here we require production of 1, 3, and 2 items in successive hours, and minimize
the number of installed workstations. This toy asset has no commodity flows or
energy balances; the constraints below describe only its production decisions.

```@example user_variables_guide
hours = MacroEnergy.TimeData{MacroEnergy.Electricity}(;
    time_interval = 1:3,
    hours_per_timestep = 1,
    subperiods = [1:3],
    subperiod_indices = [1],
    subperiod_weights = Dict(1 => 1.0),
    period_index = 1,
)
asset = ToyWorkshop(:example_workshop, hours)
model = Model(HiGHS.Optimizer)
set_silent(model)

MacroEnergy.planning_model!(asset, model)
MacroEnergy.operation_model!(asset, model)

workstations = MacroEnergy.user_variable(asset.workshop, :workstations)
production = MacroEnergy.user_variable(asset.workshop, :production)
required_production = [1.0, 3.0, 2.0]
@constraint(model, [t in 1:3], production[t, 1] == required_production[t])
@objective(model, Min, workstations[1])
optimize!(model)
assert_is_solved_and_feasible(model)

@assert isapprox(value(workstations[1]), 2.0) # hide
@assert all(isapprox.(value.(production[:, 1]), required_production)) # hide
(installed_workstations = value(workstations[1]),
 production = [value(production[t, 1]) for t in 1:3])
```

Two workstations are needed to meet the second hour's requirement of three items.
Variable declarations supply the variables and their bounds; constraints and
objective terms must still be added explicitly, as above.

## Access and model lifetime

- `MacroEnergy.user_variable(component, :name)` returns the JuMP container. It
  throws an error before the relevant model stage has built the variable, or
  after its references have been released.
- `MacroEnergy.user_variable_spec(component, :name)` returns the specification,
  including its current `variable_ref`. It can be called before model creation.
- Read results with JuMP's `value` before discarding the model. Call
  `MacroEnergy.release_user_variable_references!(component)` on each component
  to replace each user variable's reference with `nothing` while retaining
  its name, bounds, type, and indexing settings. Retrieve fresh references after
  rebuilding; previously saved specifications and references are not updated.
  The helper clears only user-variable references. This branch does not provide
  automatic system-wide model release.

Build each stage once per model. Recreating user variables that still have valid
references in the same model emits a warning and proceeds; the original variables
and constraints remain in the model. This guide covers monolithic models; custom
planning variables are not automatically linked into Benders subproblems.
See [User Variables](@ref) for all input fields and [User Variables API](@ref)
for the API docstrings.
