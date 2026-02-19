# MacroEnergy.jl Project Guidelines

MacroEnergy is a Julia-based multi-sector infrastructure optimization model for energy systems. It uses JuMP for optimization modeling with a graph-based architecture.

## Code Style

- **Naming**: Types use `PascalCase` (`Battery`, `ThermalPower`), functions/variables use `snake_case` (`load_inputs`, `time_data`), constants use `SCREAMING_SNAKE_CASE`
- **Type annotations**: Mutable structs with `Base.@kwdef mutable struct` pattern; explicit type annotations on all fields
- **Commodity parameterization**: Network components are parameterized by commodity type: `Node{T<:Commodity}`, `Edge{T<:Commodity}`
- **IDs**: Use `AssetId = Symbol` for asset identifiers throughout codebase
- **Docstrings**: Use `@doc raw"""` for math equations in constraints; structure with Description, Arguments, Returns, Examples sections
- **Example files**: [src/model/assets/battery.jl](src/model/assets/battery.jl) for asset patterns, [src/model/constraints/balance.jl](src/model/constraints/balance.jl) for constraints

## Architecture

The system follows a data flow: **Load → System → Case → Model → Solve → Output**

- **System**: Single planning period containing assets, locations, commodities, time_data, settings
- **Case**: Collection of Systems for multi-period optimization with capacity linking between periods
- **Assets**: Composed of network components (Nodes, Edges, Storage, Transformations), not graph vertices themselves
- **Component pattern**: Assets are structs containing their network components (e.g., `Battery` has `battery_storage::Storage`, `charge_edge::Edge`, `discharge_edge::Edge`)
- **Constraints**: Mutable structs implementing `add_model_constraint!(ct, obj, model)` method; store constraint reference for later access
- **Type hierarchy**: Extensive use of abstract types (`AbstractAsset`, `AbstractVertex`, `AbstractEdge`) for polymorphism

### Key Components
- [src/model/system.jl](src/model/system.jl) - Core `System` container
- [src/model/case.jl](src/model/case.jl) - Multi-period `Case` orchestration
- [src/model/generate_model.jl](src/model/generate_model.jl) - JuMP model builder
- [src/load_inputs/](src/load_inputs/) - JSON/CSV data ingestion
- [src/write_outputs/](src/write_outputs/) - CSV result export

## Build and Test

```julia
# Install dependencies
using Pkg
Pkg.activate(".")
Pkg.instantiate()

# Run tests
Pkg.test("MacroEnergy")

# Build documentation (from docs/ directory)
include("make.jl")
```

- Julia 1.x required
- Default solver: HiGHS; Gurobi via extension (weak dependency)
- Tests suppress logging to Warn level

## Project Conventions

### Creating Assets
Assets use data macros for default values:
```julia
@edge_data(:commodity => "Electricity", :efficiency => 0.95)
@storage_data(:commodity => "Electricity", :can_expand => true)
@node_data(:demand => [100.0, 120.0])
```

### Input Data Structure
- **system_data.json**: Root file with paths to all input files
- **commodities.json**: Commodity type definitions
- **time_data.json**: Contains `NumberOfSubperiods`, `HoursPerTimeStep`, `HoursPerSubperiod`, `SubPeriodMap`
- **assets/**: One CSV/JSON per asset type (battery.csv, thermal_power.csv, etc.)
- **settings/**: `macro_settings.json`, `case_settings.json`, optional `benders_settings.json`

### Time Structure
Three-level hierarchy per System:
1. **Periods** (years) - defined by `PeriodLengths` in case settings
2. **Subperiods** (seasons) - `NumberOfSubperiods`
3. **Timesteps** (hours) - `HoursPerTimeStep` dict

Multi-period cases link capacities via `carry_over_capacities!()` between periods.

### Constraint Pattern
```julia
Base.@kwdef mutable struct MyConstraint <: OperationConstraint
    constraint_ref::Union{Missing,JuMPConstraint} = missing
end

function add_model_constraint!(ct::MyConstraint, obj, model::Model)
    ct.constraint_ref = @constraint(model, ...)
end
```

### Output Conventions
- Results written to `results/` (single period) or `results_period_{i}/` (multi-period)
- Standard files: `capacity.csv`, `costs.csv`, `undiscounted_costs.csv`, `flows.csv`, `duals.csv`
- Layout controlled by `OutputLayout` setting: "long" (default) or "wide"

## Integration Points

### Solver Integration
- Create optimizer with `create_optimizer()` helper
- Environment caching via `OPT_ENV_REGISTRY` for performance
- Extensions use weak dependencies pattern (see [ext/MacroEnergyGurobiExt.jl](ext/MacroEnergyGurobiExt.jl))

### Benders Decomposition
- Implemented via `MacroEnergySolvers.benders()`
- Planning problem (capacity decisions) + operational subproblems (dispatch)
- Settings: `MaxIter`, `ConvTol`, `StabParam`, `Distributed`, `IntegerInvestment`
- Use `BendersResults` struct to wrap solver results with subproblem models

## Key Patterns

1. **Symbol-based indexing**: IDs, commodity names, constraint types all use `Symbol` type
2. **Mutable structs**: Nearly all model structs are mutable for in-place updates during model building
3. **Multiple dispatch**: Heavy use of Julia's type system for polymorphism (assets, constraints, commodities)
4. **Graph-based**: Energy system represented as a graph, but assets are containers of graph components, not vertices
5. **Extensive logging**: Use `@info`, `@debug`, `@warn` throughout code for workflow visibility
6. **Commodity hierarchy**: Commodities are abstract types created dynamically, allowing specialization

## Contributing and Pull Requests

### Implementation Workflow

When implementing a new feature or making significant code changes:
1. **Implement the code change** following the project conventions and architecture patterns
2. **Immediately invoke the `docs-agent` subagent** to handle all documentation updates
   - Use the `runSubagent` tool with agent name `docs-agent`
   - Provide a clear description of what needs to be documented
   - The agent will update docstrings, Manual pages, Guides, and Tutorials as needed
3. **Do not open a PR** until documentation updates are complete

This ensures that code and documentation stay synchronized and that PRs are complete before review.

### Before Opening a PR
- Open an issue first to discuss proposed changes
- Fork repository, create descriptive branch: `<user_id>/<short_description>`
- Keep fork synced with upstream `main` branch
- Full workflow documented in [docs/src/how_to_contribute.md](docs/src/how_to_contribute.md)

### Documentation Validation Requirements

**CRITICAL**: Before opening a PR, ensure documentation tests pass by running: `cd docs && julia make.jl`

The documentation build validates:
- Cross-reference anchors are unique within each file
- All `@ref` targets have actual docstrings or headers
- All exported functions are documented in `@autodocs` blocks

See **docs-agent** instructions for detailed troubleshooting and patterns if the build fails.

### PR Requirements
- **Code quality**: Review your code, add comments for complex logic
- **Testing**: Include test coverage; provide example case (JSON/CSV/Julia files) with expected results
- **Documentation**: **MANDATORY** - Documentation updates must be completed during implementation using the `docs-agent` (see Implementation Workflow above)
  - All docstring updates for new/changed functions (use `@doc raw"""` format with Description, Arguments, Returns, Examples sections)
  - All new exported functions/types must be included in `@autodocs` blocks in appropriate `References/` page
  - Manual page updates if behavior changes (use unique header slugs, avoid duplicate `@ref` names)
  - New or updated examples in Guides and Tutorials 
  - **Validate**: Run `cd docs && julia make.jl` to ensure documentation builds without errors before opening PR
  - PRs without completed documentation updates will not be reviewed
- **Focus**: Keep PRs small and focused on single changes
- **Description**: Write clear motivation and highlight areas needing reviewer feedback
- **Branch naming**: Follow `<user_id>/<short_description>` pattern

### Review Process
- Maintainers review and provide feedback
- Push additional commits to update PR
- Use GitHub conflict resolution if needed
- Delete branch after merge
