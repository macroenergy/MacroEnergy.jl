module TestLoadMethods

using Macro
using Test
using CSV, DataFrames

include("test_config.jl")


function test_load_inputs()

    test_path = joinpath(@__DIR__, "test_inputs")

    # read the true data for demand and capacity factor
    demand_true = CSV.read(joinpath(test_path, "system/demand_data/electricity_demand.csv"), DataFrame)
    cf_true = CSV.read(joinpath(test_path, "assets/capacity_factor_data/vre.csv"), DataFrame)
    fuel_data_true = CSV.read(joinpath(test_path, "system/fuel_data/naturalgas_prices.csv"), DataFrame)

    # test the loading of the settings
    settings_path = joinpath(test_path, "settings", "macro_settings.yml")
    macro_settings = configure_settings(settings_path)
    TestConfig.test_configure_settings(settings_path)

    # read inputs
    (commodities, time_data, nodes, edges, assets) = load_inputs(macro_settings, test_path)

    # test the commodities
    @test typeof(commodities) == Dict{Symbol,DataType}
    @test length(commodities) == 4
    @test commodities[:Electricity] == Electricity
    @test commodities[:Hydrogen] == Hydrogen
    @test commodities[:NaturalGas] == NaturalGas
    @test commodities[:CO2] == CO2

    # test the time data
    @test typeof(time_data) == Dict{Symbol,Macro.TimeData}
    @test length(time_data) == 4
    @test time_data[:Electricity].time_interval == 1:1:8760
    @test time_data[:Electricity].subperiods[1] == 1:1:8760
    # @test time_data[:Electricity].subperiod_weights # TODO: Implement this

    # test the electricity node
    elec_node = nodes[:elec_MA]
    @test typeof(elec_node) == Node{Electricity}
    @test elec_node.id == :elec_MA
    @test elec_node.demand == demand_true.MA
    @test elec_node.demand_header == :MA
    @test elec_node.timedata == time_data[:Electricity]
    @test elec_node.max_nsd == [1.0, 0.04, 0.024, 0.003]
    @test elec_node.price_nsd == [1.0, 0.9, 0.55, 0.2]
    @test typeof(elec_node.constraints[1]) == MaxNonServedDemandPerSegmentConstraint
    @test typeof(elec_node.constraints[2]) == DemandBalanceConstraint
    @test typeof(elec_node.constraints[3]) == MaxNonServedDemandConstraint

    # test the natural gas edges
    natgas_edge = edges[:natgas_MA_to_CT]
    @test typeof(natgas_edge) == Edge{NaturalGas}
    @test natgas_edge.timedata == time_data[:NaturalGas]
    @test natgas_edge.start_node == nodes[:natgas_MA]
    @test natgas_edge.end_node == nodes[:natgas_CT]
    @test natgas_edge.existing_capacity == 0.0
    @test natgas_edge.unidirectional == false
    @test natgas_edge.max_line_reinforcement == Inf
    @test natgas_edge.line_reinforcement_cost == 0.0
    @test natgas_edge.can_expand == true
    @test natgas_edge.op_cost == 0.0
    @test natgas_edge.distance == 0.0
    @test natgas_edge.line_loss_fraction == 0.0

    # test one eletrcity edge
    elec_edge = edges[:elec_MA_to_CT]
    @test typeof(elec_edge) == Edge{Electricity}
    @test elec_edge.timedata == time_data[:Electricity]
    @test elec_edge.start_node == nodes[:elec_MA]
    @test elec_edge.end_node == nodes[:elec_CT]
    @test elec_edge.existing_capacity == 2950.0
    @test elec_edge.unidirectional == false
    @test elec_edge.max_line_reinforcement == 2950.0
    @test elec_edge.line_reinforcement_cost == 12060
    @test elec_edge.distance == 123.06
    @test elec_edge.can_expand == true
    @test elec_edge.op_cost == 0.0
    @test elec_edge.line_loss_fraction == 0.01
    @test typeof(elec_edge.constraints[1]) == CapacityConstraint

    ## test the solarpv asset
    asset_testing = assets[:asset_testing]
    @test typeof(asset_testing) == NaturalGasPower
    # test the transformation part
    t = asset_testing.natgaspower_transform
    @test typeof(t) == Transformation
    @test t.id == :NaturalGasPower
    @test t.timedata == time_data[:Electricity]
    @test t.stoichiometry_balance_names == [:energy, :emissions, :storage]
    # @test t.min_capacity_storage == 1000,
    # @test t.max_capacity_storage == 1000,
    # @test t.existing_capacity_storage == 500,
    # @test t.can_expand == true,
    # @test t.can_retire == true,
    # @test t.investment_cost_storage == 1000,
    # @test t.fixed_om_cost_storage == 10,
    # @test t.min_storage_level == 6,
    # @test t.min_duration == 1,
    # @test t.max_duration == 1,
    # @test t.storage_loss_fraction == 0.5
    # @test t.discharge_edge == :discharge
    # @test t.charge_edge == :charge
    @test typeof(t.constraints[1]) == StoichiometryBalanceConstraint

    # test the electricity edge
    e_tedge = asset_testing.e_tedge
    @test typeof(e_tedge) == TEdgeWithUC{Electricity}
    @test e_tedge.id == :E
    @test e_tedge.node == nodes[:elec_MA]
    @test e_tedge.transformation == t
    @test e_tedge.timedata == time_data[:Electricity]
    @test e_tedge.direction == :output
    @test e_tedge.has_planning_variables == true
    @test e_tedge.can_retire == true
    @test e_tedge.can_expand == true
    @test e_tedge.capacity_size == 1000
    @test e_tedge.capacity_factor == cf_true.asset_testing
    @test e_tedge.st_coeff == Dict(:energy => 2.1775, :emissions => 0.0)
    @test e_tedge.min_capacity == 5
    @test e_tedge.max_capacity == 2000
    @test e_tedge.existing_capacity == 20
    @test e_tedge.investment_cost == 1000
    @test e_tedge.fixed_om_cost == 10
    @test e_tedge.variable_om_cost == 0.5
    @test e_tedge.ramp_up_fraction == 0.1
    @test e_tedge.ramp_down_fraction == 0.1
    @test e_tedge.min_flow_fraction == 20
    @test e_tedge.min_up_time == 50
    @test e_tedge.min_down_time == 50
    @test e_tedge.start_cost == 10
    @test e_tedge.start_fuel == 10
    @test e_tedge.start_fuel_stoichiometry_name == :energy
    @test typeof(e_tedge.constraints[1]) == MinFlowConstraint
    @test typeof(e_tedge.constraints[2]) == MinDownTimeConstraint
    @test typeof(e_tedge.constraints[3]) == MinUpTimeConstraint
    @test typeof(e_tedge.constraints[4]) == CapacityConstraint
    @test typeof(e_tedge.constraints[5]) == RampingLimitConstraint

    # test the natural gas edge
    ng_tedge = asset_testing.ng_tedge
    @test typeof(ng_tedge) == TEdge{NaturalGas}
    @test ng_tedge.id == :NG
    @test ng_tedge.node == nodes[:natgas_MA]
    @test ng_tedge.transformation == t
    @test ng_tedge.timedata == time_data[:NaturalGas]
    @test ng_tedge.direction == :input
    @test ng_tedge.has_planning_variables == true
    @test ng_tedge.can_retire == true
    @test ng_tedge.can_expand == true
    @test ng_tedge.capacity_size == 1000
    @test ng_tedge.min_capacity == 5
    @test ng_tedge.max_capacity == 2000
    @test ng_tedge.existing_capacity == 20
    @test ng_tedge.investment_cost == 1000
    @test ng_tedge.fixed_om_cost == 10
    @test ng_tedge.variable_om_cost == 0.5
    @test ng_tedge.ramp_up_fraction == 0.1
    @test ng_tedge.ramp_down_fraction == 0.1
    @test ng_tedge.min_flow_fraction == 20
    @test ng_tedge.st_coeff == Dict(:energy => 1.0, :emissions => 0.05306)
    
    # test the fuel data
    @test ng_tedge.price == fuel_data_true.natgas_MA
    @test ng_tedge.price_header == :natgas_MA
    @test ng_tedge.st_coeff[:emissions] == 0.05306

    # test the system
    system = Macro.create_system(nodes, edges, assets)
    @test length(system) == 28
    @test typeof(system[1]) == Node{Electricity}
    @test typeof(system[length(nodes)+1]) == Edge{NaturalGas}
    @test typeof(system[length(nodes)+length(edges)+1]) == ElectrolyzerTransform
end

test_load_inputs()

end # module TestLoadMethods
