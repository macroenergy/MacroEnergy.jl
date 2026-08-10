module AssetTestUtilities

using Test
using JuMP
using HiGHS
using OrderedCollections
using MacroEnergy

const MOI = JuMP.MOI

import MacroEnergy:
    BalanceConstraint,
    BalanceData,
    Node,
    SupplySegment,
    TimeData,
    add_linking_variables!,
    compute_annualized_costs!,
    define_available_capacity!,
    discount_fixed_costs!,
    empty_system,
    operation_model!,
    planning_model!

export MOI,
    build_test_model,
    make_demand_node,
    make_free_node,
    make_supply_node,
    make_test_system,
    make_test_timedata,
    push_locations!

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
        constraints = [BalanceConstraint()],
        balance_data = Dict(:demand => BalanceData()),
        supply = OrderedDict(
            :grid => SupplySegment(
                price = prices,
                min = [0.0],
                max = [Inf],
            ),
        ),
    )
end

function make_demand_node(::Type{T}, id::Symbol, timedata::TimeData{T}, demand::Vector{Float64}) where {T}
    return Node{T}(;
        id = id,
        timedata = timedata,
        constraints = [BalanceConstraint()],
        balance_data = Dict(:demand => BalanceData()),
        demand = demand,
    )
end

function make_free_node(::Type{T}, id::Symbol, timedata::TimeData{T}) where {T}
    return Node{T}(;
        id = id,
        timedata = timedata,
        balance_data = Dict(:exogenous => BalanceData()),
    )
end

function push_locations!(system, nodes...)
    append!(system.locations, collect(nodes))
    return nothing
end

function case_settings()
    return (
        PeriodLengths = [1],
        DiscountRate = 0.0,
        SolutionAlgorithm = MacroEnergy.Monolithic(),
        ExpansionHorizon = MacroEnergy.PerfectForesight(),
    )
end

function build_test_model(system)
    settings = case_settings()
    compute_annualized_costs!(system, settings)
    discount_fixed_costs!(system, settings)

    model = Model(HiGHS.Optimizer)
    set_silent(model)

    vref = @variable(model, base_name = "vREF")
    fix(vref, 1.0; force = true)
    model[:vREF] = vref
    model[:eInvestmentFixedCost] = AffExpr(0.0)
    model[:eOMFixedCost] = AffExpr(0.0)
    model[:eVariableCost] = AffExpr(0.0)

    add_linking_variables!(system, model)
    define_available_capacity!(system, model)
    planning_model!(system, model)
    operation_model!(system, model)

    @objective(model, Min, model[:eInvestmentFixedCost] + model[:eOMFixedCost] + model[:eVariableCost])
    optimize!(model)

    @test termination_status(model) == MOI.OPTIMAL
    @test primal_status(model) == MOI.FEASIBLE_POINT

    return model
end

end # module AssetTestUtilities
