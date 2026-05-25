"""
    StochasticScenario

One weather-year realization in a stochastic capacity expansion problem.

Fields: `id` (used as `period_index` in all TimeData), `probability` (must sum to 1.0
across all scenarios), `system` (full operational system for this scenario).
"""
struct StochasticScenario
    id::Int
    probability::Float64
    system::System
end

"""
    StochasticCase

A stochastic capacity expansion case: one shared investment decision evaluated across
multiple weather-year scenarios.

`PolicyMode` (in `stochastic_settings`) controls how CO2Cap and CO2Storage constraints
are applied across scenarios:
- `"per_realization"`: each scenario satisfies every policy constraint independently.
- `"expected"` (default): one probability-weighted constraint couples all scenarios.
"""
struct StochasticCase
    scenarios::Vector{StochasticScenario}
    settings::NamedTuple
    stochastic_settings::NamedTuple
end

number_of_scenarios(sc::StochasticCase) = length(sc.scenarios)
get_scenarios(sc::StochasticCase) = sc.scenarios
get_settings(sc::StochasticCase) = sc.settings
solution_algorithm(sc::StochasticCase) = solution_algorithm(sc.settings[:SolutionAlgorithm])

"""
    investment_system(sc::StochasticCase) -> System

Return scenario 1's system, which is the canonical source of shared investment variables.
"""
investment_system(sc::StochasticCase) = sc.scenarios[1].system

"""
    set_scenario_id!(system, scenario_id)

Set `period_index` to `scenario_id` on every `TimeData` object in the system.
This makes Benders budget variable names unique across scenarios, e.g.
`vCO2CapConstraint_Budget_nodeid_period2[w]` for scenario 2.
"""
function set_scenario_id!(system::System, scenario_id::Int)
    for c in keys(system.time_data)
        system.time_data[c].period_index = scenario_id
    end
    # A single visited set prevents revisiting shared objects (e.g. edges shared
    # between assets and storage components).
    visited = Set{UInt64}()
    for loc in system.locations
        _set_period_index!(loc, scenario_id, visited)
    end
    for asset in system.assets
        _set_period_index!(asset, scenario_id, visited)
    end
    return system
end

function _set_period_index!(obj, scenario_id::Int, visited::Set{UInt64}=Set{UInt64}())
    oid = objectid(obj)
    oid in visited && return
    push!(visited, oid)
    for field in Base.fieldnames(typeof(obj))
        val = getfield(obj, field)
        if val isa TimeData
            val.period_index = scenario_id
        elseif val isa AbstractAsset || val isa AbstractVertex ||
               val isa AbstractEdge  || val isa AbstractStorage
            _set_period_index!(val, scenario_id, visited)
        end
    end
end
