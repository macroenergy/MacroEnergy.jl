import Test
using Logging
using MacroEnergy


test_logger = ConsoleLogger(stderr, Logging.Warn)

with_logger(test_logger) do
    Test.@testset verbose = true "Load Inputs" begin
        include("test_workflow.jl")
    end

    Test.@testset verbose = true "Writing Outputs" begin
        include("test_output.jl")
    end
    
    Test.@testset verbose = true "Dual Value Exports" begin
        include("test_duals.jl")
    end
    
    Test.@testset verbose = true "Benders Output Utilities" begin
        include("test_benders_output_utilities.jl")
    end
    
    Test.@testset verbose = true "Myopic Functionality" begin
        include("test_myopic.jl")
    end
    return nothing
end
