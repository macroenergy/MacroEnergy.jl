module TestBalanceData

using Test
using JuMP
using HiGHS
using MacroEnergy

const MOI = JuMP.MOI

import MacroEnergy:
    @add_balance,
    @add_to_balance,
    @add_to_storage_balance,
    @inspect_stoichiometric_balance,
    @add_stoichiometric_balance,
    BalanceConstraint,
    BalanceData,
    Electricity,
    Node,
    Storage,
    TimeData,
    Transformation,
    UnidirectionalEdge,
    add_model_constraint!,
    balance_data,
    balance_sense,
    balance_term_coefficient,
    flow,
    get_balance,
    operation_model!

function make_test_timedata(num_steps::Int = 1)
    return TimeData{Electricity}(;
        time_interval = 1:num_steps,
        hours_per_timestep = 1,
        period_index = 1,
        subperiods = [1:num_steps],
        subperiod_indices = [1],
        subperiod_weights = Dict(1 => 1.0),
        subperiod_map = Dict(1 => 1),
    )
end

function make_test_transformation_with_edges(num_steps::Int = 1)
    timedata = make_test_timedata(num_steps)

    input_node = Node{Electricity}(;
        id = :balance_input_node,
        timedata = timedata,
    )
    output_node = Node{Electricity}(;
        id = :balance_output_node,
        timedata = timedata,
    )
    transform = Transformation(;
        id = :balance_transform,
        timedata = timedata,
    )
    elec_edge = UnidirectionalEdge{Electricity}(;
        id = :balance_elec_edge,
        timedata = timedata,
        start_vertex = input_node,
        end_vertex = transform,
        capacity = 6.0,
    )
    h2_edge = UnidirectionalEdge{Electricity}(;
        id = :balance_h2_edge,
        timedata = timedata,
        start_vertex = transform,
        end_vertex = output_node,
        capacity = 6.0,
    )

    return (; input_node, output_node, transform, elec_edge, h2_edge)
end

function make_test_transformation_with_oriented_edges(
    elec_incoming::Bool,
    h2_incoming::Bool,
    num_steps::Int = 1,
)
    timedata = make_test_timedata(num_steps)

    elec_other_node = Node{Electricity}(;
        id = Symbol(:balance_elec_other_node_, elec_incoming ? :in : :out),
        timedata = timedata,
    )
    h2_other_node = Node{Electricity}(;
        id = Symbol(:balance_h2_other_node_, h2_incoming ? :in : :out),
        timedata = timedata,
    )
    transform = Transformation(;
        id = Symbol(:balance_transform_, elec_incoming ? :ein : :eout, :_, h2_incoming ? :hin : :hout),
        timedata = timedata,
    )
    elec_edge = UnidirectionalEdge{Electricity}(;
        id = Symbol(:balance_elec_edge_, elec_incoming ? :in : :out),
        timedata = timedata,
        start_vertex = elec_incoming ? elec_other_node : transform,
        end_vertex = elec_incoming ? transform : elec_other_node,
        capacity = 6.0,
    )
    h2_edge = UnidirectionalEdge{Electricity}(;
        id = Symbol(:balance_h2_edge_, h2_incoming ? :in : :out),
        timedata = timedata,
        start_vertex = h2_incoming ? h2_other_node : transform,
        end_vertex = h2_incoming ? transform : h2_other_node,
        capacity = 6.0,
    )

    return (; elec_other_node, h2_other_node, transform, elec_edge, h2_edge)
end

function make_test_transformation_with_four_edges(num_steps::Int = 1)
    timedata = make_test_timedata(num_steps)

    input_node_1 = Node{Electricity}(;
        id = :balance_input_node_1,
        timedata = timedata,
    )
    input_node_2 = Node{Electricity}(;
        id = :balance_input_node_2,
        timedata = timedata,
    )
    output_node_1 = Node{Electricity}(;
        id = :balance_output_node_1,
        timedata = timedata,
    )
    output_node_2 = Node{Electricity}(;
        id = :balance_output_node_2,
        timedata = timedata,
    )
    transform = Transformation(;
        id = :balance_transform_four_edges,
        timedata = timedata,
    )
    elec_edge = UnidirectionalEdge{Electricity}(;
        id = :balance_elec_edge_four,
        timedata = timedata,
        start_vertex = input_node_1,
        end_vertex = transform,
        capacity = 6.0,
    )
    water_edge = UnidirectionalEdge{Electricity}(;
        id = :balance_water_edge_four,
        timedata = timedata,
        start_vertex = input_node_2,
        end_vertex = transform,
        capacity = 6.0,
    )
    h2_edge = UnidirectionalEdge{Electricity}(;
        id = :balance_h2_edge_four,
        timedata = timedata,
        start_vertex = transform,
        end_vertex = output_node_1,
        capacity = 6.0,
    )
    co2_edge = UnidirectionalEdge{Electricity}(;
        id = :balance_co2_edge_four,
        timedata = timedata,
        start_vertex = transform,
        end_vertex = output_node_2,
        capacity = 6.0,
    )

    return (; input_node_1, input_node_2, output_node_1, output_node_2, transform, elec_edge, water_edge, h2_edge, co2_edge)
end

function make_test_thermalammonia_transformation(num_steps::Int = 1)
    parts = make_test_transformation_with_four_edges(num_steps)
    return (
        ;
        transform = parts.transform,
        elec_edge = parts.elec_edge,
        fuel_edge = parts.water_edge,
        nh3_edge = parts.h2_edge,
        co2_edge = parts.co2_edge,
    )
end

function make_test_storage_with_edges(num_steps::Int = 1)
    timedata = make_test_timedata(num_steps)

    start_node = Node{Electricity}(;
        id = :storage_input_node,
        timedata = timedata,
    )
    end_node = Node{Electricity}(;
        id = :storage_output_node,
        timedata = timedata,
    )
    storage = Storage{Electricity}(;
        id = :balance_storage,
        timedata = timedata,
        capacity = 4.0,
        balance_data = Dict(:storage => BalanceData()),
    )
    charge_edge = UnidirectionalEdge{Electricity}(;
        id = :storage_charge_edge,
        timedata = timedata,
        start_vertex = start_node,
        end_vertex = storage,
        capacity = 6.0,
    )
    discharge_edge = UnidirectionalEdge{Electricity}(;
        id = :storage_discharge_edge,
        timedata = timedata,
        start_vertex = storage,
        end_vertex = end_node,
        capacity = 6.0,
    )

    return (; start_node, end_node, storage, charge_edge, discharge_edge)
end

function find_term(data::BalanceData, obj, var::Symbol)
    return only(filter(term -> term.obj === obj && term.var == var, data.terms))
end

function balance_signature(data::BalanceData)
    terms = Dict((term.obj, term.var) => term.coeff for term in data.terms)
    return (sense = data.sense, constant = data.constant, terms = terms)
end

function setup_balance_test_model(parts)
    model = Model(HiGHS.Optimizer)
    set_silent(model)
    model[:vREF] = @variable(model, base_name = "vREF")

    operation_model!(parts.elec_other_node, model)
    operation_model!(parts.h2_other_node, model)
    operation_model!(parts.transform, model)
    operation_model!(parts.elec_edge, model)
    operation_model!(parts.h2_edge, model)

    ct = BalanceConstraint()
    add_model_constraint!(ct, parts.transform, model)

    return model, ct
end

@testset "Balance Data" begin
    @testset "Legacy Dict Normalizes To BalanceData" begin
        transform = Transformation(;
            id = :legacy_transform,
            timedata = make_test_timedata(),
            balance_data = Dict(:energy => Dict(:edge_a => 2.0, :edge_b => -1.5)),
        )

        data = balance_data(transform, :energy)

        @test data isa BalanceData
        @test data.sense == :eq
        @test data.constant == 0.0
        @test length(data.terms) == 2

        terms = Dict(term.obj => term for term in data.terms)
        @test terms[:edge_a].var == :flow
        @test terms[:edge_a].coeff == 2.0
        @test terms[:edge_b].var == :flow
        @test terms[:edge_b].coeff == -1.5

        @test transform.balance_data[:energy] isa BalanceData
    end

    @testset "@add_balance Rejects Non-Flow Terms" begin
        invalid_expressions = [
            :(@add_balance(x, :bad_capacity, capacity(edge) == flow(other_edge))),
            :(@add_balance(x, :bad_existing_capacity, existing_capacity(edge) == flow(other_edge))),
            :(@add_balance(x, :bad_new_capacity, new_capacity(edge) == flow(other_edge))),
            :(@add_balance(x, :bad_retired_capacity, retired_capacity(edge) == flow(other_edge))),
            :(@add_balance(x, :bad_storage_level, storage_level(storage) == flow(edge))),
        ]

        for expr in invalid_expressions
            @test_throws ErrorException macroexpand(@__MODULE__, expr)
        end
    end

    @testset "@add_balance Rejects Nonlinear Flow Terms" begin
        invalid_expressions = [
            :(@add_balance(x, :bad_rhs_coeff, flow(edge) * 2 == flow(other_edge))),
            :(@add_balance(x, :bad_divided_flow, flow(edge) / 2 == flow(other_edge))),
            :(@add_balance(x, :bad_flow_product, flow(edge) * flow(other_edge) == 0)),
            :(@add_balance(x, :bad_flow_denominator, coeff / flow(edge) == 0)),
        ]

        for expr in invalid_expressions
            @test_throws ErrorException macroexpand(@__MODULE__, expr)
        end
    end

    @testset "@add_balance Normalizes Scalar And Vector Coefficients" begin
        parts = make_test_transformation_with_edges(3)
        transform = parts.transform
        elec_edge = parts.elec_edge
        h2_edge = parts.h2_edge

        scalar_eff = 0.8
        singleton_eff = [0.7]
        profile_eff = [0.6, 0.7, 0.8]

        @add_balance(
            transform,
            :scalar_energy,
            flow(elec_edge) == scalar_eff * flow(h2_edge)
        )
        @add_balance(
            transform,
            :singleton_energy,
            flow(elec_edge) == singleton_eff * flow(h2_edge)
        )
        @add_balance(
            transform,
            :profile_energy,
            flow(elec_edge) == profile_eff * flow(h2_edge)
        )

        scalar_term = find_term(balance_data(transform, :scalar_energy), h2_edge, :flow)
        singleton_term = find_term(balance_data(transform, :singleton_energy), h2_edge, :flow)
        profile_term = find_term(balance_data(transform, :profile_energy), h2_edge, :flow)

        @test scalar_term.coeff == scalar_eff
        @test singleton_term.coeff == only(singleton_eff)
        @test profile_term.coeff == profile_eff
    end

    @testset "@add_to_balance Adds Terms And Constants" begin
        parts = make_test_transformation_with_edges()
        transform = parts.transform
        elec_edge = parts.elec_edge
        h2_edge = parts.h2_edge

        @add_to_balance(transform, :energy, flow(elec_edge) + 1.25)
        @add_to_balance(transform, :energy, 0.5 * flow(h2_edge) - 0.25)

        data = balance_data(transform, :energy)

        @test balance_sense(transform, :energy) == :eq
        @test data.constant == 1.0
        @test length(data.terms) == 2
        @test find_term(data, elec_edge, :flow).coeff == 1.0
        @test find_term(data, h2_edge, :flow).coeff == 0.5
    end

    @testset "@add_to_balance Rejects Equations" begin
        invalid_expressions = [
            :(@add_to_balance(x, :bad_eq, flow(edge_a) == flow(edge_b))),
            :(@add_to_balance(x, :bad_le, flow(edge_a) <= flow(edge_b))),
            :(@add_to_balance(x, :bad_ge, flow(edge_a) >= flow(edge_b))),
        ]

        for expr in invalid_expressions
            @test_throws ErrorException macroexpand(@__MODULE__, expr)
        end
    end

    @testset "@add_balance Handles All Edge Orientations For Eq And Inequalities" begin
        expected_coeffs = Dict(
            (true, true) => (elec = 1.0, h2 = -0.5),
            (true, false) => (elec = 1.0, h2 = 0.5),
            (false, true) => (elec = -1.0, h2 = -0.5),
            (false, false) => (elec = -1.0, h2 = 0.5),
        )

        senses = [
            (name = :eq_energy, op = :(==), expected_sense = :eq, objective = :Max),
            (name = :le_energy, op = :(<=), expected_sense = :le, objective = :Max),
            (name = :ge_energy, op = :(>=), expected_sense = :ge, objective = :Min),
        ]

        for ((elec_incoming, h2_incoming), expected) in expected_coeffs
            for sense in senses
                parts = make_test_transformation_with_oriented_edges(elec_incoming, h2_incoming)

                equation = Expr(
                    :call,
                    sense.op,
                    :(flow($(parts.elec_edge))),
                    :($(0.5) * flow($(parts.h2_edge))),
                )
                @eval @add_balance($(parts.transform), $(QuoteNode(sense.name)), $equation)

                data = balance_data(parts.transform, sense.name)
                @test balance_sense(parts.transform, sense.name) == sense.expected_sense
                @test find_term(data, parts.elec_edge, :flow).coeff == expected.elec
                @test find_term(data, parts.h2_edge, :flow).coeff == expected.h2

                model, ct = setup_balance_test_model(parts)

                @constraint(model, flow(parts.h2_edge, 1) == 1.0)
                if sense.objective == :Max
                    @objective(model, Max, flow(parts.elec_edge, 1))
                else
                    @objective(model, Min, flow(parts.elec_edge, 1))
                end
                optimize!(model)

                @test is_solved_and_feasible(model)
                @test value(flow(parts.h2_edge, 1)) ≈ 1.0 atol = 1e-8
                @test value(flow(parts.elec_edge, 1)) ≈ 0.5 atol = 1e-8
                if sense.expected_sense == :eq
                    @test constraint_object(ct.constraint_ref[sense.name][1]).set isa MOI.EqualTo{Float64}
                    @test value(get_balance(parts.transform, sense.name, 1)) ≈ 0.0 atol = 1e-8
                elseif sense.expected_sense == :le
                    @test constraint_object(ct.constraint_ref[sense.name][1]).set isa MOI.LessThan{Float64}
                    @test value(get_balance(parts.transform, sense.name, 1)) <= 1e-8
                else
                    @test constraint_object(ct.constraint_ref[sense.name][1]).set isa MOI.GreaterThan{Float64}
                    @test value(get_balance(parts.transform, sense.name, 1)) >= -1e-8
                end
            end
        end
    end

    @testset "@inspect_stoichiometric_balance Returns Pairwise Algebraic Equations" begin
        parts = make_test_transformation_with_four_edges()

        equations = @inspect_stoichiometric_balance(
            parts.transform,
            :conversion,
            1.7 * flow(parts.elec_edge) --> flow(parts.h2_edge) + 0.2 * flow(parts.co2_edge),
            flow(parts.h2_edge),
        )

        @test equations == [
            :conversion_1 => :(1.0 * flow(parts.elec_edge) - 1.7 * flow(parts.h2_edge) == 0),
            :conversion_2 => :(1.0 * flow(parts.co2_edge) - 0.2 * flow(parts.h2_edge) == 0),
        ]
    end

    @testset "@inspect_stoichiometric_balance Reuses Orientation Validation" begin
        parts = make_test_transformation_with_four_edges()

        @test_throws ErrorException begin
            @inspect_stoichiometric_balance(
                parts.transform,
                :wrong_side,
                flow(parts.h2_edge) --> flow(parts.elec_edge),
                flow(parts.h2_edge),
                verify_edge_directions = true,
            )
        end
    end

    @testset "@inspect_stoichiometric_balance Skips Orientation Validation By Default" begin
        equations = @inspect_stoichiometric_balance(
            missing_component,
            :conversion,
            1.7 * flow(missing_elec_edge) --> flow(missing_h2_edge) + 0.2 * flow(missing_co2_edge),
            flow(missing_h2_edge),
        )

        @test equations == [
            :conversion_1 => :(1.0 * flow(missing_elec_edge) - 1.7 * flow(missing_h2_edge) == 0),
            :conversion_2 => :(1.0 * flow(missing_co2_edge) - 0.2 * flow(missing_h2_edge) == 0),
        ]
    end

    @testset "ThermalAmmonia Balance Representations" begin
        fuel_consumption = 1.3095
        electricity_consumption = 0.03787
        emission_rate = 0.2
        emission_per_nh3 = fuel_consumption * emission_rate
        nh3_per_fuel = 1 / fuel_consumption
        electricity_per_fuel = electricity_consumption / fuel_consumption

        function assert_eq_balance_coeffs(transform, balance_id, expected_coeffs)
            @test balance_sense(transform, balance_id) == :eq
            data = balance_data(transform, balance_id)
            @test data.constant == 0.0
            for (edge, coeff) in expected_coeffs
                @test balance_term_coefficient(data, edge, transform, 1) == coeff
            end
        end

        add_balance_parts = make_test_thermalammonia_transformation()
        @add_balance(
            add_balance_parts.transform,
            :fuel,
            flow(add_balance_parts.fuel_edge) == fuel_consumption * flow(add_balance_parts.nh3_edge),
        )
        @add_balance(
            add_balance_parts.transform,
            :electricity,
            flow(add_balance_parts.elec_edge) == electricity_consumption * flow(add_balance_parts.nh3_edge),
        )
        @add_balance(
            add_balance_parts.transform,
            :emissions,
            emission_rate * flow(add_balance_parts.fuel_edge) == flow(add_balance_parts.co2_edge),
        )
        assert_eq_balance_coeffs(
            add_balance_parts.transform,
            :fuel,
            [
                add_balance_parts.fuel_edge => 1.0,
                add_balance_parts.nh3_edge => fuel_consumption,
            ],
        )
        assert_eq_balance_coeffs(
            add_balance_parts.transform,
            :electricity,
            [
                add_balance_parts.elec_edge => 1.0,
                add_balance_parts.nh3_edge => electricity_consumption,
            ],
        )
        assert_eq_balance_coeffs(
            add_balance_parts.transform,
            :emissions,
            [
                add_balance_parts.fuel_edge => emission_rate,
                add_balance_parts.co2_edge => 1.0,
            ],
        )

        dict_parts = make_test_thermalammonia_transformation()
        dict_parts.transform.balance_data = Dict(
            :fuel => Dict(
                dict_parts.nh3_edge.id => fuel_consumption,
                dict_parts.fuel_edge.id => 1.0,
            ),
            :electricity => Dict(
                dict_parts.nh3_edge.id => electricity_consumption,
                dict_parts.elec_edge.id => 1.0,
            ),
            :emissions => Dict(
                dict_parts.fuel_edge.id => emission_rate,
                dict_parts.co2_edge.id => 1.0,
            ),
        )
        assert_eq_balance_coeffs(
            dict_parts.transform,
            :fuel,
            [
                dict_parts.fuel_edge => 1.0,
                dict_parts.nh3_edge => fuel_consumption,
            ],
        )
        assert_eq_balance_coeffs(
            dict_parts.transform,
            :electricity,
            [
                dict_parts.elec_edge => 1.0,
                dict_parts.nh3_edge => electricity_consumption,
            ],
        )
        assert_eq_balance_coeffs(
            dict_parts.transform,
            :emissions,
            [
                dict_parts.fuel_edge => emission_rate,
                dict_parts.co2_edge => 1.0,
            ],
        )

        rhs_base_parts = make_test_thermalammonia_transformation()
        @add_stoichiometric_balance(
            rhs_base_parts.transform,
            :ammonia_production,
            electricity_consumption * flow(rhs_base_parts.elec_edge)
            + fuel_consumption * flow(rhs_base_parts.fuel_edge)
            -->
            flow(rhs_base_parts.nh3_edge)
            + emission_per_nh3 * flow(rhs_base_parts.co2_edge),
            flow(rhs_base_parts.nh3_edge),
        )

        assert_eq_balance_coeffs(
            rhs_base_parts.transform,
            :ammonia_production_1,
            [
                rhs_base_parts.elec_edge => 1.0,
                rhs_base_parts.nh3_edge => electricity_consumption,
            ],
        )
        assert_eq_balance_coeffs(
            rhs_base_parts.transform,
            :ammonia_production_2,
            [
                rhs_base_parts.fuel_edge => 1.0,
                rhs_base_parts.nh3_edge => fuel_consumption,
            ],
        )
        assert_eq_balance_coeffs(
            rhs_base_parts.transform,
            :ammonia_production_3,
            [
                rhs_base_parts.nh3_edge => emission_per_nh3,
                rhs_base_parts.co2_edge => -1.0,
            ],
        )

        lhs_base_parts = make_test_thermalammonia_transformation()
        @add_stoichiometric_balance(
            lhs_base_parts.transform,
            :ammonia_from_fuel,
            flow(lhs_base_parts.fuel_edge)
            + electricity_per_fuel * flow(lhs_base_parts.elec_edge)
            -->
            nh3_per_fuel * flow(lhs_base_parts.nh3_edge)
            + emission_rate * flow(lhs_base_parts.co2_edge),
            flow(lhs_base_parts.fuel_edge),
        )

        assert_eq_balance_coeffs(
            lhs_base_parts.transform,
            :ammonia_from_fuel_1,
            [
                lhs_base_parts.fuel_edge => -electricity_per_fuel,
                lhs_base_parts.elec_edge => 1.0,
            ],
        )
        assert_eq_balance_coeffs(
            lhs_base_parts.transform,
            :ammonia_from_fuel_2,
            [
                lhs_base_parts.fuel_edge => -nh3_per_fuel,
                lhs_base_parts.nh3_edge => -1.0,
            ],
        )
        assert_eq_balance_coeffs(
            lhs_base_parts.transform,
            :ammonia_from_fuel_3,
            [
                lhs_base_parts.fuel_edge => -emission_rate,
                lhs_base_parts.co2_edge => -1.0,
            ],
        )
    end

    @testset "@add_stoichiometric_balance Rejects Negative Terms And Constants" begin
        @test_throws ErrorException macroexpand(
            @__MODULE__,
            :(
                @add_stoichiometric_balance(
                    x,
                    :bad_unary,
                    -flow(e1) --> flow(e2),
                    flow(e2),
                )
            ),
        )

        @test_throws ErrorException macroexpand(
            @__MODULE__,
            :(
                @add_stoichiometric_balance(
                    x,
                    :bad_binary,
                    flow(e1) - flow(e2) --> flow(e3),
                    flow(e3),
                )
            ),
        )

        @test_throws ErrorException macroexpand(
            @__MODULE__,
            :(
                @add_stoichiometric_balance(
                    x,
                    :bad_constant,
                    flow(e1) + 3 --> flow(e2),
                    flow(e2),
                )
            ),
        )
    end

    @testset "@add_stoichiometric_balance Rejects Terms On The Wrong Side" begin
        parts = make_test_transformation_with_four_edges()

        @test_throws ErrorException begin
            @add_stoichiometric_balance(
                parts.transform,
                :wrong_side,
                flow(parts.h2_edge) --> flow(parts.elec_edge),
                flow(parts.h2_edge),
            )
        end
    end

    @testset "BalanceTerm Coefficient Helper Supports Time-Varying Coefficients" begin
        parts = make_test_storage_with_edges(3)
        storage = parts.storage
        charge_edge = parts.charge_edge
        discharge_edge = parts.discharge_edge

        charge_eff = [0.5, 0.6, 0.7]
        discharge_eff = 1.25

        @add_to_storage_balance(storage, discharge_eff * flow(discharge_edge))
        @add_to_storage_balance(storage, :storage, charge_eff * flow(charge_edge))

        data = balance_data(storage, :storage)

        @test balance_term_coefficient(data, charge_edge, storage, 1) == charge_eff[1]
        @test balance_term_coefficient(data, charge_edge, storage, 2) == charge_eff[2]
        @test balance_term_coefficient(data, charge_edge, storage, 3) == charge_eff[3]

        @test balance_term_coefficient(data, discharge_edge, storage, 1) == discharge_eff
        @test balance_term_coefficient(data, discharge_edge, storage, 2) == discharge_eff
        @test balance_term_coefficient(data, discharge_edge, storage, 3) == discharge_eff
    end

    @testset "@add_to_storage_balance Rejects Invalid Usage" begin
        @test_throws ErrorException macroexpand(
            @__MODULE__,
            :(@add_to_storage_balance(storage, flow(charge_edge) == flow(discharge_edge))),
        )
        @test_throws ErrorException macroexpand(
            @__MODULE__,
            :(@add_to_storage_balance(storage, :energy, flow(charge_edge))),
        )

        parts = make_test_storage_with_edges()
        bad_id = :energy
        @test_throws ErrorException @add_to_storage_balance(parts.storage, bad_id, flow(parts.charge_edge))
    end

    @testset "Legacy Flow Balances Still Update Node Balance Expressions" begin
        timedata = make_test_timedata()

        start_node = Node{Electricity}(;
            id = :start_node,
            timedata = timedata,
        )
        end_node = Node{Electricity}(;
            id = :end_node,
            timedata = timedata,
            balance_data = Dict(:demand => Dict(:legacy_edge => 1.0)),
        )
        edge = UnidirectionalEdge{Electricity}(;
            id = :legacy_edge,
            timedata = timedata,
            start_vertex = start_node,
            end_vertex = end_node,
        )

        model = Model(HiGHS.Optimizer)
        set_silent(model)
        model[:vREF] = @variable(model, base_name = "vREF")

        operation_model!(start_node, model)
        operation_model!(end_node, model)
        operation_model!(edge, model)

        ct = BalanceConstraint()
        add_model_constraint!(ct, end_node, model)

        @objective(model, Max, flow(edge, 1))
        optimize!(model)

        @test is_solved_and_feasible(model)
        @test value(flow(edge, 1)) ≈ 0.0 atol = 1e-8
        @test value(get_balance(end_node, :demand, 1)) ≈ 0.0 atol = 1e-8
    end

    @testset "Empty BalanceData Preserves Default Edge Contribution" begin
        timedata = make_test_timedata()

        start_node = Node{Electricity}(;
            id = :empty_start_node,
            timedata = timedata,
        )
        end_node = Node{Electricity}(;
            id = :empty_end_node,
            timedata = timedata,
            balance_data = Dict(:demand => BalanceData()),
        )
        edge = UnidirectionalEdge{Electricity}(;
            id = :empty_balance_edge,
            timedata = timedata,
            start_vertex = start_node,
            end_vertex = end_node,
        )

        model = Model(HiGHS.Optimizer)
        set_silent(model)
        model[:vREF] = @variable(model, base_name = "vREF")

        operation_model!(start_node, model)
        operation_model!(end_node, model)
        operation_model!(edge, model)

        ct = BalanceConstraint()
        add_model_constraint!(ct, end_node, model)

        @objective(model, Max, flow(edge, 1))
        optimize!(model)

        @test is_solved_and_feasible(model)
        @test value(flow(edge, 1)) ≈ 0.0 atol = 1e-8
        @test value(get_balance(end_node, :demand, 1)) ≈ 0.0 atol = 1e-8
    end

    @testset "Time-Varying Flow Coefficients Apply By Timestep" begin
        parts = make_test_transformation_with_edges(3)
        transform = parts.transform
        elec_edge = parts.elec_edge
        h2_edge = parts.h2_edge

        efficiency_profile = [0.6, 0.7, 0.8]

        @add_balance(
            transform,
            :energy,
            flow(elec_edge) == efficiency_profile * flow(h2_edge)
        )

        model = Model(HiGHS.Optimizer)
        set_silent(model)
        model[:vREF] = @variable(model, base_name = "vREF")

        operation_model!(parts.input_node, model)
        operation_model!(parts.output_node, model)
        operation_model!(transform, model)
        operation_model!(elec_edge, model)
        operation_model!(h2_edge, model)

        ct = BalanceConstraint()
        add_model_constraint!(ct, transform, model)

        for t in 1:3
            @constraint(model, flow(h2_edge, t) == 1.0)
        end
        @objective(model, Max, sum(flow(elec_edge, t) for t in 1:3))
        optimize!(model)

        @test is_solved_and_feasible(model)
        for (t, eff) in enumerate(efficiency_profile)
            @test value(flow(h2_edge, t)) ≈ 1.0 atol = 1e-8
            @test value(flow(elec_edge, t)) ≈ eff atol = 1e-8
            @test value(get_balance(transform, :energy, t)) ≈ 0.0 atol = 1e-8
        end
    end

end

end
