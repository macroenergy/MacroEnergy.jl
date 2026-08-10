module TestFullTimeseries

using Test
using MacroEnergy
import MacroEnergy:
    TimeData,
    Electricity,
    reconstruct_timeseries

include("utilities.jl")

function test_reconstruct_timeseries()
    @testset "reconstruct_timeseries" begin

        # Simple case: 2 rep periods (A, B), each 3 hours.
        # Full year has 6 periods: [A, B, A, B, A, B] → 18 hours total; TotalHoursModeled = 18
        #   subperiod_map: {1=>1, 2=>2, 3=>1, 4=>2, 5=>1, 6=>2}
        #   subperiods: [1:3, 4:6]
        #   subperiod_indices: [1, 2]
        td = TimeData{Electricity}(;
            time_interval   = 1:6,
            subperiods      = [1:3, 4:6],
            subperiod_indices = [1, 2],
            subperiod_weights = Dict(1 => 3.0, 2 => 3.0),
            subperiod_map   = Dict(1=>1, 2=>2, 3=>1, 4=>2, 5=>1, 6=>2),
            total_hours_modeled = 18
        )

        vals = Float64[10, 20, 30, 40, 50, 60]  # rep-period values

        result = reconstruct_timeseries(vals, td)

        # Expected: A(1,2,3) B(4,5,6) A(1,2,3) B(4,5,6) A(1,2,3) B(4,5,6)
        expected = Float64[10,20,30, 40,50,60, 10,20,30, 40,50,60, 10,20,30, 40,50,60]
        @test result == expected

        @testset "correct length" begin
            @test length(result) == 18
        end
    end

    @testset "reconstruct_timeseries padding" begin
        # 2 rep periods of 3 hours, 4 full-year periods (12 hours covered),
        # but TotalHoursModeled = 15 → pad 3 hours from last sub-period.
        #   subperiod_map: {1=>1, 2=>2, 3=>1, 4=>2}
        td = TimeData{Electricity}(;
            time_interval   = 1:6,
            subperiods      = [1:3, 4:6],
            subperiod_indices = [1, 2],
            subperiod_weights = Dict(1 => 2.5, 2 => 2.5),
            subperiod_map   = Dict(1=>1, 2=>2, 3=>1, 4=>2),
            total_hours_modeled = 15
        )

        vals = Float64[1, 2, 3, 4, 5, 6]

        result = @test_logs (:info,) reconstruct_timeseries(vals, td)

        # Covered: period1(1,2,3) period2(4,5,6) period3(1,2,3) period4(4,5,6) = 12 hours
        # Pad 3 hours from last sub-period (4,5,6) → final 3: [4,5,6]
        expected = Float64[1,2,3, 4,5,6, 1,2,3, 4,5,6, 4,5,6]
        @test result == expected
        @test length(result) == 15
    end

    @testset "reconstruct_timeseries padding uses last calendar period's rep period" begin
        # 2 rep periods of 3 hours, 3 full-year periods (9 hours covered),
        # but TotalHoursModeled = 11 → pad 2 hours.
        # Last calendar period (key 3) maps to rep period 1.
        #   subperiod_map: {1=>2, 2=>1, 3=>1}
        td = TimeData{Electricity}(;
            time_interval   = 1:6,
            subperiods      = [1:3, 4:6],
            subperiod_indices = [1, 2],
            subperiod_weights = Dict(1 => 2.0, 2 => 1.0),
            subperiod_map   = Dict(1=>2, 2=>1, 3=>1),
            total_hours_modeled = 11
        )

        vals = Float64[1, 2, 3, 4, 5, 6]

        result = @test_logs (:info,) reconstruct_timeseries(vals, td)

        # Covered: period1→rep2(4,5,6) period2→rep1(1,2,3) period3→rep1(1,2,3) = 9 hours
        # Pad 2 hours from rep period 1 (subperiods[1] = 1:3) → [1, 2]
        expected = Float64[4,5,6, 1,2,3, 1,2,3, 1,2]
        @test result == expected
        @test length(result) == 11
    end
end

test_reconstruct_timeseries()

end # module TestFullTimeseries
