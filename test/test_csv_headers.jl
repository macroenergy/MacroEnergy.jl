using CSV, DataFrames, MacroEnergy, Test

@testset "selective CSV header cache reuse" begin
    MacroEnergy.clear_csv_cache!()
    mktempdir() do root
        path = joinpath(root, "input.csv")
        write(path, "Type,id\nVRE,asset_1\n")
        try
            @test MacroEnergy.csv_headers(path) == [:Type, :id]
            @test !haskey(MacroEnergy._CSV_READ_CACHE, path)
            MacroEnergy.read_csv(path)
            cached_time, cached_table = MacroEnergy._CSV_READ_CACHE[path]
            @test MacroEnergy.csv_headers(path) == propertynames(cached_table)
            @test MacroEnergy._CSV_READ_CACHE[path][2] === cached_table
            # A deliberately distinct fresh cache entry proves the hit skips
            # the stream reader; returned names must not mutate that table.
            MacroEnergy._CSV_READ_CACHE[path] = (cached_time, DataFrame(cached_column=[1]))
            headers = MacroEnergy.csv_headers(path)
            @test headers == [:cached_column]
            headers[1] = :changed
            @test propertynames(MacroEnergy._CSV_READ_CACHE[path][2]) == [:cached_column]
            MacroEnergy._CSV_READ_CACHE[path] = (cached_time - 1, cached_table)
            @test MacroEnergy.csv_headers(path) == [:Type, :id]
            @test MacroEnergy._CSV_READ_CACHE[path][1] == cached_time - 1
        finally
            MacroEnergy.clear_csv_cache!()
        end
    end
end

@testset "bounded CSV header streams" begin
    header = "Type,id,\"comma,header\",\"multi\nline\",\"quote\"\"header\",λ\n"
    io = IOBuffer(header * repeat("body data\n", 100_000))
    @test String(MacroEnergy._csv_header_record(io)) == header
    @test position(io) == sizeof(header)
    mktempdir() do root
        for compressed in (false, true), newline in ("\n", "\r\n", "\r")
            path = joinpath(root, compressed ? "headers.csv.gz" : "headers.csv")
            table = DataFrame(["Type", "id", "comma,header", "multi\nline", "quote\"header", "λ"] .=> fill(["value"], 6))
            # Use explicitly quoted headers, including LF inside a field
            # when the record separator is CRLF or CR.
            text = chop(header) * newline * join(fill("value", 6), ',') * newline
            if compressed
                MacroEnergy.GZip.open(path, "w") do stream
                    write(stream, text)
                end
            else
                write(path, text)
            end
            @test MacroEnergy.csv_headers(path) == propertynames(table)
            @test !haskey(MacroEnergy._CSV_READ_CACHE, path)
            mv(path, path * ".moved")
            rm(path * ".moved")
        end
        for text in ("\n\r\nType,id\nVRE,a\n", "Type;id\nVRE;a\n", "Type\tid\nVRE\ta\n", "Type,id", "", "\ufeffType,id\nVRE,a\n",
            "first;second,third\n1;2,3\n", "Type,id;part;part\nVRE,a\n")
            path = joinpath(root, "other.csv")
            write(path, text)
            @test MacroEnergy.csv_headers(path) == CSV.Rows(Vector{UInt8}(codeunits(text)); buffer_in_memory=true).names
        end
    end
end
