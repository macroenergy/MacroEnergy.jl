module TestAssetFlexDemandBalance

# FlexDemand against a line-by-line JuMP transcription of GenX's flexible_demand! on the same system: one node,
# priced supply, two weighted 6-hour subperiods. Objectives must match for every case.

using Test
using JuMP
using HiGHS
using MacroEnergy

include("asset_test_utilities.jl")
using .AssetTestUtilities

import MacroEnergy:
    BalanceConstraint,
    BalanceData,
    CapacityConstraint,
    Electricity,
    FlexDemand,
    FlexDemandConstraint,
    Node,
    OrderedDict,
    SupplySegment,
    TimeData,
    availability,
    end_vertex,
    id,
    make,
    pv_period_investment_cost,
    start_vertex,
    storage_level

const HPS = 6
const PRICE = [10.0, 50.0, 80.0, 20.0, 5.0, 60.0, 70.0, 30.0, 5.0, 90.0, 40.0, 15.0]
const DEMAND = [5.0, 6.0, 7.0, 6.0, 5.0, 8.0, 4.0, 5.0, 6.0, 9.0, 7.0, 5.0]
const RHO = [1.0, 0.8, 0.6, 1.0, 0.9, 0.5, 0.7, 1.0, 1.0, 0.6, 0.8, 0.9]
const WEIGHTS = [2.0, 1.0]
const T = length(DEMAND)

timedata(::Type{P}) where {P} = TimeData{P}(; time_interval = 1:T, hours_per_timestep = 1, period_index = 1,
    subperiods = [1:HPS, HPS+1:T], subperiod_indices = [1, 2], subperiod_weights = Dict(1 => WEIGHTS[1], 2 => WEIGHTS[2]),
    subperiod_map = Dict(1 => 1, 2 => 2), total_hours_modeled = T)

function flex_data(; eff, delay, advance, vom_in = 0.0, vom_out = 0.0, existing = 3.0, expand = false, inv = 0.0,
                   storage = Dict{Symbol,Any}(), defer = Dict{Symbol,Any}(), serve_node = :elec)
    data = Dict{Symbol,Any}(
        :id => :flex,
        :storage => merge(Dict{Symbol,Any}(:commodity => "Electricity"), storage),
        :edges => Dict{Symbol,Any}(
            :defer_edge => merge(Dict{Symbol,Any}(:commodity => "Electricity", :end_vertex => :elec,
                :availability => copy(RHO), :existing_capacity => existing, :can_expand => expand,
                :investment_cost => inv, :variable_om_cost => vom_in), defer),
            :serve_edge => Dict{Symbol,Any}(:commodity => "Electricity", :start_vertex => serve_node,
                :variable_om_cost => vom_out),
        ),
    )
    for (k, v) in ((:flexible_demand_energy_eff, eff), (:max_flexible_demand_delay, delay),
                   (:max_flexible_demand_advance, advance))
        v === nothing || (data[k] = v)
    end
    return data
end

function flex_system(; serve_node = :elec)
    system = make_test_system(DataType[Electricity])
    system.time_data[:Electricity] = timedata(Electricity)
    td = system.time_data[:Electricity]
    node(n) = Node{Electricity}(; id = n, timedata = td, constraints = [BalanceConstraint()],
        balance_data = Dict(:demand => BalanceData()), demand = copy(DEMAND),
        supply = OrderedDict(:grid => SupplySegment(price = copy(PRICE), min = [0.0], max = [Inf])))
    push_locations!(system, node(:elec))
    serve_node == :elec || push_locations!(system, node(serve_node))
    return system
end

function flex_case(data::AbstractDict; serve_node = :elec)
    system = flex_system(; serve_node)
    asset = make(FlexDemand, data, system)
    push!(system.assets, asset)
    return system, asset
end

flex_case(; serve_node = :elec, kw...) = flex_case(flex_data(; serve_node, kw...); serve_node)

# GenX src/model/utility.jl.
hoursbefore(p::Int, t::Int, b::Int) = div(t - 1, p) * p + mod1(t - b, p)
hoursafter(p::Int, t::Int, a::UnitRange{Int}) = div(t - 1, p) * p .+ mod1.(t .+ a, p)

# GenX flexible_demand! and the variable cost of the served demand, on one zone with an unlimited priced supply.
function genx_reference(; eff, delay, advance, vom_in = 0.0, vom_out = 0.0, existing = 3.0, expand = false,
                        inv_coeff = 0.0)
    ω = [WEIGHTS[div(t - 1, HPS) + 1] for t in 1:T]
    EP = Model(HiGHS.Optimizer)
    set_silent(EP)
    @variable(EP, gen[1:T] >= 0)
    @variable(EP, vP[1:T] >= 0)
    @variable(EP, vCHARGE_FLEX[1:T] >= 0)
    @variable(EP, vS_FLEX[1:T])
    @variable(EP, vNEWCAP >= 0)
    expand || fix(vNEWCAP, 0.0; force = true)
    eTotalCap = existing + vNEWCAP
    @constraint(EP, [t in 1:T], gen[t] - vP[t] + vCHARGE_FLEX[t] == DEMAND[t])
    @constraint(EP, [t in 1:T], vS_FLEX[t] == vS_FLEX[hoursbefore(HPS, t, 1)] - eff * vP[t] + vCHARGE_FLEX[t])
    @constraint(EP, [t in 1:T], vCHARGE_FLEX[t] <= RHO[t] * eTotalCap)
    @constraint(EP, [t in 1:T], eff * vP[t] <= eTotalCap)
    max_delay = Int(floor(delay))
    max_advance = Int(floor(advance))
    @constraint(EP, [t in 1:T], sum(vP[e] for e in hoursafter(HPS, t, 1:max_delay)) >= vS_FLEX[t])
    @constraint(EP, [t in 1:T], sum(vCHARGE_FLEX[e] for e in hoursafter(HPS, t, 1:max_advance)) >= -vS_FLEX[t])
    @objective(EP, Min, sum(ω[t] * (PRICE[t] * gen[t] + vom_out * vP[t] + vom_in * vCHARGE_FLEX[t]) for t in 1:T) +
                        inv_coeff * vNEWCAP)
    optimize!(EP)
    @assert termination_status(EP) == MOI.OPTIMAL
    return objective_value(EP)
end

no_flex_cost() = sum(WEIGHTS[div(t - 1, HPS) + 1] * PRICE[t] * DEMAND[t] for t in 1:T)

function test_structure()
    @testset "structure" begin
        system, a = flex_case(eff = 0.9, delay = 2, advance = 3)
        @test a isa FlexDemand{Electricity}
        @test start_vertex(a.defer_edge) === a.storage && id(end_vertex(a.defer_edge)) == :elec
        @test id(start_vertex(a.serve_edge)) == :elec && end_vertex(a.serve_edge) === a.storage
        @test a.storage.charge_edge === a.defer_edge && a.storage.discharge_edge === a.serve_edge
        ct = only(filter(c -> c isa FlexDemandConstraint, a.storage.constraints))
        @test (ct.efficiency, ct.max_delay, ct.max_advance) == (0.9, 2, 3)
        @test availability(a.defer_edge) == RHO
        @test count(c -> c isa CapacityConstraint, a.defer_edge.constraints) == 1
        @test count(c -> c isa BalanceConstraint, a.storage.constraints) == 1
        build_test_model(system)
        @test !any(has_lower_bound, storage_level(a.storage))
        @test Set(keys(ct.constraint_ref)) == Set([:serve_limit, :delay, :advance])
        @test all(ref -> ref isa Vector, values(ct.constraint_ref))
    end
    @testset "FlexDemandConstraint() builds with defaults, as a JSON flag does" begin
        ct = FlexDemandConstraint()
        @test (ct.efficiency, ct.max_delay, ct.max_advance) == (1.0, 0, 0)
    end
end

function test_matches_genx()
    cases = [(d, adv, eff, vin, vout, exp) for (d, adv) in ((0, 0), (2, 0), (0, 2), (2, 3), (3, 1), (8, 7), (2.7, 1.2))
             for eff in (1.0, 0.9) for (vin, vout) in ((0.0, 0.0), (1.5, 0.5)) for exp in (false, true)]
    for (d, adv, eff, vin, vout, exp) in cases
        @testset "matches GenX: delay=$d advance=$adv eff=$eff vom_in=$vin vom_out=$vout expand=$exp" begin
            kw = (eff = eff, delay = d, advance = adv, vom_in = vin, vom_out = vout,
                  existing = exp ? 1.0 : 3.0, expand = exp)
            system, a = flex_case(; kw..., inv = exp ? 40.0 : 0.0)
            model = build_test_model(system)
            inv_coeff = exp ? pv_period_investment_cost(a.defer_edge) : 0.0
            @test objective_value(model) ≈ genx_reference(; kw..., inv_coeff) rtol = 1e-7
        end
    end
end

# The comparison with GenX is only meaningful if flexibility is used in both directions.
function test_both_directions()
    @testset "delay only: the level is >= 0 and positive somewhere" begin
        system, a = flex_case(eff = 1.0, delay = 2, advance = 0)
        model = build_test_model(system)
        S = value.(storage_level(a.storage))
        @test maximum(S) > 1e-6 && minimum(S) > -1e-7
        @test objective_value(model) < no_flex_cost() - 1.0
    end
    @testset "advance only: the level is <= 0 and negative somewhere" begin
        system, a = flex_case(eff = 1.0, delay = 0, advance = 2)
        model = build_test_model(system)
        S = value.(storage_level(a.storage))
        @test minimum(S) < -1e-6 && maximum(S) < 1e-7
        @test objective_value(model) < no_flex_cost() - 1.0
    end
    @testset "no delay and no advance: no flexibility" begin
        system, _ = flex_case(eff = 1.0, delay = 0, advance = 0)
        model = build_test_model(system)
        @test objective_value(model) ≈ no_flex_cost() rtol = 1e-9
    end
end

function test_simple_input()
    @testset "simple-style input gives the same solution" begin
        kw = (eff = 0.9, delay = 2, advance = 3, vom_in = 1.5, vom_out = 0.5)
        data = Dict{Symbol,Any}(
            :id => :flex, :storage_commodity => "Electricity",
            :flexible_demand_energy_eff => 0.9, :max_flexible_demand_delay => 2, :max_flexible_demand_advance => 3,
            :defer_end_vertex => :elec, :defer_availability => copy(RHO), :defer_existing_capacity => 3.0,
            :defer_variable_om_cost => 1.5, :serve_start_vertex => :elec, :serve_variable_om_cost => 0.5)
        system, _ = flex_case(data)
        model = build_test_model(system)
        @test objective_value(model) ≈ genx_reference(; kw...) rtol = 1e-7
    end
end

function test_input_errors()
    @testset "the storage BalanceConstraint and the defer_edge CapacityConstraint cannot be disabled" begin
        @test_throws "needs its BalanceConstraint" flex_case(eff = 1.0, delay = 2, advance = 2,
            storage = Dict{Symbol,Any}(:constraints => Dict{Symbol,Bool}(:BalanceConstraint => false)))
        @test_throws "needs its CapacityConstraint" flex_case(eff = 1.0, delay = 2, advance = 2,
            defer = Dict{Symbol,Any}(:constraints => Dict{Symbol,Bool}(:CapacityConstraint => false)))
    end
    @testset "input errors" begin
        @test_throws "flexible_demand_energy_eff is required" flex_case(eff = nothing, delay = 2, advance = 2)
        @test_throws "max_flexible_demand_delay is required" flex_case(eff = 1.0, delay = nothing, advance = 2)
        @test_throws "max_flexible_demand_advance is required" flex_case(eff = 1.0, delay = 2, advance = nothing)
        @test_throws "must be > 0" flex_case(eff = 0.0, delay = 2, advance = 2)
        @test_throws "must be >= 0" flex_case(eff = 1.0, delay = -1, advance = 2)
        @test_throws "StorageCapacityConstraint is not supported" flex_case(eff = 1.0, delay = 2, advance = 2,
            storage = Dict{Symbol,Any}(:constraints => Dict{Symbol,Bool}(:StorageCapacityConstraint => true)))
        @test_throws "FlexDemandConstraint is not supported" flex_case(eff = 1.0, delay = 2, advance = 2,
            storage = Dict{Symbol,Any}(:constraints => Dict{Symbol,Bool}(:FlexDemandConstraint => true)))
        @test_throws "long_duration is not supported" flex_case(eff = 1.0, delay = 2, advance = 2,
            storage = Dict{Symbol,Any}(:long_duration => true))
        @test_throws "no energy capacity" flex_case(eff = 1.0, delay = 2, advance = 2,
            storage = Dict{Symbol,Any}(:can_expand => true))
        @test_throws "loss_fraction is not supported" flex_case(eff = 1.0, delay = 2, advance = 2,
            storage = Dict{Symbol,Any}(:loss_fraction => 0.01))
        @test_throws "has_capacity = true" flex_case(eff = 1.0, delay = 2, advance = 2,
            defer = Dict{Symbol,Any}(:has_capacity => false))
        @test_throws "same node" flex_case(eff = 1.0, delay = 2, advance = 2, serve_node = :other)
        @test_throws "not a defined commodity" flex_case(eff = 1.0, delay = 2, advance = 2,
            storage = Dict{Symbol,Any}(:commodity => "NotACommodity"))
    end
end

test_structure()
test_matches_genx()
test_both_directions()
test_simple_input()
test_input_errors()

end # module TestAssetFlexDemandBalance
