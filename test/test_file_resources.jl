module TestFileResources

using Test, Logging, JSON3, MacroEnergy

struct FailingJSON end
JSON3.StructTypes.StructType(::Type{FailingJSON}) = JSON3.StructTypes.CustomStruct()
JSON3.StructTypes.lower(::FailingJSON) = error("intentional serialization failure")

@testset "JSON streams close after errors" begin
    mktempdir() do root
        for compressed in (false, true)
            path = joinpath(root, compressed ? "input.json.gz" : "input.json")
            opener = compressed ? MacroEnergy.GZip.open : open
            opener(path, "w") do io
                write(io, "{invalid json")
            end
            @test_throws Exception MacroEnergy.read_json(path)
            rm(path)
            @test !ispath(path)

            @test_throws ErrorException MacroEnergy.write_json(path, Dict("value" => FailingJSON()))
            rm(path)
            @test !ispath(path)

            MacroEnergy.write_json(path, Dict("value" => 3))
            @test MacroEnergy.read_json(path)["value"] == 3
        end
    end
end

@testset "case logger restores caller and closes owned stream" begin
    mktempdir() do root
        previous = current_logger()
        global_before = global_logger()
        for attributed in (false, true), fail in (false, true)
            path = joinpath(root, "run.log")
            stream = Ref{IO}()
            function run()
                MacroEnergy.with_case_logger(false, true, Logging.Info, path, attributed) do
                    stream[] = current_logger().logger.stream
                    @info "case message"
                    fail && error("intentional run failure")
                    return :completed
                end
            end
            if fail
                @test_throws ErrorException run()
            else
                @test run() == :completed
            end
            @test current_logger() === previous && global_logger() === global_before
            @test !isopen(stream[])
            @test occursin("case message", read(path, String))
            rm(path)
            @test !ispath(path)
        end
        MacroEnergy.with_case_logger(false, false, Logging.Info, "unused.log", false) do
            @test current_logger() === previous
        end
    end
end

@testset "failed case run releases its log" begin
    mktempdir() do root
        previous = current_logger()
        path = joinpath(root, "run.log")
        @test_throws Exception run_case(root; log_to_console=false,
            log_file_path=path, write_status=false)
        @test current_logger() === previous
        rm(path)
        @test !ispath(path)
    end
end

end
