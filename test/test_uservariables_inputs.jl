module TestUserVariablesInputs

using Test
using MacroEnergy

import MacroEnergy: check_and_convert_variables!

function test_empty_variables_input_returns_empty_dict()
    variables = MacroEnergy.check_and_convert_uservar(nothing, :test_node)

    @test variables == Dict{Symbol,MacroEnergy.VariableConfig}()
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
end

function test_unnamed_variables_get_default_keys()
    variables_input = [
        Dict{Symbol,Any}(:time_varying => true),
        Dict{Symbol,Any}(:time_varying => false, :number_segments => 2),
    ]

    variables = MacroEnergy.check_and_convert_uservar(variables_input, :test_node)

    @test length(variables) == 2
    @test haskey(variables, :variable1)
    @test haskey(variables, :variable2)
    @test variables[:variable1].name == Symbol("")
    @test variables[:variable1].time_varying == true
    @test variables[:variable1].operation_variable == true
    @test variables[:variable1].number_segments == 1
    @test variables[:variable2].name == Symbol("")
    @test variables[:variable2].time_varying == false
    @test variables[:variable2].operation_variable == true
    @test variables[:variable2].number_segments == 2
end

function test_duplicate_named_variables_get_default_key_for_later_entry()
    variables_input = [
        Dict{Symbol,Any}(:name => "dispatch", :time_varying => true),
        Dict{Symbol,Any}(:name => "dispatch", :time_varying => false, :number_segments => 2),
    ]

    variables = MacroEnergy.check_and_convert_uservar(variables_input, :test_node)

    @test length(variables) == 2
    @test haskey(variables, :dispatch)
    @test haskey(variables, :variable1)
    @test variables[:dispatch].name == :dispatch
    @test variables[:dispatch].time_varying == true
    @test variables[:dispatch].operation_variable == true
    @test variables[:dispatch].number_segments == 1
    @test variables[:variable1].name == :dispatch
    @test variables[:variable1].time_varying == false
    @test variables[:variable1].operation_variable == true
    @test variables[:variable1].number_segments == 2
end

function test_default_key_skips_existing_named_variable_key()
    variables_input = [
        Dict{Symbol,Any}(:name => "variable1", :time_varying => true),
        Dict{Symbol,Any}(:time_varying => false),
    ]

    variables = MacroEnergy.check_and_convert_uservar(variables_input, :test_node)

    @test length(variables) == 2
    @test haskey(variables, :variable1)
    @test haskey(variables, :variable2)
    @test variables[:variable1].name == :variable1
    @test variables[:variable1].operation_variable == true
    @test variables[:variable2].name == Symbol("")
    @test variables[:variable2].operation_variable == true
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

function test_check_and_convert_variables_bang_updates_data_in_place()
    data = Dict{Symbol,Any}(
        :id => :test_node,
        :variables => [
            Dict{Symbol,Any}(:name => "dispatch", :time_varying => true),
            Dict{Symbol,Any}(:time_varying => false, :number_segments => 2),
        ],
    )

    check_and_convert_variables!(data)

    @test haskey(data, :variables)
    @test data[:variables] isa Dict{Symbol,MacroEnergy.VariableConfig}
    @test length(data[:variables]) == 2
    @test haskey(data[:variables], :dispatch)
    @test haskey(data[:variables], :variable1)
    @test data[:variables][:dispatch].name == :dispatch
    @test data[:variables][:dispatch].operation_variable == true
    @test data[:variables][:variable1].name == Symbol("")
    @test data[:variables][:variable1].operation_variable == true
end

function test_check_and_convert_variables_bang_is_no_op_for_parsed_variables()
    parsed_variables = Dict{Symbol,MacroEnergy.VariableConfig}(
        :dispatch => MacroEnergy.VariableConfig(:dispatch, true, false, 2),
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
end

@testset "User Variable Inputs" begin
    test_empty_variables_input_returns_empty_dict()
    test_named_variable_string_is_converted_to_symbol()
    test_named_variable_symbol_is_preserved()
    test_unnamed_variables_get_default_keys()
    test_duplicate_named_variables_get_default_key_for_later_entry()
    test_default_key_skips_existing_named_variable_key()
    test_operation_variable_defaults_to_true()
    test_non_dict_variable_entry_errors()
    test_invalid_name_type_errors()
    test_missing_time_varying_errors()
    test_non_bool_time_varying_errors()
    test_non_bool_operation_variable_errors()
    test_non_int_number_segments_errors()
    test_non_positive_number_segments_errors()
    test_check_and_convert_variables_bang_updates_data_in_place()
    test_check_and_convert_variables_bang_is_no_op_for_parsed_variables()
end

end # module TestUserVariablesInputs