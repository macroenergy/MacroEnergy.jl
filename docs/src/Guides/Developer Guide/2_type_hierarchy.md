# Macro type hierarchy

```@meta
CurrentModule = MacroEnergy
```

### Commodity Types
```@example type_hierarchy
using MacroEnergy # hide
using AbstractTrees # hide
using InteractiveUtils # hide
AbstractTrees.children(d::DataType) = subtypes(d) # hide
print_tree(Commodity)
```

### Asset Types
```@example type_hierarchy
print_tree(AbstractAsset)
```

### Constraint Types
```@example type_hierarchy
print_tree(MacroEnergy.AbstractTypeConstraint)
```

### JuMP container types

Macro's variables and constraints are stored on edges, vertices and storage units as JuMP
containers, and the concrete container type is not the same in every model. The types
involved are defined in `src/model/jump_containers.jl` and come in two layers.

The **wide** types, `JuMPVariable` and `JuMPConstraint`, are unions over every container 
JuMP might hand back (`Array`, `DenseAxisArray`, `SparseAxisArray`, and 
`VariableRef`/`ConstraintRef`). Struct fields are declared with them — 
`flow::JuMPVariable` on an `Edge`, `non_served_demand::JuMPVariable` on a `Node` — 
because a field has to accept whichever container the model build actually
produced. [`array_container`](@ref MacroEnergy.array_container) decides which one: a
contiguous one-based index set such as `1:24` gets a plain `Array`, anything else gets a
`DenseAxisArray`. In practice the `Array` fast path is what a
monolithic model uses everywhere; the `DenseAxisArray` branch exists for Benders
subproblems, where `generate_decomposed_system` gives each subproblem its own subperiod
window (`1:168`, `169:336`, `337:504`, …) and only the first one starts at 1.

The **narrow** types — `VarArrayOrDense`, `MatrixVarOrDense`, `AffExprArrayOrDense` — are
two-member unions covering only the container shapes that can actually occur for
a given field, and they are what the accessors re-assert down to:

```julia
flow(e::AbstractEdge, t::Int64) = (flow(e)::VarArrayOrDense)[t]
storage_level(g::AbstractStorage, t::Int64) = (storage_level(g)::VarArrayOrDense)[t]
non_served_demand(n::Node, s::Int64, t::Int64) = (non_served_demand(n)::MatrixVarOrDense)[s, t]
```

Without that assertion the compiler knows only the field's declared type, `JuMPVariable`,
which is too wide to have a fixed layout. Each element read inside a per-timestep loop then
has to go through a generic `getindex` that returns its result as a freshly allocated,
tagged heap object rather than as a value in registers. With the assertion, Julia splits
the union into its two concrete branches and specializes the read for each, so it produces a
`VariableRef`/`AffExpr` directly and allocates nothing.

`test/test_container_types.jl` pins each alias against a real macro-built container and
`test/test_accessor_allocation.jl` asserts the accessors allocate nothing, so a shape that
drifts fails a test instead of quietly reverting to `Any`.


