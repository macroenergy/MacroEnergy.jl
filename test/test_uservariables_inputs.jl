module TestUserVariablesInputs

using Test
using MacroEnergy
using JuMP
using HiGHS

import MacroEnergy: check_and_convert_variables!

function make_test_timedata()
    return MacroEnergy.TimeData{MacroEnergy.Electricity}(;
        time_interval = 1:3,
        hours_per_timestep = 1,
        subperiods = [1:3],
        subperiod_indices = [1],
        subperiod_weights = Dict(1 => 1.0),
        period_index = 1,
    )
end

function make_test_node(variables)
    return MacroEnergy.Node{MacroEnergy.Electricity}(;
        id = :test_node,
        timedata = make_test_timedata(),
        variables = variables,
    )
end

function make_test_edge(variables; has_capacity=false)
    timedata = make_test_timedata()
    start_node = MacroEnergy.Node{MacroEnergy.Electricity}(;
        id = :start_node,
        timedata = timedata,
    )
    end_node = MacroEnergy.Node{MacroEnergy.Electricity}(;
        id = :end_node,
        timedata = timedata,
    )
    return MacroEnergy.Edge(
        :test_edge,
        Dict{Symbol,Any}(
            :has_capacity => has_capacity,
            :variables => variables,
        ),
        timedata,
        MacroEnergy.Electricity,
        start_node,
        end_node,
    )
end

function test_empty_variables_input_returns_empty_dict()
    variables = MacroEnergy.check_and_convert_uservar(nothing, :test_node)

    @test variables == Dict{Symbol,MacroEnergy.UserVariable}()
end

function test_named_variable_string_is_converted_to_symbol()
    variables_input = [
        Dict{Symbol,Any}(:name => "dispatch", :time_varying => true),
    ]

    variables = MacroEnergy.check_and_convert_uservar(variables_input, :test_node)

    @test length(variables) == 1
    @test haskey(variables, :dispatch)
    @test variables[:dispatch].name == :dispatch
    @test variables[:dispatch].time_varying == true
    @test variables[:dispatch].operation_variable == true
    @test variables[:dispatch].number_segments == 1
    @test variables[:dispatch].variable_type == :Continuous
    @test variables[:dispatch].lower_bound === nothing
    @test variables[:dispatch].upper_bound === nothing
end

function test_named_variable_symbol_is_preserved()
    variables_input = [
        Dict{Symbol,Any}(:name => :reserve, :time_varying => false, :operation_variable => false, :number_segments => 3),
    ]

    variables = MacroEnergy.check_and_convert_uservar(variables_input, :test_node)

    @test haskey(variables, :reserve)
    @test variables[:reserve].name == :reserve
    @test variables[:reserve].time_varying == false
    @test variables[:reserve].operation_variable == false
    @test variables[:reserve].number_segments == 3
    @test variables[:reserve].variable_type == :Continuous
end

function test_variable_type_and_bounds_are_parsed()
    variables_input = [
        Dict{Symbol,Any}(
            :name => "reserve",
            :time_varying => false,
            :type => "Int",
            :lower_bound => 1,
            :upper_bound => 4.5,
        ),
    ]

    variables = MacroEnergy.check_and_convert_uservar(variables_input, :test_node)

    @test variables[:reserve].variable_type == :Int
    @test variables[:reserve].lower_bound == 1.0
    @test variables[:reserve].upper_bound == 4.5
end

function test_operation_variable_defaults_to_true()
    variables_input = [
        Dict{Symbol,Any}(:name => "dispatch", :time_varying => true),
    ]

    variables = MacroEnergy.check_and_convert_uservar(variables_input, :test_node)

    @test variables[:dispatch].operation_variable == true
end

function test_non_bool_operation_variable_errors()
    variables_input = [
        Dict{Symbol,Any}(:name => "dispatch", :time_varying => true, :operation_variable => "false"),
    ]

    @test_throws ErrorException MacroEnergy.check_and_convert_uservar(variables_input, :test_node)
end

function test_non_dict_variable_entry_errors()
    variables_input = Any[1]

    @test_throws ErrorException MacroEnergy.check_and_convert_uservar(variables_input, :test_node)
end

function test_invalid_name_type_errors()
    variables_input = [
        Dict{Symbol,Any}(:name => 1.5, :time_varying => true),
    ]

    @test_throws ErrorException MacroEnergy.check_and_convert_uservar(variables_input, :test_node)
end

function test_missing_time_varying_errors()
    variables_input = [
        Dict{Symbol,Any}(:name => "dispatch"),
    ]

    @test_throws ErrorException MacroEnergy.check_and_convert_uservar(variables_input, :test_node)
end

function test_non_bool_time_varying_errors()
    variables_input = [
        Dict{Symbol,Any}(:name => "dispatch", :time_varying => "true"),
    ]

    @test_throws ErrorException MacroEnergy.check_and_convert_uservar(variables_input, :test_node)
end

function test_non_int_number_segments_errors()
    variables_input = [
        Dict{Symbol,Any}(:name => "dispatch", :time_varying => true, :number_segments => 2.0),
    ]

    @test_throws ErrorException MacroEnergy.check_and_convert_uservar(variables_input, :test_node)
end

function test_non_positive_number_segments_errors()
    variables_input = [
        Dict{Symbol,Any}(:name => "dispatch", :time_varying => true, :number_segments => 0),
    ]

    @test_throws ErrorException MacroEnergy.check_and_convert_uservar(variables_input, :test_node)
end

function test_invalid_variable_type_errors()
    variables_input = [
        Dict{Symbol,Any}(:name => "dispatch", :time_varying => true, :type => "Binary"),
    ]

    @test_throws ErrorException MacroEnergy.check_and_convert_uservar(variables_input, :test_node)
end

function test_non_numeric_bounds_error()
    variables_input = [
        Dict{Symbol,Any}(:name => "dispatch", :time_varying => true, :lower_bound => "0.0"),
    ]

    @test_throws ErrorException MacroEnergy.check_and_convert_uservar(variables_input, :test_node)
end

function test_invalid_bound_order_errors()
    variables_input = [
        Dict{Symbol,Any}(:name => "dispatch", :time_varying => true, :lower_bound => 3.0, :upper_bound => 1.0),
    ]

    @test_throws ErrorException MacroEnergy.check_and_convert_uservar(variables_input, :test_node)
end

function test_semi_types_require_bounds()
    semiint_input = [
        Dict{Symbol,Any}(:name => "dispatch", :time_varying => true, :type => "Semiinteger", :lower_bound => 1.0),
    ]
    semicont_input = [
        Dict{Symbol,Any}(:name => "dispatch", :time_varying => true, :type => "Semicontinuous", :upper_bound => 2.0),
    ]

    @test_throws ErrorException MacroEnergy.check_and_convert_uservar(semiint_input, :test_node)
    @test_throws ErrorException MacroEnergy.check_and_convert_uservar(semicont_input, :test_node)
end

function test_check_and_convert_variables_bang_updates_data_in_place()
    data = Dict{Symbol,Any}(
        :id => :test_node,
        :variables => [
            Dict{Symbol,Any}(:name => "dispatch", :time_varying => true),
            Dict{Symbol,Any}(:name => "reserve", :time_varying => false, :number_segments => 2),
        ],
    )

    check_and_convert_variables!(data)

    @test haskey(data, :variables)
    @test data[:variables] isa Dict{Symbol,MacroEnergy.UserVariable}
    @test length(data[:variables]) == 2
    @test haskey(data[:variables], :dispatch)
    @test haskey(data[:variables], :reserve)
    @test data[:variables][:dispatch].name == :dispatch
    @test data[:variables][:dispatch].operation_variable == true
    @test data[:variables][:reserve].name == :reserve
    @test data[:variables][:reserve].operation_variable == true
    @test data[:variables][:dispatch].variable_ref === nothing
    @test data[:variables][:reserve].variable_ref === nothing
end

function test_check_and_convert_variables_bang_is_no_op_for_parsed_variables()
    parsed_variables = Dict{Symbol,MacroEnergy.UserVariable}(
        :dispatch => MacroEnergy.UserVariable(:dispatch, true, false, 2, :Continuous, nothing, nothing, nothing),
    )
    data = Dict{Symbol,Any}(
        :id => :test_node,
        :variables => parsed_variables,
    )

    check_and_convert_variables!(data)

    @test data[:variables] === parsed_variables
    @test data[:variables][:dispatch].name == :dispatch
    @test data[:variables][:dispatch].time_varying == true
    @test data[:variables][:dispatch].operation_variable == false
    @test data[:variables][:dispatch].number_segments == 2
    @test data[:variables][:dispatch].variable_type == :Continuous
end

function test_parsed_variables_flow_into_node_construction()
    input_data = Dict{Symbol,Any}(
        :id => :parsed_node,
        :variables => [
            Dict{Symbol,Any}(:name => "dispatch", :time_varying => true, :number_segments => 2),
            Dict{Symbol,Any}(:name => "build", :time_varying => false, :operation_variable => false),
        ],
    )

    data = MacroEnergy.process_data(input_data)
    node = MacroEnergy.Node(data, make_test_timedata(), MacroEnergy.Electricity)

    @test length(node.variables) == 2
    @test haskey(node.variables, :dispatch)
    @test haskey(node.variables, :build)
    @test node.variables[:dispatch].name == :dispatch
    @test node.variables[:dispatch].time_varying == true
    @test node.variables[:dispatch].number_segments == 2
    @test node.variables[:dispatch].variable_ref === nothing
    @test node.variables[:build].operation_variable == false
    @test node.variables[:build].variable_ref === nothing
end

function test_planning_model_creates_only_planning_variables()
    variables = Dict{Symbol,MacroEnergy.UserVariable}(
        :build_decision => MacroEnergy.UserVariable(:build_decision, false, false, 2, :Continuous, nothing, nothing, nothing),
        :dispatch => MacroEnergy.UserVariable(:dispatch, true, true, 3, :Continuous, nothing, nothing, nothing),
    )
    node = make_test_node(variables)
    model = Model(HiGHS.Optimizer)

    MacroEnergy.planning_model!(node, model)

    @test JuMP.num_variables(model) == 2
    @test node.variables[:build_decision].variable_ref !== nothing
    @test length(node.variables[:build_decision].variable_ref) == 2
    @test JuMP.name(node.variables[:build_decision].variable_ref[1]) == "vbuild_decision_test_node_period1[1]"
    @test JuMP.name(node.variables[:build_decision].variable_ref[2]) == "vbuild_decision_test_node_period1[2]"
    @test node.variables[:dispatch].variable_ref === nothing
end

function test_operation_model_creates_only_operation_variables()
    variables = Dict{Symbol,MacroEnergy.UserVariable}(
        :build_decision => MacroEnergy.UserVariable(:build_decision, false, false, 2, :Continuous, nothing, nothing, nothing),
        :dispatch => MacroEnergy.UserVariable(:dispatch, true, true, 3, :Continuous, nothing, nothing, nothing),
    )
    node = make_test_node(variables)
    model = Model(HiGHS.Optimizer)

    MacroEnergy.operation_model!(node, model)

    @test JuMP.num_variables(model) == 9
    @test node.variables[:build_decision].variable_ref === nothing
    @test node.variables[:dispatch].variable_ref !== nothing
    @test size(node.variables[:dispatch].variable_ref) == (3, 3)
    @test JuMP.name(node.variables[:dispatch].variable_ref[1, 1]) == "vdispatch_test_node_period1[1,1]"
    @test JuMP.name(node.variables[:dispatch].variable_ref[3, 3]) == "vdispatch_test_node_period1[3,3]"
end

function test_planning_and_operation_model_preserve_both_variable_refs()
    variables = Dict{Symbol,MacroEnergy.UserVariable}(
        :build_decision => MacroEnergy.UserVariable(:build_decision, false, false, 2, :Continuous, nothing, nothing, nothing),
        :dispatch => MacroEnergy.UserVariable(:dispatch, true, true, 3, :Continuous, nothing, nothing, nothing),
    )
    node = make_test_node(variables)
    model = Model(HiGHS.Optimizer)

    MacroEnergy.planning_model!(node, model)
    planning_ref = node.variables[:build_decision].variable_ref

    MacroEnergy.operation_model!(node, model)

    @test JuMP.num_variables(model) == 11
    @test node.variables[:build_decision].variable_ref === planning_ref
    @test node.variables[:dispatch].variable_ref !== nothing
    @test length(node.variables[:build_decision].variable_ref) == 2
    @test size(node.variables[:dispatch].variable_ref) == (3, 3)
end

function test_planning_model_creates_variables_on_noncapacity_edges()
    variables = Dict{Symbol,MacroEnergy.UserVariable}(
        :build_decision => MacroEnergy.UserVariable(:build_decision, false, false, 2, :Continuous, nothing, nothing, nothing),
    )
    edge = make_test_edge(variables; has_capacity=false)
    model = Model(HiGHS.Optimizer)

    MacroEnergy.planning_model!(edge, model)

    @test JuMP.num_variables(model) == 2
    @test edge.variables[:build_decision].variable_ref !== nothing
    @test length(edge.variables[:build_decision].variable_ref) == 2
    @test JuMP.name(edge.variables[:build_decision].variable_ref[1]) == "vbuild_decision_test_edge_period1[1]"
    @test JuMP.name(edge.variables[:build_decision].variable_ref[2]) == "vbuild_decision_test_edge_period1[2]"
end

function test_user_variable_accessors_return_spec_and_ref()
    variables = Dict{Symbol,MacroEnergy.UserVariable}(
        :build_decision => MacroEnergy.UserVariable(:build_decision, false, false, 1, :Continuous, nothing, nothing, nothing),
    )
    node = make_test_node(variables)
    model = Model(HiGHS.Optimizer)

    MacroEnergy.planning_model!(node, model)

    @test MacroEnergy.user_variable_spec(node, :build_decision) === node.variables[:build_decision]
    @test MacroEnergy.user_variable(node, :build_decision) === node.variables[:build_decision].variable_ref
end

function test_user_variables_apply_bounds_and_types()
    variables = Dict{Symbol,MacroEnergy.UserVariable}(
        :continuous => MacroEnergy.UserVariable(:continuous, false, false, 1, :Continuous, 1.0, 5.0, nothing),
        :binary => MacroEnergy.UserVariable(:binary, false, false, 1, :Bin, nothing, nothing, nothing),
        :integer => MacroEnergy.UserVariable(:integer, false, false, 1, :Int, 2.0, 4.0, nothing),
        :semiinteger => MacroEnergy.UserVariable(:semiinteger, false, false, 1, :Semiinteger, 3.0, 5.0, nothing),
        :semicontinuous => MacroEnergy.UserVariable(:semicontinuous, false, false, 1, :Semicontinuous, 1.5, 2.5, nothing),
    )
    node = make_test_node(variables)
    model = Model(HiGHS.Optimizer)

    MacroEnergy.planning_model!(node, model)

    @test JuMP.lower_bound(node.variables[:continuous].variable_ref[1]) == 1.0
    @test JuMP.upper_bound(node.variables[:continuous].variable_ref[1]) == 5.0
    @test JuMP.is_binary(node.variables[:binary].variable_ref[1])
    @test JuMP.is_integer(node.variables[:integer].variable_ref[1])
    @test JuMP.lower_bound(node.variables[:integer].variable_ref[1]) == 2.0
    @test JuMP.upper_bound(node.variables[:integer].variable_ref[1]) == 4.0
    @test JuMP.num_constraints(model, VariableRef, JuMP.MOI.Semiinteger{Float64}) == 1
    @test JuMP.num_constraints(model, VariableRef, JuMP.MOI.Semicontinuous{Float64}) == 1
end

function test_created_user_variables_can_be_used_in_later_expressions()
    input_data = Dict{Symbol,Any}(
        :id => :expr_node,
        :variables => [
            Dict{Symbol,Any}(:name => "dispatch", :time_varying => true, :number_segments => 2),
            Dict{Symbol,Any}(:name => "build", :time_varying => false, :operation_variable => false, :number_segments => 3),
        ],
    )

    data = MacroEnergy.process_data(input_data)
    node = MacroEnergy.Node(data, make_test_timedata(), MacroEnergy.Electricity)
    model = Model(HiGHS.Optimizer)

    MacroEnergy.planning_model!(node, model)
    planning_expr = @expression(
        model,
        sum(node.variables[:build].variable_ref[s] for s in 1:node.variables[:build].number_segments)
    )

    MacroEnergy.operation_model!(node, model)
    operation_expr = @expression(
        model,
        sum(
            node.variables[:dispatch].variable_ref[t, s]
            for t in MacroEnergy.time_interval(node), s in 1:node.variables[:dispatch].number_segments
        )
    )

    @test planning_expr isa AffExpr
    @test operation_expr isa AffExpr
    @test node.variables[:build].variable_ref !== nothing
    @test node.variables[:dispatch].variable_ref !== nothing
end

function test_variable_names_must_be_nonempty_and_unique()
    for name in (nothing, "", "   ", Symbol(""))
        entry = Dict{Symbol,Any}(:time_varying => true)
        name === nothing || (entry[:name] = name)
        @test_throws ErrorException MacroEnergy.check_and_convert_uservar([entry], :test_node)
    end
    @test_throws ErrorException MacroEnergy.check_and_convert_uservar([
        Dict(:name => "dispatch", :time_varying => true),
        Dict(:name => :dispatch, :time_varying => false),
    ], :test_node)
    # An unnamed entry must never steal an explicitly declared name.
    @test_throws ErrorException MacroEnergy.check_and_convert_uservar([
        Dict(:time_varying => true),
        Dict(:name => "variable1", :time_varying => false),
    ], :test_node)
    variables = MacroEnergy.check_and_convert_uservar([
        Dict(:name => "variable1", :time_varying => true),
        Dict(:name => "dispatch", :time_varying => false),
    ], :test_node)
    invalid = Dict(:alias => variables[:dispatch])
    @test_throws ErrorException check_and_convert_variables!(Dict{Symbol,Any}(:variables => invalid))
    @test_throws ErrorException MacroEnergy.planning_model!(make_test_node(invalid), Model())
    node = make_test_node(variables)
    @test MacroEnergy.user_variable_spec(node, "variable1") === variables[:variable1]
    @test MacroEnergy.user_variable_spec(node, :dispatch) === variables[:dispatch]
    @test_throws ErrorException MacroEnergy.user_variable_spec(node, :missing)
end

struct VariableCleanupAsset <: MacroEnergy.AbstractAsset
    id::Symbol
    components::Tuple
end

function test_user_variable_cleanup_and_rebuild()
    specs = MacroEnergy.check_and_convert_uservar([
        Dict(:name => "build", :time_varying => false, :operation_variable => false,
             :number_segments => 2, :type => "Int", :lower_bound => 0.0, :upper_bound => 3.0),
        Dict(:name => "dispatch", :time_varying => true, :lower_bound => 0.0),
    ], :test_node)
    timedata = make_test_timedata()
    node = make_test_node(copy(specs))
    components = Any[node]
    for T in (MacroEnergy.Transformation, MacroEnergy.Storage{MacroEnergy.Electricity},
              MacroEnergy.LongDurationStorage{MacroEnergy.Electricity})
        push!(components, T(; id=Symbol(nameof(T)), timedata, variables=copy(specs)))
    end
    for T in (MacroEnergy.UnidirectionalEdge{MacroEnergy.Electricity},
              MacroEnergy.BidirectionalEdge{MacroEnergy.Electricity},
              MacroEnergy.EdgeWithUC{MacroEnergy.Electricity})
        push!(components, T(; id=Symbol(nameof(T)), timedata, variables=copy(specs),
                           start_vertex=node, end_vertex=node))
    end
    system = MacroEnergy.empty_system(@__DIR__)
    push!(system.locations, node)
    push!(system.assets, VariableCleanupAsset(:cleanup, Tuple(components[2:end])))
    model = Model(HiGHS.Optimizer)
    set_silent(model)
    for component in components
        @test_throws r"has not been built" MacroEnergy.user_variable(component, :build)
        MacroEnergy.add_uservariables!(component, model, false)
        @test_throws r"has not been built" MacroEnergy.user_variable(component, :dispatch)
        MacroEnergy.add_uservariables!(component, model, true)
        build = MacroEnergy.user_variable(component, :build)
        dispatch = MacroEnergy.user_variable(component, :dispatch)
        @constraint(model, dispatch[1, 1] >= sum(build))
    end
    @objective(model, Min, sum(all_variables(model)))
    optimize!(model)
    @test termination_status(model) == MOI.OPTIMAL
    old_ref = MacroEnergy.user_variable(node, :build)[1]
    MacroEnergy.release_model!(system, model)
    @test num_variables(model) == 0
    @test !is_valid(model, old_ref)
    for component in components
        for (name, spec) in specs
            @test component.variables[name] === spec
            @test_throws r"has been released" MacroEnergy.user_variable(component, name)
        end
    end
    # Releasing twice also works for components without live capacity variables.
    MacroEnergy.release_model_references!(system)
    rebuilt = Model()
    for component in components
        MacroEnergy.add_uservariables!(component, rebuilt, false)
        MacroEnergy.add_uservariables!(component, rebuilt, true)
        build = MacroEnergy.user_variable(component, :build)
        @test owner_model(build[1]) === rebuilt
        @test is_integer(build[1])
        @test lower_bound(build[1]) == 0.0
        @test upper_bound(build[1]) == 3.0
        @test length(build) == 2
        @test size(MacroEnergy.user_variable(component, :dispatch)) == (3, 1)
    end
    @test all(spec.variable_ref === nothing for spec in values(specs))
end

function test_repeated_creation_warns_only_for_live_variables_in_same_model()
    variables = MacroEnergy.check_and_convert_uservar([
        Dict(:name => "build", :time_varying => false, :operation_variable => false),
        Dict(:name => "dispatch", :time_varying => true),
    ], :test_node)
    node = make_test_node(variables)
    model = Model()
    @test_logs MacroEnergy.add_uservariables!(node, model, false)
    @test_logs MacroEnergy.add_uservariables!(node, model, true)
    original = MacroEnergy.user_variable(node, :build)[1]
    constraint = @constraint(model, original >= 1)
    @test_logs (:warn, r"User variable build on component test_node already exists") MacroEnergy.add_uservariables!(node, model, false)
    @test num_variables(model) == 5
    @test is_valid(model, original)
    @test normalized_coefficient(constraint, original) == 1.0
    @test MacroEnergy.user_variable(node, :build)[1] != original
    @test_logs (:warn, r"User variable dispatch on component test_node already exists") MacroEnergy.add_uservariables!(node, model, true)

    fresh_model = Model()
    @test_logs MacroEnergy.add_uservariables!(node, fresh_model, false)
    @test_logs MacroEnergy.add_uservariables!(node, fresh_model, true)
    # Check all entries, including when the first has been deleted.
    dispatch = MacroEnergy.user_variable(node, :dispatch)
    delete(fresh_model, dispatch[1, 1])
    @test_logs (:warn, r"User variable dispatch.*already exists") MacroEnergy.add_uservariables!(node, fresh_model, true)
    empty!(fresh_model)
    @test_logs MacroEnergy.add_uservariables!(node, fresh_model, false)
    MacroEnergy.release_user_variable_references!(node)
    @test_logs MacroEnergy.add_uservariables!(node, Model(), false)
end

@testset "User Variable Inputs" begin
    test_repeated_creation_warns_only_for_live_variables_in_same_model()
    test_user_variable_cleanup_and_rebuild()
    test_variable_names_must_be_nonempty_and_unique()
    test_empty_variables_input_returns_empty_dict()
    test_named_variable_string_is_converted_to_symbol()
    test_named_variable_symbol_is_preserved()
    test_variable_type_and_bounds_are_parsed()
    test_operation_variable_defaults_to_true()
    test_non_dict_variable_entry_errors()
    test_invalid_name_type_errors()
    test_missing_time_varying_errors()
    test_non_bool_time_varying_errors()
    test_non_bool_operation_variable_errors()
    test_non_int_number_segments_errors()
    test_non_positive_number_segments_errors()
    test_invalid_variable_type_errors()
    test_non_numeric_bounds_error()
    test_invalid_bound_order_errors()
    test_semi_types_require_bounds()
    test_check_and_convert_variables_bang_updates_data_in_place()
    test_check_and_convert_variables_bang_is_no_op_for_parsed_variables()
    test_parsed_variables_flow_into_node_construction()
    test_planning_model_creates_only_planning_variables()
    test_operation_model_creates_only_operation_variables()
    test_planning_and_operation_model_preserve_both_variable_refs()
    test_planning_model_creates_variables_on_noncapacity_edges()
    test_user_variable_accessors_return_spec_and_ref()
    test_user_variables_apply_bounds_and_types()
    test_created_user_variables_can_be_used_in_later_expressions()
end

end # module TestUserVariablesInputs
