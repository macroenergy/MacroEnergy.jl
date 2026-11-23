module TestInvestmentCredit

using Test
using JuMP
using HiGHS
using JSON3
using CSV
using DataFrames
using MacroEnergy

include("asset_tests/asset_test_utilities.jl")
using .AssetTestUtilities

const ME = MacroEnergy
const WACC = 0.08
const CRP = 20
const SETTINGS = AssetTestUtilities.case_settings()

# One expandable VRE serving a peak demand of 4.
function make_credit_system(; rate = 0.0, investment_cost = 100.0, wacc = WACC, has_capacity = true,
    annualized_investment_cost = nothing)
    system = make_test_system([ME.Electricity])
    push_locations!(system, make_demand_node(ME.Electricity, :sink, system.time_data[:Electricity], [2.0, 4.0, 1.0]))
    data = Dict{Symbol,Any}(
        :id => :solar, :location => :A, :has_capacity => has_capacity,
        :can_expand => true, :can_retire => false, :existing_capacity => 0.0,
        :investment_cost => investment_cost, :wacc => wacc, :capital_recovery_period => CRP,
        :availability => [1.0, 1.0, 1.0], :end_vertex => :sink,
        :investment_credit_rate => rate,
    )
    isnothing(annualized_investment_cost) || (data[:annualized_investment_cost] = annualized_investment_cost)
    push!(system.assets, ME.make(ME.VRE, data, system))
    return system
end

# A battery whose storage capacity must be built to shift cheap supply to the peak.
function make_battery_credit_system(inputs)
    system = make_test_system(DataType[ME.Electricity])
    td = system.time_data[:Electricity]
    push_locations!(system,
        make_supply_node(ME.Electricity, :source, td, [1.0, 10.0, 2.0]),
        make_demand_node(ME.Electricity, :sink, td, [0.0, 4.0, 0.0]))
    data = Dict{Symbol,Any}(
        :id => :credit_battery,
        :storage_can_expand => true, :storage_can_retire => false, :storage_existing_capacity => 0.0,
        :storage_investment_cost => 2.0, :storage_wacc => WACC, :storage_capital_recovery_period => CRP,
        :charge_can_expand => false, :charge_can_retire => false, :charge_existing_capacity => 10.0,
        :discharge_can_expand => false, :discharge_can_retire => false, :discharge_existing_capacity => 10.0,
        :charge_start_vertex => :source, :discharge_end_vertex => :sink)
    asset = ME.make(ME.Battery, merge(data, inputs), system)
    push!(system.assets, asset)
    return system, asset
end

function test_inputs()
    @testset "Input validation and zero default" begin
        for bad in (-0.1, 1.5, Inf, NaN, true, "0.3", [0.3])
            @test_throws ArgumentError ME.process_data(Dict{Symbol,Any}(:investment_credit_rate => bad))
        end
        @test ME.edge_default_data()[:investment_credit_rate] == 0.0
        @test ME.storage_default_data()[:investment_credit_rate] == 0.0
        @test only(make_credit_system().assets).edge.investment_credit_rate == 0.0
        @test only(make_credit_system(rate = 0.3).assets).edge.investment_credit_rate == 0.3
        _, battery = make_battery_credit_system(Dict{Symbol,Any}(:storage_investment_credit_rate => 0.4))
        @test battery.battery_storage.investment_credit_rate == 0.4
        @test battery.discharge_edge.investment_credit_rate == 0.0
        # The credit applies to new capacity, so it needs a component with capacity.
        @test_throws ArgumentError build_test_model(make_credit_system(rate = 0.3, has_capacity = false))
    end
end

function test_small_model()
    @testset "A credit equals a lower investment cost" begin
        for rate in (0.0, 0.3, 1.0)
            system = make_credit_system(; rate)
            model = build_test_model(system)
            reference = build_test_model(make_credit_system(; investment_cost = 100.0 * (1 - rate)))
            @test objective_value(model) ≈ objective_value(reference) atol = 1e-9
            edge = only(system.assets).edge
            ME.undo_discount_fixed_costs!(system, SETTINGS)
            inv_pv, inv_cf = ME.compute_investment_cost(edge)
            @test all(ME.compute_investment_credit(edge) .≈ (rate * inv_pv, rate * inv_cf))
        end
    end

    @testset "A lower cost of capital as a credit" begin
        wacc_derisked = 0.02
        rate = 1 - ME.capital_recovery_factor(wacc_derisked, CRP) / ME.capital_recovery_factor(WACC, CRP)
        credited = objective_value(build_test_model(make_credit_system(; rate)))
        @test credited ≈ objective_value(build_test_model(make_credit_system(; wacc = wacc_derisked))) rtol = 1e-9
    end

    @testset "Storage credit" begin
        system, battery = make_battery_credit_system(Dict{Symbol,Any}(:storage_investment_credit_rate => 0.4))
        model = build_test_model(system)
        reference, _ = make_battery_credit_system(Dict{Symbol,Any}(:storage_investment_cost => 2.0 * 0.6))
        @test objective_value(model) ≈ objective_value(build_test_model(reference)) rtol = 1e-9
        @test value(ME.new_capacity(battery.battery_storage)) > 0
    end

    @testset "Parameter scaling leaves the rate unchanged" begin
        reference = objective_value(build_test_model(make_credit_system(rate = 0.3)))
        S = 10.0
        system = make_credit_system(rate = 0.3)
        ME.scale!(system, S)
        @test only(system.assets).edge.investment_credit_rate == 0.3
        @test objective_value(build_test_model(system)) * S^2 ≈ reference rtol = 1e-9
    end
end

function test_outputs()
    @testset "Credit table and cost breakdown" begin
        system = make_credit_system(rate = 0.3)
        build_test_model(system)
        edge = only(system.assets).edge
        credits = ME.get_investment_credits(system, SETTINGS, 1.0)
        row = only(eachrow(credits))
        capacity = value(ME.new_capacity(edge))
        @test capacity > 0
        @test row.component_id == string(ME.id(edge))
        @test row.investment_credit_rate == 0.3
        @test row.credited_capacity ≈ capacity
        @test row.overnight_credit ≈ 0.3 * 100.0 * capacity
        @test row.annual_payment ≈ 0.3 * ME.annualized_investment_cost(edge) * capacity
        credit_pv, credit_cf = ME.compute_investment_credit(edge)
        @test row.discounted_payment ≈ credit_pv
        @test row.undiscounted_payment ≈ credit_cf

        costs = ME.get_detailed_costs(system, SETTINGS, 1.0)
        credit_rows = costs.discounted[costs.discounted.category .== :InvestmentCredit, :]
        @test sum(credit_rows.value) ≈ -credit_pv

        @test isempty(ME.get_investment_credits(build_and_return(make_credit_system()), SETTINGS, 1.0))
    end

    @testset "Overnight credit with only annualized_investment_cost" begin
        annualized = 100.0 * ME.capital_recovery_factor(WACC, CRP)
        system = build_and_return(make_credit_system(rate = 0.3, investment_cost = 0.0,
            annualized_investment_cost = annualized))
        row = only(eachrow(ME.get_investment_credits(system, SETTINGS, 1.0)))
        @test row.credited_capacity > 0
        @test row.overnight_credit ≈ 0.3 * 100.0 * row.credited_capacity
    end
end

build_and_return(system) = (build_test_model(system); system)

########################## End-to-end run on test_small_case ##########################

const SMALL_CASE = joinpath(@__DIR__, "test_small_case")
const SIMPLEX = ("solver" => "simplex",)

function write_json(file::AbstractString, data)
    open(io -> JSON3.write(io, data; allow_inf = true), file, "w")
end

function write_credit_case!(dir; rate)
    mkpath(joinpath(dir, "settings"))
    cp(joinpath(SMALL_CASE, "assets"), joinpath(dir, "assets"))
    cp(joinpath(SMALL_CASE, "system"), joinpath(dir, "system"))
    cp(joinpath(SMALL_CASE, "system_data.json"), joinpath(dir, "system_data.json"))
    write_json(joinpath(dir, "settings", "macro_settings.json"), Dict("ConstraintScaling" => true, "OutputLayout" => "long"))
    write_json(joinpath(dir, "settings", "case_settings.json"), Dict("SolutionAlgorithm" => "Monolithic"))
    vre_file = joinpath(dir, "assets", "vre.json")
    data = JSON3.read(read(vre_file, String), Dict{String,Any}; allow_inf = true)
    for vre in data["VRE"]["instance_data"]
        vre["edges"]["edge"]["investment_credit_rate"] = rate
    end
    write_json(vre_file, data)
    return dir
end

function results_dir(dir)
    for (root, _, files) in walkdir(dir)
        "investment_credits.csv" in files && return root
    end
    error("no investment_credits.csv under $dir")
end

read_csv(results, file_name) = CSV.read(joinpath(results, file_name), DataFrame)
total_cost(results) = only(read_csv(results, "costs.csv").value[read_csv(results, "costs.csv").variable .== "DiscountedTotalCost"])

function test_end_to_end()
    @testset "End-to-end outputs" begin
        mktempdir() do tmp
            base = write_credit_case!(joinpath(tmp, "base"); rate = 0.0)
            run_case(base; log_to_console = false, log_to_file = false, optimizer_attributes = SIMPLEX)
            @test nrow(read_csv(results_dir(base), "investment_credits.csv")) == 0

            credited = write_credit_case!(joinpath(tmp, "credited"); rate = 0.3)
            run_case(credited; log_to_console = false, log_to_file = false, optimizer_attributes = SIMPLEX)
            results = results_dir(credited)
            credits = read_csv(results, "investment_credits.csv")
            @test nrow(credits) > 0
            @test all(credits.investment_credit_rate .== 0.3)
            by_type = read_csv(results, "costs_by_type.csv")
            category_total = sum(by_type.value[(by_type.category .== "InvestmentCredit") .& (by_type.type .!= "Total")])
            @test category_total ≈ -sum(credits.discounted_payment) rtol = 1e-6
            @test total_cost(results) < total_cost(results_dir(base))
        end
    end
end

@testset "Investment Credits" begin
    test_inputs()
    test_small_model()
    test_outputs()
    test_end_to_end()
end

end # module
