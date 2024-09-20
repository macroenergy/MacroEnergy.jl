import Test
using Logging
using Macro


test_logger = ConsoleLogger(stderr, Logging.Warn)

with_logger(test_logger) do
    out = Test.@testset verbose = true "Load Inputs" begin
        include("test_workflow.jl")
    end
    return nothing
end
