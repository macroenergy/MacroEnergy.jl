import CSV
import DataFrames

Test.@testset "CSV read cache" begin
    mktempdir() do dir
        path = joinpath(dir, "profiles.csv")
        CSV.write(
            path,
            DataFrames.DataFrame(
                solar = [0.1, 0.2, 0.3],
                wind = [0.4, 0.5, 0.6],
            ),
        )

        cache_key = abspath(path)
        lock(MacroEnergy._CSV_READ_CACHE_LOCK) do
            delete!(MacroEnergy._CSV_READ_CACHE, cache_key)
        end

        try
            cached_first = MacroEnergy._cached_duckdb_read(path)
            cached_second = MacroEnergy._cached_duckdb_read(path)
            Test.@test cached_first === cached_second

            selected = MacroEnergy.read_csv(path, :solar)
            Test.@test propertynames(selected) == [:solar]
            Test.@test selected.solar == [0.1, 0.2, 0.3]

            # A caller may mutate its result without changing the cached data.
            selected.solar[1] = 99.0
            Test.@test MacroEnergy.read_csv(path, :solar).solar == [0.1, 0.2, 0.3]

            full = MacroEnergy.read_csv(path)
            full.wind[1] = 99.0
            Test.@test MacroEnergy.read_csv(path, :wind).wind == [0.4, 0.5, 0.6]

            Test.@test_throws ErrorException MacroEnergy.read_csv(path, :missing)
        finally
            lock(MacroEnergy._CSV_READ_CACHE_LOCK) do
                delete!(MacroEnergy._CSV_READ_CACHE, cache_key)
            end
        end
    end
end
