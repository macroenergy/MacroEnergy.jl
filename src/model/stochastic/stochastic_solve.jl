"""
    solve_case(sc::StochasticCase, opt::Optimizer) -> (sc, model, cpu_time)

Solve a stochastic case using the monolithic (extensive form) solver.
"""
function solve_case(sc::StochasticCase, opt::Optimizer)
    solve_case(sc, opt, solution_algorithm(sc))
end

function solve_case(sc::StochasticCase, opt::Optimizer, ::Monolithic)
    @info("*** Running stochastic case with monolithic solver ***")
    model = generate_stochastic_model(sc)
    set_optimizer(model, opt)

    if investment_system(sc).settings.ConstraintScaling
        @info "Scaling constraints and RHS"
        scale_constraints!(model)
    end

    start_optimization = time()
    optimize!(model)
    cpu_optimization = time() - start_optimization

    return (sc, model, cpu_optimization)
end
