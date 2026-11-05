module TestFlowCredit

using Test
using JuMP
using HiGHS
using MacroEnergy
using Distributed

# Existing input macros resolve these helpers in the caller's module. The new
# alias normalizer must bind internally; custom assets need no new import for it.
using MacroEnergy: recursive_merge, clear_dict, default_data, get_from,
    remove_missing!, recursive_merge!, process_data

include("utilities.jl")
include("asset_tests/asset_test_utilities.jl")
using .AssetTestUtilities

const ME = MacroEnergy

function add_generator!(system; id = :flow_credit_generator, rate = 40.0, vom = 3.0,
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
        :flow_credit_rate => rate,
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

function make_flow_credit_system(; uc = false, rate = 40.0, vom = 3.0, period = 1,
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
            @test_throws ArgumentError ME.process_data(Dict{Symbol,Any}(:flow_credit_rate => bad))
        end
        @test ME.edge_default_data()[:flow_credit_rate] == 0.0
        system = make_flow_credit_system()
        asset = ME.make(ME.VRE, Dict{Symbol,Any}(:id => :default,
            :end_vertex => :load), system)
        @test asset.edge.flow_credit_rate == 0.0
        @test electricity_edge(system.assets[1]).flow_credit_rate == 40.0
        @test electricity_edge(system.assets[1]).variable_om_cost == 3.0
        @test settings_for(discount = 0).DiscountRate isa Float64
        for capacity_enabled in (false, true), constraint_enabled in (false, true)
            system = make_flow_credit_system()
            edge = electricity_edge(system.assets[1])
            edge.has_capacity = capacity_enabled
            if !constraint_enabled || !capacity_enabled
                filter!(c -> !(c isa ME.CapacityConstraint), edge.constraints)
            end
            @test objective_value(build_test_model(system)) ≈ -3700.0
        end
        for capacity_enabled in (false, true)
            thermal = make_flow_credit_system(uc = true)
            thermal.assets[1].fuel_edge.has_capacity = capacity_enabled
            thermal.assets[1].fuel_edge.flow_credit_rate = 40.0
            @test_throws ArgumentError build_test_model(thermal)
        end
        edge = electricity_edge(system.assets[1])
        bidirectional = ME.BidirectionalEdge{ME.Electricity}(;
            id = :line, timedata = edge.timedata, start_vertex = edge.start_vertex,
            end_vertex = edge.end_vertex, has_capacity = true, flow_credit_rate = 40.0)
        @test_throws ArgumentError ME.add_flow_credit_payment!(bidirectional, Model())
    end
    @testset "Benders lower-bound validation and slack guard" begin
        for bounds in (nothing, Dict(:2 => [-4000.0]), Dict(:1 => [0.0, 0.0]),
            Dict(:1 => [NaN]), Dict(:1 => [Inf]), Dict(:1 => [true]), Dict(:1 => ["-4000"]))
            system = make_flow_credit_system()
            settings = settings_for(algorithm = "Benders", bounds = bounds)
            ME.prepare_case!([system], settings)
            @test_throws ArgumentError ME.generate_model(ME.Case([system], settings),
                optimizer_for("Benders"), ME.Benders())
        end
        @test_throws ArgumentError ME.generate_operation_subproblem(make_flow_credit_system(), settings_for(), true)
        for rate in (0.0, 40.0)
            system = make_flow_credit_system(; rate)
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

function test_json_flow_credit_input()
    @testset "JSON scalar inputs" begin
        mktempdir() do root
            path = joinpath(root, "input.json")
            write(path, """
            {"edge": {"flow_credit_rate": 40, "variable_om_cost": 3},
             "settings": {"DiscountRate": 0}}
            """)
            data = ME.read_file(path)
            edge = ME.process_data(data[:edge])
            @test edge[:flow_credit_rate] == 40
            @test edge[:variable_om_cost] == 3
            @test ME.configure_case(data[:settings]).DiscountRate === 0.0
        end
    end
end

function test_flow_credit_small_model()
    @testset "Single-resource FlowCredit accounting" begin
        for uc in (false, true), (vom, rate) in ((3.0, 0.0), (3.0, 40.0), (0.0, 40.0), (0.0, 0.0), (40.0, 40.0), (50.0, 40.0))
            system = make_flow_credit_system(; uc, vom, rate)
            model = build_test_model(system)
            edge = electricity_edge(system.assets[1])
            @test objective_value(model) ≈ 100 * (vom - rate) atol = 1e-6
            @test ME.compute_variable_om_cost(edge) ≈ 100 * vom atol = 1e-6
            @test ME.compute_flow_credit_payment(edge) ≈ 100 * rate atol = 1e-6
        end
    end
end


# A user-defined asset and commodity exercise the ordinary extension interface.
abstract type TestCreditCommodity <: ME.Commodity end

struct CustomCreditAsset{T} <: ME.AbstractAsset
    id::ME.AssetId
    edge::ME.UnidirectionalEdge{T}
end

function ME.default_data(::Type{CustomCreditAsset}, id=missing, style="full")
    edge = ME.edge_default_data()
    merge!(edge, Dict{Symbol,Any}(:has_capacity => true,
        :can_expand => false, :can_retire => false, :existing_capacity => 100.0,
        :constraints => Dict{Symbol,Bool}(:CapacityConstraint => true)))
    return Dict{Symbol,Any}(:id => id, :edges => Dict{Symbol,Any}(:edge => edge))
end

function ME.make(asset_type::Type{CustomCreditAsset}, data::AbstractDict{Symbol,Any}, system::ME.System)
    id = ME.AssetId(data[:id])
    ME.@setup_data(asset_type, data, id)
    edge_key = :edge
    ME.@process_data(edge_data, data[:edges][edge_key],
        [(data[:edges][edge_key], key), (data, key)])
    commodity = data[:commodity]
    edge = ME.Edge(Symbol(id, "_edge"), edge_data, system.time_data[Symbol(nameof(commodity))],
        commodity, system.locations[1], system.locations[2])
    return CustomCreditAsset{commodity}(id, edge)
end

function make_custom_credit_system(; commodity = ME.Biomass, rate = 40.0, period = 1,
    demand = [100.0], weights = [1.0], ranges = [1:length(demand)])
    system = make_test_system(DataType[ME.Electricity, commodity]; num_steps = length(demand))
    for td in values(system.time_data)
        td.period_index = period
        td.subperiods = StepRange{Int,Int}[first(r):1:last(r) for r in ranges]
        td.subperiod_indices = collect(eachindex(ranges))
        td.subperiod_weights = Dict(i => Float64(weights[i]) for i in eachindex(ranges))
        td.subperiod_map = Dict(i => i for i in eachindex(ranges))
        td.total_hours_modeled = Int(sum(length(r) * weights[i] for (i, r) in enumerate(ranges)))
    end
    td = system.time_data[Symbol(nameof(commodity))]
    push_locations!(system,
        make_supply_node(commodity, :source, td, fill(4.0, length(demand))),
        make_demand_node(commodity, :load, td, Float64.(demand)))
    asset = ME.make(CustomCreditAsset, Dict{Symbol,Any}(:id => :custom_credit,
        :commodity => commodity, :variable_om_cost => 3.0, :flow_credit_rate => rate), system)
    push!(system.assets, asset)
    return system
end

function make_hydrogen_credit_system(; uc = false)
    system = make_test_system(DataType[ME.Electricity, ME.Hydrogen]; num_steps = 1)
    push_locations!(system,
        make_supply_node(ME.Electricity, :grid, system.time_data[:Electricity], [4.0]),
        make_demand_node(ME.Hydrogen, :hydrogen, system.time_data[:Hydrogen], [100.0]))
    asset = ME.make(ME.Electrolyzer, Dict{Symbol,Any}(:id => :electrolyzer,
        :can_expand => false, :can_retire => false, :existing_capacity => 100.0,
        :efficiency_rate => 0.5, :elec_start_vertex => :grid, :h2_end_vertex => :hydrogen,
        :variable_om_cost => 3.0, :flow_credit_rate => 40.0, :uc => uc), system)
    push!(system.assets, asset)
    return system
end

function test_general_credit_scope()
    @testset "Default edge role and non-electric commodities" begin
        for uc in (false, true)
            system = make_hydrogen_credit_system(; uc)
            model = build_test_model(system)
            @test objective_value(model) ≈ -2900.0 atol=1e-6
            @test ME.compute_flow_credit_payment(system.assets[1].h2_edge) ≈ 4000.0
            @test ME.compute_flow_credit_payment(system.assets[1].elec_edge) == 0.0
        end
        for commodity in (ME.Biomass, TestCreditCommodity), capacity_enabled in (false, true)
            system = make_custom_credit_system(; commodity)
            edge = system.assets[1].edge
            edge.has_capacity = capacity_enabled
            capacity_enabled || empty!(edge.constraints)
            model = build_test_model(system)
            @test objective_value(model) ≈ -3300.0 atol=1e-6
            table = ME.get_flow_credits(system, 1.0)
            @test only(table.commodity) == string(nameof(commodity))
            @test only(table.credited_flow) ≈ 100.0
            @test only(table.annual_payment) ≈ 4000.0
            @test commodity == ME.Biomass ? only(table.flow_unit) == "t" : ismissing(only(table.flow_unit))
        end
        system = make_test_system(DataType[ME.Electricity]; num_steps=1)
        td = system.time_data[:Electricity]
        push_locations!(system, make_supply_node(ME.Electricity, :source, td, [4.0]),
            make_demand_node(ME.Electricity, :load, td, [100.0]))
        asset = ME.make(ME.OneWayTransmissionLink, Dict{Symbol,Any}(:id => :credit_link,
            :commodity => "Electricity", :transmission_origin => :source,
            :transmission_dest => :load, :has_capacity => false,
            :flow_credit_rate => 2.0,
            :constraints => Dict{Symbol,Bool}(:CapacityConstraint => false)), system)
        push!(system.assets, asset)
        @test objective_value(build_test_model(system)) ≈ 200.0
        @test ME.compute_flow_credit_payment(asset.transmission_edge) ≈ 200.0
    end
    @testset "Legacy input names and precedence" begin
        @test ME.process_data(Dict{Symbol,Any}(:ptc_rate => 40))[:flow_credit_rate] == 40
        @test_throws ArgumentError ME.process_data(Dict{Symbol,Any}(:ptc_rate => 40, :flow_credit_rate => 40))
        data = Dict{Symbol,Any}(:type => "VRE",
            :global_data => Dict{Symbol,Any}(:edges => Dict{Symbol,Any}(:edge => Dict{Symbol,Any}(:ptc_rate => 40))),
            :instance_data => [Dict{Symbol,Any}(:id => :a,
                :edges => Dict{Symbol,Any}(:edge => Dict{Symbol,Any}(:flow_credit_rate => 10)))])
        merged = only(ME.merge_global_data(data))
        @test merged[:instance_data][:edges][:edge][:flow_credit_rate] == 10
        system = make_hydrogen_credit_system()
        asset = ME.make(ME.Electrolyzer, Dict{Symbol,Any}(:id => :legacy,
            :efficiency_rate => 0.5, :elec_start_vertex => :grid,
            :h2_end_vertex => :hydrogen, :h2_ptc_rate => 12.0), system)
        @test asset.h2_edge.flow_credit_rate == 12.0
        @test asset.elec_edge.flow_credit_rate == 0.0
    end
end

if run_long_tests()
    include("test_flow_credit_integration.jl")
end

@testset "Flow credits" begin
    test_inputs_and_bounds()
    test_json_flow_credit_input()
    test_flow_credit_small_model()
    test_general_credit_scope()
    if run_long_tests()
        mktempdir() do root
            test_flow_credit_integration(root)
        end
    end
end

end # module TestFlowCredit
