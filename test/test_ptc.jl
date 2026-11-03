module TestPTC

using Test
using JuMP
using HiGHS
using MacroEnergy
using Distributed

include("utilities.jl")
include("asset_tests/asset_test_utilities.jl")
using .AssetTestUtilities

const ME = MacroEnergy

function add_generator!(system; id = :ptc_generator, rate = 40.0, vom = 3.0,
    uc = false, capacity = 100.0, expand = false, startup = 0.0)
    edge_data = Dict{Symbol,Any}(
        :end_vertex => :load,
        :has_capacity => true,
        :can_expand => expand,
        :can_retire => false,
        :existing_capacity => expand ? 0.0 : capacity,
        :max_capacity => capacity,
        :fixed_om_cost => expand ? 1.0 : 0.0,
        :availability => [1.0],
        :variable_om_cost => vom,
        :ptc_rate => rate,
        :capacity_size => 100.0,
        :uc => uc,
        :startup_cost => startup,
        :min_up_time => 0,
        :min_down_time => 0,
        :constraints => Dict{Symbol,Bool}(
            :CapacityConstraint => true,
            :MaxCapacityConstraint => expand,
            :RampingLimitConstraint => false,
        ),
    )
    data = Dict{Symbol,Any}(
        :id => id,
        :location => :load,
        :tags => [string(id)],
        :edges => Dict{Symbol,Any}((uc ? :elec_edge : :edge) => edge_data),
    )
    if uc
        data[:transforms] = Dict{Symbol,Any}(
            :timedata => "Electricity", :fuel_consumption => 1.0, :emission_rate => 0.0,
        )
        data[:edges][:fuel_edge] = Dict{Symbol,Any}(
            :commodity => "NaturalGas", :start_vertex => :fuel_source,
        )
        data[:edges][:co2_edge] = Dict{Symbol,Any}(:end_vertex => :co2_sink)
    end
    asset = ME.make(uc ? ME.ThermalPower : ME.VRE, data, system)
    push!(system.assets, asset)
    return asset
end

electricity_edge(asset::ME.VRE) = asset.edge
electricity_edge(asset::ME.ThermalPower) = asset.elec_edge

function make_ptc_system(; uc = false, rate = 40.0, vom = 3.0, period = 1,
    demand = [100.0], weights = [1.0], ranges = [1:length(demand)],
    expand = false, startup = 0.0)
    commodities = uc ? DataType[ME.Electricity, ME.NaturalGas, ME.CO2] : DataType[ME.Electricity]
    system = make_test_system(commodities; num_steps = length(demand))
    for td in values(system.time_data)
        td.period_index = period
        td.subperiods = StepRange{Int,Int}[first(r):1:last(r) for r in ranges]
        td.subperiod_indices = collect(eachindex(ranges))
        td.subperiod_weights = Dict(i => Float64(weights[i]) for i in eachindex(ranges))
        td.subperiod_map = Dict(i => i for i in eachindex(ranges))
        td.total_hours_modeled = Int(sum(length(r) * weights[i] for (i, r) in enumerate(ranges)))
    end
    push_locations!(system, make_demand_node(ME.Electricity, :load,
        system.time_data[:Electricity], Float64.(demand)))
    if uc
        push_locations!(system,
            make_supply_node(ME.NaturalGas, :fuel_source, system.time_data[:NaturalGas], zeros(length(demand))),
            make_free_node(ME.CO2, :co2_sink, system.time_data[:CO2]),
        )
    end
    add_generator!(system; uc, rate, vom, expand, startup)
    return system
end

function settings_for(; algorithm = "Monolithic", scale = 1.0, lengths = [1],
    discount = 0.0, horizon = "PerfectForesight", bounds = nothing,
    distributed = false, myopic = Dict{Symbol,Any}())
    benders = Dict{Symbol,Any}(
        :Distributed => distributed, :MaxIter => 100, :ConvTol => 1e-8,
        :ExpectFeasibleSubproblems => true, :IncludeSubproblemSlacksAutomatically => false,
    )
    isnothing(bounds) || (benders[:OperatingCostLowerBounds] = bounds)
    return ME.configure_case(Dict{Symbol,Any}(
        :SolutionAlgorithm => algorithm, :ExpansionHorizon => horizon,
        :PeriodLengths => lengths, :DiscountRate => discount,
        :ParameterScaling => scale != 1.0, :ParameterScalingFactor => scale,
        :BendersSettings => benders,
        :MyopicSettings => merge(Dict{Symbol,Any}(:ReturnModels => true), myopic),
    ))
end

function optimizer_for(algorithm)
    options = ("output_flag" => false, "primal_feasibility_tolerance" => 1e-9,
        "dual_feasibility_tolerance" => 1e-9)
    return algorithm == "Monolithic" ? ME.create_optimizer(HiGHS.Optimizer, nothing, options) :
        ME.create_optimizer_benders(HiGHS.Optimizer, HiGHS.Optimizer, options, options)
end

function test_inputs_and_bounds()
    @testset "Input validation and zero default" begin
        for bad in (-1, Inf, NaN, true, "40", [40.0])
            @test_throws ArgumentError ME.process_data(Dict{Symbol,Any}(:ptc_rate => bad))
        end
        @test ME.edge_default_data()[:ptc_rate] == 0.0
        system = make_ptc_system()
        asset = ME.make(ME.VRE, Dict{Symbol,Any}(:id => :default,
            :end_vertex => :load), system)
        @test asset.edge.ptc_rate == 0.0
        @test electricity_edge(system.assets[1]).ptc_rate == 40.0
        @test electricity_edge(system.assets[1]).variable_om_cost == 3.0
        @test settings_for(discount = 0).DiscountRate isa Float64
        invalid = make_ptc_system()
        electricity_edge(invalid.assets[1]).has_capacity = false
        @test_throws ArgumentError ME.add_ptc_payment!(electricity_edge(invalid.assets[1]), Model())
        thermal = make_ptc_system(uc = true)
        thermal.assets[1].fuel_edge.ptc_rate = 40.0
        @test_throws ArgumentError ME.add_ptc_payment!(thermal.assets[1].fuel_edge, Model())
        edge = electricity_edge(system.assets[1])
        bidirectional = ME.BidirectionalEdge{ME.Electricity}(;
            id = :line, timedata = edge.timedata, start_vertex = edge.start_vertex,
            end_vertex = edge.end_vertex, has_capacity = true, ptc_rate = 40.0)
        @test_throws ArgumentError ME.add_ptc_payment!(bidirectional, Model())
    end
    @testset "Benders lower-bound validation and slack guard" begin
        for bounds in (nothing, Dict(:2 => [-4000.0]), Dict(:1 => [0.0, 0.0]),
            Dict(:1 => [NaN]), Dict(:1 => [Inf]), Dict(:1 => [true]), Dict(:1 => ["-4000"]))
            system = make_ptc_system()
            settings = settings_for(algorithm = "Benders", bounds = bounds)
            ME.prepare_case!([system], settings)
            @test_throws ArgumentError ME.generate_model(ME.Case([system], settings),
                optimizer_for("Benders"), ME.Benders())
        end
        @test_throws ArgumentError ME.generate_operation_subproblem(make_ptc_system(), settings_for(), true)
        for rate in (0.0, 40.0)
            system = make_ptc_system(; rate)
            bounds = rate == 0.0 ? nothing : Dict(:1 => [-4000.0])
            settings = settings_for(algorithm = "Benders", bounds = bounds, scale = 1000.0,
                lengths = [2], discount = 0.05)
            ME.prepare_case!([system], settings)
            model = ME.generate_model(ME.Case([system], settings), optimizer_for("Benders"), ME.Benders())
            factor = sum(1.05^(-year) for year in 1:2)
            expected = rate == 0.0 ? 0.0 : -4000.0 * factor / 1000.0^2
            @test JuMP.constant(model.planning_problem[:eLowerBoundOperatingCost][1]) ≈ expected
        end
    end
end

function test_json_ptc_input()
    @testset "JSON scalar inputs" begin
        mktempdir() do root
            path = joinpath(root, "input.json")
            write(path, """
            {"edge": {"ptc_rate": 40, "variable_om_cost": 3},
             "settings": {"DiscountRate": 0}}
            """)
            data = ME.read_file(path)
            edge = ME.process_data(data[:edge])
            @test edge[:ptc_rate] == 40
            @test edge[:variable_om_cost] == 3
            @test ME.configure_case(data[:settings]).DiscountRate === 0.0
        end
    end
end

function test_ptc_small_model()
    @testset "Single-resource PTC accounting" begin
        for uc in (false, true), (vom, rate) in ((3.0, 0.0), (3.0, 40.0), (0.0, 40.0), (0.0, 0.0), (40.0, 40.0), (50.0, 40.0))
            system = make_ptc_system(; uc, vom, rate)
            model = build_test_model(system)
            edge = electricity_edge(system.assets[1])
            @test objective_value(model) ≈ 100 * (vom - rate) atol = 1e-6
            @test ME.compute_variable_om_cost(edge) ≈ 100 * vom atol = 1e-6
            @test ME.compute_ptc_payment(edge) ≈ 100 * rate atol = 1e-6
        end
    end
end

if run_long_tests()
    include("test_ptc_integration.jl")
end

@testset "Electricity production tax credit" begin
    test_inputs_and_bounds()
    test_json_ptc_input()
    test_ptc_small_model()
    if run_long_tests()
        mktempdir() do root
            test_ptc_integration(root)
        end
    end
end

end # module TestPTC
