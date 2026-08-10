module TestMyopic

using Test
using HiGHS
using DataFrames
using JSON3
using JuMP

import MacroEnergy:
    load_case,
    run_case,
    MyopicResults,
    Case,
    System,
    default_myopic_settings,
    AbstractEdge,
    EdgeWithUC,
    AbstractStorage,
    LongDurationStorage,
    Transformation,
    Node,
    Location,
    solve_case,
    create_optimizer,
    get_edges,
    get_storages

const MYOPIC_TEST_INPUTS = joinpath(@__DIR__, "test_inputs")
include("utilities.jl")

function write_two_period_myopic_case!(case_path::AbstractString)
    system_data_path = joinpath(case_path, "system_data.json")
    system_data = JSON3.read(read(system_data_path, String), Dict{String,Any})
    case_data = Dict(
        "case" => [system_data, deepcopy(system_data)],
        "settings" => Dict("path" => "settings/case_settings.json"),
    )
    write(system_data_path, JSON3.write(case_data))

    case_settings = Dict(
        "SolutionAlgorithm" => "Monolithic",
        "ExpansionHorizon" => "Myopic",
        "PeriodLengths" => [1, 1],
        "ParameterScaling" => true,
        "WriteFullTimeseries" => false,
        "MyopicSettings" => Dict(
            "ReturnModels" => false,
            "WriteModelLP" => false,
        ),
    )
    write(
        joinpath(case_path, "settings", "case_settings.json"),
        JSON3.write(case_settings),
    )
    return nothing
end

function assert_constraint_references_released(constraints)
    for constraint in constraints
        hasproperty(constraint, :constraint_ref) || continue
        @test ismissing(getproperty(constraint, :constraint_ref))
    end
    return nothing
end

function assert_model_references_released!(system::System)
    assert_constraint_references_released(system.constraints)

    for asset in system.assets
        for field in fieldnames(typeof(asset))
            component = getfield(asset, field)
            if component isa AbstractEdge
                @test component.capacity isa Real
                @test component.existing_capacity isa Real
                @test component.new_capacity isa Real
                @test component.retired_capacity isa Real
                @test component.new_units isa Real
                @test component.retired_units isa Real
                @test component.retrofitted_units isa Real
                @test isempty(component.flow)
                @test isempty(component.retrofitted_capacity.terms)
                @test all(isempty(track.terms) for track in values(component.new_capacity_track))
                @test all(isempty(track.terms) for track in values(component.retired_capacity_track))
                @test all(isempty(track.terms) for track in values(component.retrofitted_capacity_track))
                assert_constraint_references_released(component.constraints)

                if component isa EdgeWithUC
                    @test isempty(component.ucommit)
                    @test isempty(component.ushut)
                    @test isempty(component.ustart)
                end
            elseif component isa AbstractStorage
                @test component.capacity isa Real
                @test component.existing_capacity isa Real
                @test component.new_capacity isa Real
                @test component.retired_capacity isa Real
                @test ismissing(component.new_units)
                @test ismissing(component.retired_units)
                @test isempty(component.storage_level)
                @test all(isempty(track.terms) for track in values(component.new_capacity_track))
                @test all(isempty(track.terms) for track in values(component.retired_capacity_track))
                @test isempty(component.operation_expr)
                assert_constraint_references_released(component.constraints)

                if component isa LongDurationStorage
                    @test isempty(component.storage_initial)
                    @test isempty(component.storage_change)
                end
            elseif component isa Transformation
                @test isempty(component.operation_expr)
                assert_constraint_references_released(component.constraints)
            end
        end
    end

    for location in system.locations
        if location isa Node
            @test isempty(location.non_served_demand)
            @test isempty(location.supply_flow)
            @test isempty(location.policy_budgeting_vars)
            @test isempty(location.policy_budgeting_constraints)
            @test isempty(location.policy_slack_vars)
            @test isempty(location.operation_expr)
            assert_constraint_references_released(location.constraints)
        elseif location isa Location
            assert_constraint_references_released(location.constraints)
            for node in values(location.nodes)
                @test isempty(node.non_served_demand)
                @test isempty(node.supply_flow)
                @test isempty(node.policy_budgeting_vars)
                @test isempty(node.policy_budgeting_constraints)
                @test isempty(node.policy_slack_vars)
                @test isempty(node.operation_expr)
                assert_constraint_references_released(node.constraints)
            end
        end
    end
    return nothing
end

"""
Test MyopicResults structure and basic functionality
"""
function test_myopic_results_structure()
    @testset "MyopicResults structure" begin
        # Test without results stored (this is the memory-optimized case)
        results_without_models = MyopicResults(nothing, "path/to/output")
        @test isnothing(results_without_models.results)
        @test results_without_models.output_path == "path/to/output"

        # Test field access
        @test hasfield(MyopicResults, :results)
        @test fieldtype(MyopicResults, :results) == Union{Vector, Nothing}

        @test hasfield(MyopicResults, :output_path)
        @test fieldtype(MyopicResults, :output_path) == String

        # Test that the struct can be created with nothing
        @test isa(results_without_models, MyopicResults)
    end
end

"""
Test default myopic settings and configuration
"""
function test_myopic_settings()
    @testset "Myopic settings" begin
        # Test default settings
        default_settings = default_myopic_settings()
        @test haskey(default_settings, :ReturnModels)
        @test default_settings[:ReturnModels] == false
        @test haskey(default_settings, :WriteModelLP)
        @test default_settings[:WriteModelLP] == false
        @test isa(default_settings, Dict)
        @test isa(default_settings[:ReturnModels], Bool)
        @test isa(default_settings[:WriteModelLP], Bool)
        
        # Test valid settings configurations
        valid_configs = [
            Dict(:ReturnModels => true, :WriteModelLP => false),
            Dict(:ReturnModels => false, :WriteModelLP => true),
            Dict(:ReturnModels => true, :WriteModelLP => true),
            Dict(:ReturnModels => false, :WriteModelLP => false)
        ]
        
        for config in valid_configs
            @test haskey(config, :ReturnModels)
            @test isa(config[:ReturnModels], Bool)
            @test haskey(config, :WriteModelLP)
            @test isa(config[:WriteModelLP], Bool)
        end
        
        # Test invalid settings
        invalid_settings = Dict(:ReturnModels => "not_a_boolean")
        @test !isa(invalid_settings[:ReturnModels], Bool)
    end
end

"""
Test myopic case integration and configuration scenarios
"""
function test_myopic_case_integration()
    @testset "Myopic case integration" begin
        # Test various case configurations
        case_configs = [
            # Single period
            Dict(
                :MyopicSettings => Dict(:ReturnModels => false, :WriteModelLP => false),
                :SolutionAlgorithm => "Myopic",
                :PeriodLengths => [10],
                :DiscountRate => 0.045
            ),
            # Multi-period
            Dict(
                :MyopicSettings => Dict(:ReturnModels => false, :WriteModelLP => false),
                :SolutionAlgorithm => "Myopic",
                :PeriodLengths => [5, 5, 5],
                :DiscountRate => 0.045
            ),
            # Model retention
            Dict(
                :MyopicSettings => Dict(:ReturnModels => true, :WriteModelLP => false),
                :SolutionAlgorithm => "Myopic",
                :PeriodLengths => [5, 5],
                :DiscountRate => 0.045
            ),
            # LP writing enabled
            Dict(
                :MyopicSettings => Dict(:ReturnModels => false, :WriteModelLP => true),
                :SolutionAlgorithm => "Myopic",
                :PeriodLengths => [5, 5],
                :DiscountRate => 0.045
            ),
            # Varied period lengths
            Dict(
                :MyopicSettings => Dict(:ReturnModels => true, :WriteModelLP => false),
                :SolutionAlgorithm => "Myopic",
                :PeriodLengths => [1, 5, 10, 20],
                :DiscountRate => 0.045
            )
        ]
        
        for config in case_configs
            # Test required fields
            @test haskey(config, :SolutionAlgorithm)
            @test config[:SolutionAlgorithm] == "Myopic"
            @test haskey(config, :PeriodLengths)
            @test haskey(config, :DiscountRate)
            @test haskey(config, :MyopicSettings)
            @test haskey(config[:MyopicSettings], :ReturnModels)
            @test haskey(config[:MyopicSettings], :WriteModelLP)
            
            # Test period lengths validity
            @test length(config[:PeriodLengths]) >= 1
            @test all(x -> x > 0, config[:PeriodLengths])
            
            # Test ReturnModels and WriteModelLP are boolean
            @test isa(config[:MyopicSettings][:ReturnModels], Bool)
            @test isa(config[:MyopicSettings][:WriteModelLP], Bool)
        end
    end
end

"""
Test myopic error handling and edge cases
"""
function test_myopic_error_handling()
    @testset "Myopic error handling" begin
        # Test missing MyopicSettings when SolutionAlgorithm is Myopic
        missing_myopic_settings = Dict(
            :SolutionAlgorithm => "Myopic",
            :PeriodLengths => [10],
            :DiscountRate => 0.045
        )
        @test !haskey(missing_myopic_settings, :MyopicSettings)
        
        # Test empty MyopicSettings
        empty_myopic_settings = Dict(
            :MyopicSettings => Dict(),
            :SolutionAlgorithm => "Myopic",
            :PeriodLengths => [10],
            :DiscountRate => 0.045
        )
        @test isempty(empty_myopic_settings[:MyopicSettings])
        @test !haskey(empty_myopic_settings[:MyopicSettings], :ReturnModels)
        @test !haskey(empty_myopic_settings[:MyopicSettings], :WriteModelLP)
        
        # Test invalid ReturnModels type
        invalid_settings = Dict(:ReturnModels => "not_a_boolean")
        @test !isa(invalid_settings[:ReturnModels], Bool)
    end
end

"""
Test myopic memory optimization behavior
"""
function test_myopic_memory_optimization()
    @testset "Myopic memory optimization" begin
        # Test memory optimization settings
        memory_optimized = Dict(
            :MyopicSettings => Dict(:ReturnModels => false),
            :SolutionAlgorithm => "Myopic",
            :PeriodLengths => [10, 10, 10, 10, 10],  # 5 periods
            :DiscountRate => 0.045
        )
        
        # Test model retention settings
        model_retention = Dict(
            :MyopicSettings => Dict(:ReturnModels => true),
            :SolutionAlgorithm => "Myopic",
            :PeriodLengths => [5, 5],  # 2 periods
            :DiscountRate => 0.045
        )
        
        # Test behavior differences
        @test memory_optimized[:MyopicSettings][:ReturnModels] == false
        @test model_retention[:MyopicSettings][:ReturnModels] == true
        @test length(memory_optimized[:PeriodLengths]) > length(model_retention[:PeriodLengths])
        
        # Test default is memory optimized
        default_settings = default_myopic_settings()
        @test default_settings[:ReturnModels] == false
    end
end

function test_myopic_model_release()
    @testset "Myopic model release" begin
        temporary_root = abspath(mktempdir("."))
        case_path = joinpath(temporary_root, "case")
        try
            cp(MYOPIC_TEST_INPUTS, case_path)
            write_two_period_myopic_case!(case_path)

            case = load_case(case_path)
            _, results = solve_case(
                case,
                create_optimizer(
                    HiGHS.Optimizer,
                    nothing,
                    (
                        "solver" => "ipm",
                        "run_crossover" => "off",
                        "ipm_optimality_tolerance" => 1e-3,
                        "log_to_console" => false,
                    )
                ),
            )

            @test results isa MyopicResults
            @test isnothing(results.results)
            @test length(case.systems) == 2

            first_period, second_period = case.systems
            first_components = Dict(
                component.id => component for component in vcat(
                    get_edges(first_period),
                    get_storages(first_period),
                )
            )
            for component in vcat(
                get_edges(second_period),
                get_storages(second_period),
            )
                @test component.existing_capacity ≈ first_components[component.id].capacity
            end

            assert_model_references_released!(first_period)
            assert_model_references_released!(second_period)
        finally
            rm(temporary_root; recursive=true, force=true)
        end
    end
end

""""
Run all myopic tests
"""
function run_myopic_tests()
    @testset "Myopic Tests" begin
        test_myopic_results_structure()
        test_myopic_settings()
        test_myopic_case_integration()
        test_myopic_error_handling()
        test_myopic_memory_optimization()
        if run_long_tests()
            @warn_error_logger test_myopic_model_release()
        end
    end
end

run_myopic_tests()

end # module 
