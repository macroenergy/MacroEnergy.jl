module TestBendersSubproblems

using Test
using HiGHS
using JuMP
import MacroEnergy:
    System,
    create_optimizer,
    generate_decomposed_system,
    get_settings,
    initialize_subproblem,
    load_case

const test_path = joinpath(@__DIR__, "test_small_case")

function build_subproblem(; direct::Bool, names::Bool)
    case = load_case(test_path)
    s = first(generate_decomposed_system(case.systems))
    # A copy with other settings, rather than assigning `s.settings`, so the test does not depend
    # on whether a loaded System's settings can be reassigned.
    settings = merge(s.settings, (EnableJuMPDirectModel = direct, EnableJuMPStringNames = names))
    system = System(s.data_dirpath, settings, s.commodities, s.time_data, s.assets, s.locations, s.input_data, s.constraints)
    optimizer = create_optimizer(HiGHS.Optimizer, nothing, ())
    return initialize_subproblem(system, optimizer, get_settings(case), false)
end

function test_subproblem_settings()
    @testset "Benders subproblems follow EnableJuMPDirectModel and EnableJuMPStringNames" begin
        for direct in (false, true), names in (false, true)
            @testset "direct = $direct, names = $names" begin
                model, linking = build_subproblem(; direct, names)
                @test (mode(model) == DIRECT) == direct
                @test solver_name(model) == "HiGHS"

                # Linking variables are looked up by name in every configuration.
                @test !isempty(linking)
                linking_vars = [variable_by_name(model, n) for n in linking]
                @test all(!isnothing, linking_vars)

                operational = setdiff(all_variables(model), [linking_vars; model[:vREF]])
                @test !isempty(operational)
                if names
                    @test any(v -> !isempty(name(v)), operational)
                else
                    @test all(v -> isempty(name(v)), operational)
                end
            end
        end
    end
end

test_subproblem_settings()

end # module TestBendersSubproblems
