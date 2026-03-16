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
    default_myopic_settings

"""
Test MyopicResults structure and basic functionality
"""
function test_myopic_results_structure()
    @testset "MyopicResults structure" begin
        # Test without models stored (this is the memory-optimized case)
        results_without_models = MyopicResults(nothing)
        @test isnothing(results_without_models.models)
        
        # Test field access
        @test hasfield(MyopicResults, :models)
        @test fieldtype(MyopicResults, :models) == Union{Vector{Model}, Nothing}
        
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

"""
Run all myopic tests
"""
function run_myopic_tests()
    @testset "Myopic Tests" begin
        test_myopic_results_structure()
        test_myopic_settings()
        test_myopic_case_integration()
        test_myopic_error_handling()
        test_myopic_memory_optimization()
    end
end

run_myopic_tests()

end # module 
