module TestFlowCredit

using Test
using JuMP
using HiGHS
using MacroEnergy
using Distributed

# Existing input macros resolve these helpers in the caller's module.
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
    @testset "Input precedence and edge-prefixed rates" begin
        data = Dict{Symbol,Any}(:type => "VRE",
            :global_data => Dict{Symbol,Any}(:edges => Dict{Symbol,Any}(:edge => Dict{Symbol,Any}(:flow_credit_rate => 40))),
            :instance_data => [Dict{Symbol,Any}(:id => :a,
                :edges => Dict{Symbol,Any}(:edge => Dict{Symbol,Any}(:flow_credit_rate => 10)))])
        merged = only(ME.merge_global_data(data))
        @test merged[:instance_data][:edges][:edge][:flow_credit_rate] == 10
        system = make_hydrogen_credit_system()
        asset = ME.make(ME.Electrolyzer, Dict{Symbol,Any}(:id => :prefixed,
            :efficiency_rate => 0.5, :elec_start_vertex => :grid,
            :h2_end_vertex => :hydrogen, :h2_flow_credit_rate => 12.0), system)
        @test asset.h2_edge.flow_credit_rate == 12.0
        @test asset.elec_edge.flow_credit_rate == 0.0
    end
end

function make_battery_credit_case(inputs)
    system = make_test_system(DataType[ME.Electricity])
    td = system.time_data[:Electricity]
    push_locations!(system,
        make_supply_node(ME.Electricity, :source, td, [1.0, 10.0, 2.0]),
        make_demand_node(ME.Electricity, :sink, td, [0.0, 4.0, 0.0]))
    data = Dict{Symbol,Any}(
        :id => :credit_battery,
        :storage_can_expand => false, :storage_can_retire => false,
        :charge_can_expand => false, :charge_can_retire => false,
        :discharge_can_expand => false, :discharge_can_retire => false,
        :storage_existing_capacity => 10.0, :charge_existing_capacity => 10.0,
        :discharge_existing_capacity => 10.0,
        :charge_efficiency => 0.8, :discharge_efficiency => 0.5,
        :charge_start_vertex => :source, :discharge_end_vertex => :sink)
    asset = ME.make(ME.Battery, merge(data, inputs), system)
    push!(system.assets, asset)
    return system, asset
end

function make_biomass_credit_case(inputs)
    system = make_test_system(DataType[ME.Biomass, ME.Electricity, ME.CO2, ME.CO2Captured, ME.Hydrogen])
    td = system.time_data
    push_locations!(system,
        make_supply_node(ME.Biomass, :biomass_source, td[:Biomass], fill(4.0, 3)),
        make_supply_node(ME.Electricity, :elec_source, td[:Electricity], fill(1.0, 3)),
        make_supply_node(ME.CO2, :co2_source, td[:CO2], fill(1.0, 3)),
        make_demand_node(ME.Hydrogen, :h2_sink, td[:Hydrogen], [1.0, 2.0, 3.0]),
        make_free_node(ME.CO2, :emissions, td[:CO2]),
        make_free_node(ME.CO2Captured, :captured, td[:CO2Captured]))
    data = Dict{Symbol,Any}(
        :id => :credit_beccs, :timedata => "Biomass",
        :can_expand => false, :can_retire => false, :existing_capacity => 100.0,
        :hydrogen_production => 0.5, :electricity_consumption => 0.2,
        :fuel_consumption => 0.0, :co2_content => 0.1,
        :emission_rate => 0.15, :capture_rate => 0.25,
        :biomass_start_vertex => :biomass_source, :elec_start_vertex => :elec_source,
        :co2_start_vertex => :co2_source, :h2_end_vertex => :h2_sink,
        :co2_emission_end_vertex => :emissions, :co2_captured_end_vertex => :captured)
    asset = ME.make(ME.BECCSHydrogen, merge(data, inputs), system)
    push!(system.assets, asset)
    return system, asset
end

function test_multi_edge_credit_inputs()
    @testset "Battery credit inputs follow its VOM mapping" begin
        for inputs in (
            Dict{Symbol,Any}(:discharge_flow_credit_rate => 40.0),
            Dict{Symbol,Any}(:edges => Dict(:discharge_edge => Dict(:flow_credit_rate => 40.0))),
            Dict{Symbol,Any}(:discharge_flow_credit_rate => 12.0,
                :edges => Dict(:discharge_edge => Dict(:flow_credit_rate => 40.0))),
        )
            system, asset = make_battery_credit_case(inputs)
            @test asset.discharge_edge.flow_credit_rate == 40.0
            @test asset.charge_edge.flow_credit_rate == 0.0
            model = build_test_model(system)
            @test objective_value(model) ≈ -150.0 atol=1e-6
            @test ME.compute_flow_credit_payment(asset.discharge_edge) ≈ 160.0
            payments = ME.get_flow_credits(system, 1.0)
            @test only(payments.edge_id) == string(ME.id(asset.discharge_edge))
            @test only(payments.annual_payment) ≈ 160.0
        end
        # This documents the existing shorthand mapping; the explicit edge form is recommended.
        system, asset = make_battery_credit_case(Dict{Symbol,Any}(:flow_credit_rate => 40.0))
        @test asset.discharge_edge.flow_credit_rate == asset.charge_edge.flow_credit_rate == 0.0
        @test objective_value(build_test_model(system)) ≈ 10.0
        @test isempty(ME.get_flow_credits(system, 1.0))
    end
    @testset "BECCSHydrogen credits the selected biomass input" begin
        for inputs in (
            Dict{Symbol,Any}(:biomass_flow_credit_rate => 40.0),
            Dict{Symbol,Any}(:edges => Dict(:biomass_edge => Dict(:flow_credit_rate => 40.0))),
            Dict{Symbol,Any}(:biomass_flow_credit_rate => 12.0,
                :edges => Dict(:biomass_edge => Dict(:flow_credit_rate => 40.0))),
        )
            system, asset = make_biomass_credit_case(inputs)
            @test asset.biomass_edge.flow_credit_rate == 40.0
            @test all(iszero(ME.flow_credit_rate(edge)) for edge in ME.get_edges(system) if edge !== asset.biomass_edge)
            model = build_test_model(system)
            @test objective_value(model) ≈ 51.6 - 480.0 atol=1e-6
            payments = ME.get_flow_credits(system, 1.0)
            @test only(payments.edge_id) == string(ME.id(asset.biomass_edge))
            @test only(payments.commodity) == "Biomass"
            @test only(payments.flow_unit) == "t"
            @test only(payments.credited_flow) ≈ 12.0
            @test only(payments.annual_payment) ≈ 480.0
        end
        system, asset = make_biomass_credit_case(Dict{Symbol,Any}(:flow_credit_rate => 40.0))
        @test asset.biomass_edge.flow_credit_rate == 40.0
        @test asset.h2_edge.flow_credit_rate == 40.0
        @test_throws ArgumentError build_test_model(system)
    end
end

function test_credit_output_controls()
    @testset "Monolithic and Benders credit reports respect cost output settings" begin
        # One-period models keep a Benders solve and payment export in the short suite.
        for algorithm in ("Monolithic", "Benders")
            mktempdir() do root
                rate = 40.012345
                system = make_flow_credit_system(; rate)
                system.data_dirpath = root
                settings = settings_for(; algorithm, bounds=Dict(:1 => [-5000.0]))
                ME.prepare_case!([system], settings)
                case, model = ME.solve_case(ME.Case([system], settings), optimizer_for(algorithm))
                outcome = ME.solution_outcome(model)
                @test outcome.status == "OK" || outcome.termination_status == "NEGATIVE GAP"
                if algorithm == "Benders"
                    @test last(model.convergence.UB_hist) ≈ 100 * (3.0 - rate) atol=1e-6
                    @test last(model.convergence.LB_hist) ≈ last(model.convergence.UB_hist) atol=1e-6
                    @test isfinite(last(model.convergence.gap_hist))
                else
                    @test objective_value(model) ≈ 100 * (3.0 - rate) atol=1e-6
                end
                ME.postprocess!(case, model)
                for format in ("csv", "csv.gz", "parquet")
                    system.settings = ME.configure_settings((
                        OutputFormat=(Costs=format,), WriteOutputs=(Duals=false,),
                        OutputSignificantDigits=2))
                    output_dir = mktempdir(root)
                    ME.write_outputs(output_dir, case, model)
                    results = joinpath(output_dir, "results")
                    path = joinpath(results, "flow_credits.$format")
                    @test isfile(path)
                    @test count(startswith("flow_credits."), readdir(results)) == 1
                    payments = ME.duckdb_read(path)
                    @test only(payments.flow_credit_rate) ≈ rate
                    @test only(payments.annual_payment) ≈ 100 * rate
                    @test only(payments.discounted_payment) ≈ 100 * rate
                    @test only(payments.edge_id) == string(ME.id(electricity_edge(system.assets[1])))
                end
                system.settings = ME.configure_settings((OutputFormat="csv.gz", WriteOutputs=(Duals=false,)))
                output_dir = mktempdir(root)
                ME.write_outputs(output_dir, case, model)
                @test isfile(joinpath(output_dir, "results", "flow_credits.csv.gz"))

                system.settings = ME.configure_settings((WriteOutputs=(Costs=false, Duals=false,),))
                output_dir = mktempdir(root)
                ME.write_outputs(output_dir, case, model)
                outputs = readdir(joinpath(output_dir, "results"))
                @test !any(startswith("flow_credits."), outputs)
                @test !any(startswith("costs."), outputs)
            end
        end
    end
end


function test_credit_payment_table_formats()
    @testset "Empty and unknown-unit credit output formats" begin
        settings = settings_for()
        mktempdir() do folder
            for empty in (true, false), format in ("csv", "csv.gz", "parquet")
                annual = ME.empty_flow_credits()
                if !empty
                    push!(annual, (1, "custom", "custom_edge", "zone", "CustomAsset", "", "CustomCommodity",
                        missing, 40.012345, 100.0, 4001.2345))
                end
                path = joinpath(folder, "credits_$(empty).$format")
                written = ME.write_flow_credits(path, annual, settings)
                @test eltype(written.period_payment) == Float64
                @test eltype(written.discounted_payment) == Float64
                table = ME.duckdb_read(path)
                @test size(table, 1) == (empty ? 0 : 1)
                @test names(table) == names(written)
                if !empty
                    @test ismissing(only(table.flow_unit))
                    @test only(table.annual_payment) ≈ 4001.2345
                end
            end
        end
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
    test_multi_edge_credit_inputs()
    test_credit_output_controls()
    test_credit_payment_table_formats()
    if run_long_tests()
        mktempdir() do root
            test_flow_credit_integration(root)
        end
    end
end

end # module TestFlowCredit
