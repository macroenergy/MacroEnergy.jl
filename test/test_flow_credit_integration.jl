# Full solve and output workflows are included only in the long suite.
function solve_flow_credit_case(systems, settings, folder)
    mkpath(folder)
    for system in systems
        system.data_dirpath = folder
    end
    ME.prepare_case!(systems, settings)
    algorithm = settings.SolutionAlgorithm isa ME.Benders ? "Benders" : "Monolithic"
    case, model = ME.solve_case(ME.Case(systems, settings), optimizer_for(algorithm))
    outcome = ME.solution_outcome(model)
    @test outcome.status == "OK" || outcome.termination_status == "NEGATIVE GAP"
    if outcome.termination_status == "NEGATIVE GAP"
        scale = ME.parameter_scaling_factor(settings)
        @test abs(last(model.convergence.UB_hist) - last(model.convergence.LB_hist)) * scale^2 < 1e-5
    end
    ME.postprocess!(case, model)
    model isa ME.MyopicResults || ME.write_outputs(folder, case, model)
    return (; case, model, folder)
end

function check_payment_file(path, annual, years, factor;
    generation = 100.0, rate = 40.0, resource_id = "flow_credit_generator")
    table = ME.CSV.read(path, ME.DataFrame)
    @test names(table) == ["period", "resource_id", "edge_id", "zone", "type", "tags",
        "commodity", "flow_unit", "flow_credit_rate", "credited_flow", "annual_payment", "period_payment", "discounted_payment"]
    @test sum(table.annual_payment; init = 0.0) ≈ annual atol = 1e-6
    @test sum(table.period_payment; init = 0.0) ≈ annual * years atol = 1e-6
    @test sum(table.discounted_payment; init = 0.0) ≈ annual * factor atol = 1e-6
    if annual > 0
        @test only(table.credited_flow) ≈ generation
        @test only(table.flow_credit_rate) ≈ rate
        @test only(table.resource_id) == resource_id
        @test occursin(resource_id, only(table.tags))
    else
        @test isempty(table)
    end
    return table
end

function test_accounting(root)
    @testset "FlowCredit accounting, UC, scaling, and zero VOM" begin
        for uc in (false, true), scale in (1.0, 1000.0), (vom, rate) in ((3.0, 0.0), (3.0, 40.0), (0.0, 40.0), (0.0, 0.0), (40.0, 40.0), (50.0, 40.0))
            system = make_flow_credit_system(; uc, vom, rate)
            settings = settings_for(; scale)
            result = solve_flow_credit_case([system], settings, mktempdir(root))
            edge = electricity_edge(system.assets[1])
            @test objective_value(result.model) * scale^2 ≈ 100 * (vom - rate) atol = 1e-6
            @test ME.compute_flow_credit_payment(edge) * scale^2 ≈ 100 * rate atol = 1e-6
            @test ME.compute_variable_om_cost(edge) * scale^2 ≈ 100 * vom atol = 1e-6
            check_payment_file(joinpath(result.folder, "results", "flow_credits.csv"), 100 * rate, 1, 1; rate)
            detail = ME.get_detailed_costs(system, settings, scale)
            @test sum(detail.discounted.value) ≈ 100 * (vom - rate) atol = 1e-6
            @test sum(detail.discounted[detail.discounted.category .== :FlowCredit, :value]) ≈ -100 * rate atol = 1e-6
            ME.unscale!(system, scale)
            @test edge.flow_credit_rate == rate
        end
    end
    @testset "Startup costs remain separate" begin
        system = make_flow_credit_system(uc = true, startup = 2.0)
        system.data_dirpath = root
        settings = settings_for()
        ME.prepare_case!([system], settings)
        model = ME.generate_model(ME.Case([system], settings), optimizer_for("Monolithic"), ME.Monolithic())
        edge = electricity_edge(system.assets[1])
        fix(ME.ustart(edge, 1), 1.0; force = true)
        fix(ME.ushut(edge, 1), 1.0; force = true)
        optimize!(model)
        @test termination_status(model) == MOI.OPTIMAL
        @test ME.compute_startup_cost(edge) ≈ 200.0
        @test ME.compute_flow_credit_payment(edge) ≈ 4000.0
        @test objective_value(model) ≈ -3500.0
    end
    @testset "No payment without generation" begin
        result = solve_flow_credit_case([make_flow_credit_system(demand = [0.0])], settings_for(), mktempdir(root))
        payments = ME.CSV.read(joinpath(result.folder, "results", "flow_credits.csv"), ME.DataFrame)
        @test ME.nrow(payments) == 1
        @test only(payments.flow_credit_rate) == 40.0
        @test only(payments.credited_flow) == 0.0
        @test only(payments.annual_payment) == 0.0
    end

end

function test_non_electric_credit(root)
    @testset "Non-electric credit across periods and algorithms" begin
        for algorithm in ("Monolithic", "Benders"), scale in (1.0, 1000.0)
            systems = [make_custom_credit_system(period=p, rate=p == 1 ? 40.0 : 0.0,
                demand=[20.0,30.0], weights=[2.0,3.0], ranges=[1:1,2:2]) for p in 1:2]
            settings = settings_for(; algorithm, scale, lengths=[2,3], discount=0.05,
                bounds=Dict(:1 => [-8000.0,-12000.0], :2 => [0.0,0.0]))
            result = solve_flow_credit_case(systems, settings, mktempdir(root))
            factors = [sum(1.05^(-y) for y in 1:2),sum(1.05^(-y) for y in 3:5)]
            expected = 130 * (-33) * factors[1] + 130 * 7 * factors[2]
            actual = algorithm == "Monolithic" ? objective_value(result.model) : last(result.model.convergence.UB_hist)
            @test actual * scale^2 ≈ expected atol=1e-5
            for p in 1:2
                table = ME.CSV.read(joinpath(result.folder,"results_period_$p","flow_credits.csv"),ME.DataFrame)
                @test sum(table.annual_payment; init=0.0) ≈ (p == 1 ? 5200.0 : 0.0)
                @test sum(table.discounted_payment; init=0.0) ≈ (p == 1 ? 5200.0 * factors[p] : 0.0)
                if p == 1
                    @test only(table.commodity) == "Biomass"
                    @test only(table.flow_unit) == "t"
                    @test only(table.credited_flow) ≈ 130.0
                end
            end
        end
    end
end

function test_flow_credit_integration(root)
    test_accounting(root)
    test_non_electric_credit(root)
    @testset "Weighted periods, expiry, and algorithm agreement" begin
        for algorithm in ("Monolithic", "Benders"), scale in (1.0, 1000.0), uc in (false, true)
            systems = [make_flow_credit_system(; uc, period = p, rate = p == 1 ? 40.0 : 0.0,
                demand = [20.0, 30.0], ranges = [1:1, 2:2], weights = [2.0, 3.0]) for p in 1:2]
            settings = settings_for(; algorithm, scale, lengths = [2, 3], discount = 0.05,
                bounds = Dict(:1 => [-8000.0, -12000.0], :2 => [0.0, 0.0]))
            result = solve_flow_credit_case(systems, settings, mktempdir(root))
            factors = [sum(1.05^(-year) for year in 1:2), sum(1.05^(-year) for year in 3:5)]
            expected = 130 * (-37) * factors[1] + 130 * 3 * factors[2]
            actual = algorithm == "Monolithic" ? objective_value(result.model) : last(result.model.convergence.UB_hist)
            @test actual * scale^2 ≈ expected atol = 1e-5
            for p in 1:2
                check_payment_file(joinpath(result.folder, "results_period_$p", "flow_credits.csv"),
                    p == 1 ? 5200.0 : 0.0, [2, 3][p], factors[p]; generation = 130.0)
            end
        end
    end
    @testset "FlowCredit changes capacity and dispatch" begin
        for algorithm in ("Monolithic", "Benders"), rate in (0.0, 40.0)
            system = make_flow_credit_system(; rate, vom = 30.0, expand = true, demand = [50.0])
            add_generator!(system; id = :competitor, rate = 0.0, vom = 20.0)
            # MaxCapacityConstraint enforces 100 MW, so -40 * 100 is valid for all plans.
            settings = settings_for(; algorithm, bounds = Dict(:1 => [-4000.0]))
            result = solve_flow_credit_case([system], settings, mktempdir(root))
            capacity = ME.CSV.read(joinpath(result.folder, "results", "capacity.csv"), ME.DataFrame)
            selected = capacity[(capacity.resource_id .== "flow_credit_generator") .& (capacity.variable .== "capacity"), :value]
            @test only(selected) ≈ (rate == 0 ? 0.0 : 50.0) atol = 1e-5
            flows = ME.CSV.read(joinpath(result.folder, "results", "flows.csv"), ME.DataFrame)
            selected = flows[(flows.resource_id .== "flow_credit_generator") .& (flows.variable .== "flow"), :value]
            @test only(selected) ≈ (rate == 0 ? 0.0 : 50.0) atol = 1e-5
        end
    end
    @testset "Myopic restart retains period rates" begin
        for algorithm in ("Monolithic", "Benders"), scale in (1.0, 1000.0)
            folder = mktempdir(root)
            systems = [make_flow_credit_system(period = p, rate = p == 1 ? 40.0 : 0.0) for p in 1:2]
            settings = settings_for(; algorithm, scale, horizon = "Myopic", lengths = [2, 3], discount = 0.05,
                bounds = Dict(:1 => [-4000.0], :2 => [0.0]))
            result = solve_flow_credit_case(systems, settings, folder)
            factors = [sum(1.05^(-year) for year in 1:2), sum(1.05^(-year) for year in 3:5)]
            check_payment_file(joinpath(result.model.output_path, "results_period_1", "flow_credits.csv"), 4000.0, 2, factors[1])
            check_payment_file(joinpath(result.model.output_path, "results_period_2", "flow_credits.csv"), 0.0, 3, factors[2])
            restart = Dict{Symbol,Any}(:Restart => Dict(:enabled => true,
                :folder => basename(result.model.output_path), :from_period => 2))
            systems = [make_flow_credit_system(period = p, rate = p == 1 ? 40.0 : 0.0) for p in 1:2]
            settings = settings_for(; algorithm, scale, horizon = "Myopic", lengths = [2, 3], discount = 0.05,
                bounds = Dict(:1 => [-4000.0], :2 => [0.0]), myopic = restart)
            restarted = solve_flow_credit_case(systems, settings, folder)
            check_payment_file(joinpath(restarted.model.output_path, "results_period_2", "flow_credits.csv"), 0.0, 3, factors[2])
            @test electricity_edge(systems[2].assets[1]).flow_credit_rate == 0.0
        end
    end
    @testset "Distributed Benders output" begin
        workers = addprocs(2; exeflags = ["--project=$(dirname(Base.active_project()))", "--startup-file=no"])
        try
            @sync for worker in workers
                @async remotecall_fetch(Core.eval, worker, Main, :(using MacroEnergy, HiGHS))
            end
            for scale in (1.0, 1000.0)
                system = make_flow_credit_system(uc = true, demand = [20.0, 30.0], ranges = [1:1, 2:2], weights = [2.0, 3.0])
                settings = settings_for(; algorithm = "Benders", scale, distributed = true,
                    lengths = [3], discount = 0.05, bounds = Dict(:1 => [-8000.0, -12000.0]))
                result = solve_flow_credit_case([system], settings, mktempdir(root))
                factor = sum(1.05^(-year) for year in 1:3)
                @test last(result.model.convergence.UB_hist) * scale^2 ≈ -4810 * factor atol = 1e-5
                check_payment_file(joinpath(result.folder, "results", "flow_credits.csv"), 5200.0, 3, factor;
                    generation = 130.0)
            end
        finally
            rmprocs(workers)
        end
    end
end
