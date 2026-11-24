module TestPolicyBudgets

using Test
using HiGHS
using JuMP
import MacroEnergy
import MacroEnergy:
    Node,
    create_optimizer,
    generate_model,
    get_edges,
    get_nodes,
    id,
    load_case,
    receives_only,
    solution_algorithm

const test_path = joinpath(@__DIR__, "test_small_case")

# Stand-in edges: `receives_only` reads only the endpoints and the direction.
struct TopologyEdge
    from::Any
    to::Any
    one_way::Bool
end
MacroEnergy.start_vertex(e::TopologyEdge) = e.from
MacroEnergy.end_vertex(e::TopologyEdge) = e.to
MacroEnergy.unidirectional(e::TopologyEdge) = e.one_way

function test_receives_only_topology()
    @testset "receives_only reads the edges touching the node" begin
        case = load_case(test_path)
        sink = only(n for n in get_nodes(case.systems[1]) if id(n) == :co2_sink_1)
        other = :somewhere_else

        @test receives_only(sink, [TopologyEdge(other, sink, true), TopologyEdge(other, sink, true)])
        @test !receives_only(sink, [TopologyEdge(other, sink, true), TopologyEdge(sink, other, true)])
        @test !receives_only(sink, [TopologyEdge(other, sink, false)])
        # A node no edge touches is left alone.
        @test !receives_only(sink, TopologyEdge[])
        @test !receives_only(sink, [TopologyEdge(other, other, true)])
    end
end

function test_receive_only_budgets_are_nonnegative()
    @testset "Policy budgets are bounded at zero exactly on receive-only nodes" begin
        case = load_case(test_path)
        system = case.systems[1]
        model = generate_model(case, create_optimizer(HiGHS.Optimizer), solution_algorithm(case))
        edges = get_edges(system)

        budget_nodes = [n for n in get_nodes(system) if !isempty(n.policy_budgeting_vars)]
        @test !isempty(budget_nodes)
        bounded = 0
        for n in budget_nodes, budget in values(n.policy_budgeting_vars)
            if receives_only(n, edges)
                @test all(v -> has_lower_bound(v) && lower_bound(v) == 0.0, budget)
                bounded += 1
            else
                @test !any(has_lower_bound, budget)
            end
        end
        # The CO2 sinks of the small case only receive emissions.
        @test bounded > 0

        # Every feasible solution already satisfies the bound, so removing it leaves the optimum unchanged.
        set_silent(model)
        optimize!(model)
        @test termination_status(model) == MOI.OPTIMAL
        bounded_objective = objective_value(model)
        for n in budget_nodes, budget in values(n.policy_budgeting_vars)
            foreach(v -> has_lower_bound(v) && delete_lower_bound(v), budget)
        end
        optimize!(model)
        @test termination_status(model) == MOI.OPTIMAL
        @test objective_value(model) ≈ bounded_objective rtol = 1e-6
    end
end

test_receives_only_topology()
test_receive_only_budgets_are_nonnegative()

end # module TestPolicyBudgets
