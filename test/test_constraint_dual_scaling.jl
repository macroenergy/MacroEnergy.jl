module TestConstraintDualScaling

using Test, MacroEnergy, JuMP, CSV, DataFrames, HiGHS
include("utilities.jl")
if is_gurobi_available()
    @eval const OPTIMIZER = Gurobi.Optimizer
else
    const OPTIMIZER = HiGHS.Optimizer
end
const MES = MacroEnergy.MacroEnergyScaling

# A cheap emitting supply competes with a clean supply costing 7/unit.
# Relaxing the emissions cap by one unit must therefore save exactly 7.
function solve_cap(cap; scale_rows=false, scale_objective=false)
    system = MacroEnergy.empty_system(@__DIR__)
    td = MacroEnergy.TimeData{MacroEnergy.CO2}(;
        time_interval=1:1:1, subperiods=[1:1:1], subperiod_indices=[1],
    )
    node = MacroEnergy.Node{MacroEnergy.CO2}(;
        id=:carbon, timedata=td, constraints=[MacroEnergy.CO2CapConstraint()],
        rhs_policy=Dict{DataType,Float64}(MacroEnergy.CO2CapConstraint => cap),
    )
    push!(system.locations, node)
    model = Model(OPTIMIZER)
    set_silent(model)
    MacroEnergy.add_linking_variables!(node, model)
    MacroEnergy.planning_model!(node, model)
    @variable(model, emitting >= 0)
    @variable(model, clean >= 0)
    @constraint(model, emitting + clean == 2e8)
    @constraint(model, emitting <= only(node.policy_budgeting_vars[:CO2CapConstraint_Budget]))
    @objective(model, Min, 7.0 * clean)
    cap_row = node.policy_budgeting_constraints[MacroEnergy.CO2CapConstraint]
    settings = MES.ScalingSettings(scale_objective_uniformly=scale_objective, objective_coeff_ub=1.0)
    model.ext[:macroenergy_scaling] = settings
    if scale_objective
        MES.scale_objective!(model, settings)
    end
    if scale_rows
        system.settings = merge(system.settings, (; ConstraintScaling=true))
        MacroEnergy.scale_constraints!(system, model)
        @test model.ext[:macroenergy_scaling] === settings
    end
    optimize!(model)
    @test termination_status(model) == JuMP.MOI.OPTIMAL
    # Read the actual Macro CSV exporter, with parameter/time/discount factors 1.
    price = mktempdir() do dir
        MacroEnergy.write_co2_cap_duals(dir, system, 1.0, 1.0)
        only(CSV.read(joinpath(dir, "co2_cap_duals.csv"), DataFrame).CO2_Shadow_Price)
    end
    return (; cost=objective_value(model) / settings.objective_scaling_factor, emitting=value(emitting), clean=value(clean),
        price, raw_price=-dual(cap_row), row_multiplier=normalized_rhs(cap_row) / cap,
        objective_factor=settings.objective_scaling_factor, variables=num_variables(model))
end

@testset "Constraint row scaling and exported CO2 duals" begin
    cap, delta = 1e8, 1000.0
    for scale_objective in (false, true)
        original = solve_cap(cap; scale_objective)
        scaled = solve_cap(cap; scale_rows=true, scale_objective)
        relaxed = solve_cap(cap + delta; scale_rows=true, scale_objective)
        finite_difference_price = (scaled.cost - relaxed.cost) / delta
        @test scaled.cost ≈ original.cost
        @test scaled.emitting ≈ original.emitting
        @test scaled.clean ≈ original.clean
        @test scaled.variables == original.variables == 3 # No proxy variables involved.
        @test scaled.row_multiplier ≈ 0.01
        @test finite_difference_price ≈ 7.0
        @test original.price ≈ finite_difference_price
        @test scaled.raw_price * scaled.row_multiplier / scaled.objective_factor ≈ finite_difference_price
        @test scaled.price ≈ finite_difference_price
        println("CO2 cap price: unscaled export=$(original.price), scaled export=$(scaled.price), ",
            "finite difference=$finite_difference_price, row multiplier=$(scaled.row_multiplier)")
    end
end


@testset "Per-model scaling metadata and repeated calls" begin
    system = MacroEnergy.empty_system(@__DIR__)
    model = Model(OPTIMIZER)
    set_silent(model)
    @variable(model, x >= 0)
    row = @constraint(model, x <= 1e8)
    @objective(model, Min, -x)
    system.settings = merge(system.settings, (; ConstraintScaling=false))
    MacroEnergy.scale_constraints!(system, model)
    settings = model.ext[:macroenergy_scaling]
    @test isempty(settings.constraint_scaling_factors)
    @test normalized_rhs(row) == 1e8
    system.settings = merge(system.settings, (; ConstraintScaling=true))
    for _ in 1:2
        MacroEnergy.scale_constraints!(system, model)
        @test model.ext[:macroenergy_scaling] === settings
        @test settings.constraint_scaling_factors[row] ≈ normalized_rhs(row) / 1e8
    end
    optimize!(model)
    @test termination_status(model) == JuMP.MOI.OPTIMAL
    @test MacroEnergy.dual_or_nan(row) ≈ -1.0
    @test isnan(MacroEnergy.dual_or_nan(row; duals_available=false))
    other = Model()
    MacroEnergy.scale_constraints!(system, other)
    @test other.ext[:macroenergy_scaling] !== settings
    @test isempty(other.ext[:macroenergy_scaling].constraint_scaling_factors)
end

@testset "Zero RHS with all original terms replaced by proxies" begin
    model = Model(OPTIMIZER)
    set_silent(model)
    @variable(model, x)
    @variable(model, y == 0)
    row = @constraint(model, 1e9 * x + 1e-9 * y <= 0.0)
    @objective(model, Min, -1e9 * x)
    settings = MES.ScalingSettings()
    model.ext[:macroenergy_scaling] = settings
    MES.scale_constraints!(model, settings)
    optimize!(model)
    @test termination_status(model) == JuMP.MOI.OPTIMAL
    @test normalized_coefficient(row, x) == 0.0
    @test normalized_coefficient(row, y) == 0.0
    @test get(settings.constraint_scaling_factors, row, 1.0) == 1.0
    @test MacroEnergy.dual_or_nan(row) ≈ -1.0
end

@testset "Balance CSV keeps input, weight and discount conversions" begin
    for scale_objective in (false, true), S in (1.0, 1000.0), discount in (1.0, 0.7)
        system = MacroEnergy.empty_system(@__DIR__)
        td = MacroEnergy.TimeData{MacroEnergy.Electricity}(;
            time_interval=1:1:1, subperiods=[1:1:1], subperiod_indices=[1],
            subperiod_weights=Dict(1=>2.0),
        )
        balance = MacroEnergy.BalanceConstraint()
        node = MacroEnergy.Node{MacroEnergy.Electricity}(;
            id=:power, timedata=td, constraints=[balance],
            balance_data=Dict(:demand=>MacroEnergy.BalanceData()),
        )
        push!(system.locations, node)
        model = Model(OPTIMIZER)
        set_silent(model)
        @variable(model, supply >= 0)
        row = @constraint(model, supply == 2e8 / S)
        balance.constraint_ref = Dict(:demand=>[row])
        @objective(model, Min, (14.0 * discount / S) * supply)
        settings = MES.ScalingSettings(scale_objective_uniformly=scale_objective, objective_coeff_ub=1.0)
        model.ext[:macroenergy_scaling] = settings
        MES.scale_objective!(model, settings)
        MES.scale_constraints!(model, settings)
        optimize!(model)
        @test termination_status(model) == JuMP.MOI.OPTIMAL
        @test MacroEnergy.dual_or_nan(row) ≈ 14.0 * discount / S
        mktempdir() do dir
            # Writing twice exercises the cached-dual path as well.
            for _ in 1:2
                MacroEnergy.write_balance_duals(dir, system, S, discount)
                prices = CSV.read(joinpath(dir, "balance_duals.csv"), DataFrame)
                @test only(prices.power) ≈ 7.0
            end
        end
    end
end

end
