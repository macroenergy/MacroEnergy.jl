module TestAnnualizedCosts

using Test
using MacroEnergy

import MacroEnergy:
    Battery,
    Electricity,
    VRE,
    annualized_investment_cost,
    capital_recovery_factor,
    compute_annualized_costs!,
    make,
    wacc,
    empty_system,
    Node,
    BalanceConstraint,
    TimeData


function annualized_costs_settings()
    return (
        PeriodLengths = [1],
        DiscountRate = 0.05,
        SolutionAlgorithm = MacroEnergy.Monolithic()
    )
end

function make_test_timedata(::Type{T}, num_steps::Int = 3) where {T}
    return TimeData{T}(;
        time_interval = 1:num_steps,
        hours_per_timestep = 1,
        period_index = 1,
        subperiods = [1:num_steps],
        subperiod_indices = [1],
        subperiod_weights = Dict(1 => 1.0),
        subperiod_map = Dict(1 => 1),
        total_hours_modeled = num_steps,
    )
end

function make_test_system(commodity_types::Vector{DataType}; num_steps::Int = 3)
    system = empty_system(@__DIR__)
    system.settings = MacroEnergy.default_settings()
    for commodity_type in commodity_types
        system.time_data[Symbol(nameof(commodity_type))] = make_test_timedata(commodity_type, num_steps)
    end
    return system
end

function make_supply_node(::Type{T}, id::Symbol, timedata::TimeData{T}, prices::Vector{Float64}) where {T}
    return Node{T}(;
        id = id,
        timedata = timedata,
        constraints = [BalanceConstraint()]
    )
end

function make_demand_node(::Type{T}, id::Symbol, timedata::TimeData{T}, demand::Vector{Float64}) where {T}
    return Node{T}(;
        id = id,
        timedata = timedata,
        constraints = [BalanceConstraint()],
        demand = demand,
    )
end

function push_locations!(system, nodes...)
    append!(system.locations, collect(nodes))
    return nothing
end

function make_vre_system(extra_data::Dict{Symbol,Any})
    system = make_test_system([Electricity])

    sink = make_demand_node(Electricity, :annualized_sink, system.time_data[:Electricity], [1.0, 1.0, 1.0])
    push_locations!(system, sink)

    asset = make(
        VRE,
        merge(
            Dict{Symbol,Any}(
                :id => :annualized_vre,
                :can_expand => false,
                :can_retire => false,
                :existing_capacity => 1.0,
                :availability => [1.0, 1.0, 1.0],
                :end_vertex => :annualized_sink,
                :investment_cost => 1000.0,
                :capital_recovery_period => 20,
            ),
            extra_data,
        ),
        system,
    )
    push!(system.assets, asset)

    return (; system, asset)
end

function make_battery_system(extra_data::Dict{Symbol,Any})
    system = make_test_system([Electricity])
    elec_timedata = system.time_data[:Electricity]

    source = make_supply_node(Electricity, :annualized_source, elec_timedata, [1.0, 1.0, 1.0])
    sink = make_demand_node(Electricity, :annualized_sink, elec_timedata, [1.0, 1.0, 1.0])
    push_locations!(system, source, sink)

    asset = make(
        Battery,
        merge(
            Dict{Symbol,Any}(
                :id => :annualized_battery,
                :charge_start_vertex => :annualized_source,
                :discharge_end_vertex => :annualized_sink,
                :storage_investment_cost => 1000.0,
                :storage_capital_recovery_period => 20,
            ),
            extra_data,
        ),
        system,
    )
    push!(system.assets, asset)

    return (; system, asset)
end

function test_annualized_costs()
    settings = annualized_costs_settings()

    @testset "Edge wacc handling" begin
        @testset "Omitted wacc falls back to DiscountRate" begin
            (; system, asset) = make_vre_system(Dict{Symbol,Any}())
            @test ismissing(wacc(asset.edge)) # Before computing annualized costs, wacc should be missing
            compute_annualized_costs!(system, settings)
            @test wacc(asset.edge) == settings.DiscountRate # After computing annualized costs, wacc should be set to the DiscountRate
            @test annualized_investment_cost(asset.edge) ≈
                  1000.0 * capital_recovery_factor(settings.DiscountRate, 20)
        end

        @testset "Explicit wacc is respected" begin
            (; system, asset) = make_vre_system(Dict{Symbol,Any}(:wacc => 0.02))
            @test wacc(asset.edge) == 0.02
            compute_annualized_costs!(system, settings)
            @test annualized_investment_cost(asset.edge) ≈
                  1000.0 * capital_recovery_factor(0.02, 20)
        end

        @testset "Explicit zero wacc gives straight-line annualization" begin
            (; system, asset) = make_vre_system(Dict{Symbol,Any}(:wacc => 0.0))
            compute_annualized_costs!(system, settings)
            @test wacc(asset.edge) == 0.0
            @test annualized_investment_cost(asset.edge) ≈ 1000.0 / 20
        end
    end

    @testset "Storage wacc handling" begin
        @testset "Omitted wacc falls back to DiscountRate" begin
            (; system, asset) = make_battery_system(Dict{Symbol,Any}())
            @test ismissing(wacc(asset.battery_storage)) # Before computing annualized costs, wacc should be missing
            compute_annualized_costs!(system, settings)
            @test wacc(asset.battery_storage) == settings.DiscountRate # After computing annualized costs, wacc should be set to the DiscountRate
            @test annualized_investment_cost(asset.battery_storage) ≈
                  1000.0 * capital_recovery_factor(settings.DiscountRate, 20)
        end

        @testset "Explicit wacc is respected" begin
            (; system, asset) = make_battery_system(Dict{Symbol,Any}(:storage_wacc => 0.02))
            @test wacc(asset.battery_storage) == 0.02
            compute_annualized_costs!(system, settings)
            @test annualized_investment_cost(asset.battery_storage) ≈
                  1000.0 * capital_recovery_factor(0.02, 20)
        end
    end

    return nothing
end

test_annualized_costs()

end # module TestAnnualizedCosts
