module TestTimeData

using Test
import MacroEnergy: TimeData, Hydrogen, NaturalGas, Electricity
import MacroEnergy: load_time_data, load_subperiod_map!, validate_and_set_default_total_hours_modeled!
import MacroEnergy: timestepbefore, current_subperiod, Node

include("utilities.jl")

function test_time_data_commodity(input_data, expected_data, rel_path)
    haskey(input_data, :SubPeriodMap) && load_subperiod_map!(input_data, rel_path)
    validate_and_set_default_total_hours_modeled!(input_data)
    time_data = load_time_data(input_data, Dict(
        :Hydrogen => Hydrogen,
        :NaturalGas => NaturalGas,
        :Electricity => Electricity
    ))
    
    @test length(time_data) == length(expected_data)
    for (k, v) in time_data
        # Check that the keys are the same
        @test k in keys(expected_data)
        # Check that the fields are the same
        for i in fieldnames(typeof(v))
            @test isequal(getfield(v, i), getfield(expected_data[k], i))
        end
    end
end

function test_load_time_data()
    rel_path = joinpath(@__DIR__, "test_inputs")
    
    # Test different input data
    scenarios = [
        (input_data_no_period_map, time_data_true_no_period_map, "No period map"),
        (input_data_with_period_map, time_data_true_with_period_map, "With period map"),
        (input_data_with_total_hours_modeled, time_data_true_with_total_hours_modeled, "With weight total"),
        (input_data_with_year, time_data_true_with_year, "With year")
    ]
    
    for (input_data, expected_data, scenario_name) in scenarios
        @testset "$scenario_name" begin
            @error_logger test_time_data_commodity(input_data, expected_data, rel_path)
        end
    end
    
    return nothing
end

input_data_no_period_map = Dict{Symbol,Any}(
    :HoursPerSubperiod => Dict(:Hydrogen => 168, :NaturalGas => 168, :Electricity => 168),
    :HoursPerTimeStep => Dict(:Hydrogen => 1, :NaturalGas => 1, :Electricity => 1),
    :NumberOfSubperiods => 3
)

input_data_with_period_map = Dict{Symbol,Any}(
    :HoursPerSubperiod => Dict(:Hydrogen => 168, :NaturalGas => 168, :Electricity => 168),
    :HoursPerTimeStep => Dict(:Hydrogen => 1, :NaturalGas => 1, :Electricity => 1),
    :NumberOfSubperiods => 3,
    :SubPeriodMap => Dict(
        :path => "system/Period_map.csv"
    )
)

input_data_with_total_hours_modeled = Dict{Symbol,Any}(
    :HoursPerSubperiod => Dict(:Hydrogen => 168, :NaturalGas => 168, :Electricity => 168),
    :HoursPerTimeStep => Dict(:Hydrogen => 1, :NaturalGas => 1, :Electricity => 1),
    :NumberOfSubperiods => 3,
    :TotalHoursModeled => 8736,
    :SubPeriodMap => Dict(
        :path => "system/Period_map.csv"
    )
)

input_data_with_year = Dict{Symbol,Any}(
    :HoursPerSubperiod => Dict(:Hydrogen => 168, :NaturalGas => 168, :Electricity => 168),
    :HoursPerTimeStep => Dict(:Hydrogen => 1, :NaturalGas => 1, :Electricity => 1),
    :NumberOfSubperiods => 3,
    :Year => 2030
)

time_data_true_no_period_map = Dict{Symbol,TimeData}(
    :Hydrogen => TimeData{Hydrogen}(time_interval=1:1:504, hours_per_timestep=1, subperiods=[1:1:168, 169:1:336, 337:1:504], subperiod_indices=[1, 2, 3], subperiod_weights=Dict(1 => 1.0*8760/(3*168), 2 => 1.0*8760/(3*168), 3 => 1.0*8760/(3*168)), subperiod_map=Dict(1 => 1, 2 => 2, 3 => 3)),
    :NaturalGas => TimeData{NaturalGas}(time_interval=1:1:504, hours_per_timestep=1, subperiods=[1:1:168, 169:1:336, 337:1:504], subperiod_indices=[1, 2, 3], subperiod_weights=Dict(1 => 1.0*8760/(3*168), 2 => 1.0*8760/(3*168), 3 => 1.0*8760/(3*168)), subperiod_map=Dict(1 => 1, 2 => 2, 3 => 3)),
    :Electricity => TimeData{Electricity}(time_interval=1:1:504, hours_per_timestep=1, subperiods=[1:1:168, 169:1:336, 337:1:504], subperiod_indices=[1, 2, 3], subperiod_weights=Dict(1 => 1.0*8760/(3*168), 2 => 1.0*8760/(3*168), 3 => 1.0*8760/(3*168)), subperiod_map=Dict(1 => 1, 2 => 2, 3 => 3))
)

subperiod_map = Dict(5 => 6, 16 => 17, 20 => 17, 35 => 32, 30 => 32, 19 => 17, 32 => 32, 49 => 6, 6 => 6, 45 => 6, 44 => 6, 
9 => 6, 31 => 32, 29 => 32, 46 => 6, 4 => 6, 13 => 17, 21 => 17, 38 => 32, 52 => 6, 12 => 17, 24 => 32, 28 => 32, 8 => 6, 
17 => 17, 37 => 32, 1 => 6, 23 => 17, 22 => 17, 47 => 6, 41 => 32, 43 => 6, 11 => 6, 36 => 32, 14 => 17, 3 => 6, 39 => 32, 
51 => 6, 7 => 6, 25 => 32, 33 => 32, 40 => 32, 48 => 6, 34 => 32, 50 => 6, 15 => 17, 2 => 6, 10 => 17, 18 => 17, 26 => 32, 
27 => 32, 42 => 6)

time_data_true_with_period_map = Dict{Symbol,TimeData}(
    :Hydrogen => TimeData{Hydrogen}(time_interval=1:1:504, hours_per_timestep=1, subperiods=[1:1:168, 169:1:336, 337:1:504], subperiod_indices=[6, 17, 32], subperiod_weights=Dict(6 => 21.057692307692307, 17 =>  13.035714285714285, 32 => 18.049450549450547), subperiod_map=subperiod_map),
    :NaturalGas => TimeData{NaturalGas}(time_interval=1:1:504, hours_per_timestep=1, subperiods=[1:1:168, 169:1:336, 337:1:504], subperiod_indices=[6, 17, 32], subperiod_weights=Dict(6 => 21.057692307692307, 17 =>  13.035714285714285, 32 => 18.049450549450547), subperiod_map=subperiod_map),
    :Electricity => TimeData{Electricity}(time_interval=1:1:504, hours_per_timestep=1, subperiods=[1:1:168, 169:1:336, 337:1:504], subperiod_indices=[6, 17, 32], subperiod_weights=Dict(6 => 21.057692307692307, 17 =>  13.035714285714285, 32 => 18.049450549450547), subperiod_map=subperiod_map)
)

time_data_true_with_year = Dict{Symbol,TimeData}(
    :Hydrogen => TimeData{Hydrogen}(time_interval=1:1:504, hours_per_timestep=1, year=2030, subperiods=[1:1:168, 169:1:336, 337:1:504], subperiod_indices=[1, 2, 3], subperiod_weights=Dict(1 => 1.0*8760/(3*168), 2 => 1.0*8760/(3*168), 3 => 1.0*8760/(3*168)), subperiod_map=Dict(1 => 1, 2 => 2, 3 => 3)),
    :NaturalGas => TimeData{NaturalGas}(time_interval=1:1:504, hours_per_timestep=1, year=2030, subperiods=[1:1:168, 169:1:336, 337:1:504], subperiod_indices=[1, 2, 3], subperiod_weights=Dict(1 => 1.0*8760/(3*168), 2 => 1.0*8760/(3*168), 3 => 1.0*8760/(3*168)), subperiod_map=Dict(1 => 1, 2 => 2, 3 => 3)),
    :Electricity => TimeData{Electricity}(time_interval=1:1:504, hours_per_timestep=1, year=2030, subperiods=[1:1:168, 169:1:336, 337:1:504], subperiod_indices=[1, 2, 3], subperiod_weights=Dict(1 => 1.0*8760/(3*168), 2 => 1.0*8760/(3*168), 3 => 1.0*8760/(3*168)), subperiod_map=Dict(1 => 1, 2 => 2, 3 => 3))
)

time_data_true_with_total_hours_modeled  = Dict{Symbol,TimeData}(
    :Hydrogen => TimeData{Hydrogen}(time_interval=1:1:504, hours_per_timestep=1, subperiods=[1:1:168, 169:1:336, 337:1:504], subperiod_indices=[6, 17, 32], subperiod_weights=Dict(6 => 21, 17 =>  13, 32 => 18), subperiod_map=subperiod_map, total_hours_modeled=8736),
    :NaturalGas => TimeData{NaturalGas}(time_interval=1:1:504, hours_per_timestep=1, subperiods=[1:1:168, 169:1:336, 337:1:504], subperiod_indices=[6, 17, 32], subperiod_weights=Dict(6 => 21, 17 =>  13, 32 => 18), subperiod_map=subperiod_map, total_hours_modeled=8736),
    :Electricity => TimeData{Electricity}(time_interval=1:1:504, hours_per_timestep=1, subperiods=[1:1:168, 169:1:336, 337:1:504], subperiod_indices=[6, 17, 32], subperiod_weights=Dict(6 => 21, 17 =>  13, 32 => 18), subperiod_map=subperiod_map, total_hours_modeled=8736)
)
test_load_time_data()

function test_timestepbefore_correctness()
    subperiods = [1:1:168, 169:1:336, 337:1:504]

    @test timestepbefore(50, 0, subperiods) == 50
    @test timestepbefore(50, 5, subperiods) == 45
    # wraparound at the start of a subperiod
    @test timestepbefore(1, 1, subperiods) == 168
    @test timestepbefore(169, 1, subperiods) == 336
    @test timestepbefore(337, 1, subperiods) == 504
    # shift larger than the subperiod length (multiple wraps)
    @test timestepbefore(169, 168, subperiods) == 169
    @test timestepbefore(169, 169, subperiods) == 336

    # single large subperiod, matching a full-year (8760h) case
    big_subperiods = [1:1:8760]
    @test timestepbefore(1, 1, big_subperiods) == 8760
    @test timestepbefore(8760, 1, big_subperiods) == 8759
    @test timestepbefore(4380, 100, big_subperiods) == 4280

    # Stepped ranges must return a timestep within the subperiod.
    stepped_subperiods = [1:2:9]
    @test timestepbefore(5, 1, stepped_subperiods) == 3
    @test timestepbefore(1, 1, stepped_subperiods) == 9
    @test timestepbefore(1, 5, stepped_subperiods) == 1

    return nothing
end

function test_timestepbefore_allocation()
    subperiods = [1:1:8760]
    timestepbefore(100, 1, subperiods)  # warm up / compile before measuring
    bytes = @allocated timestepbefore(100, 1, subperiods)
    @info "timestepbefore allocated $(bytes) bytes for a single call over an 8760-length subperiod"
    @test bytes == 0
    return bytes
end

@testset "timestepbefore" begin
    test_timestepbefore_correctness()
    test_timestepbefore_allocation()
end

function test_current_subperiod_correctness()
    subperiods = [1:1:168, 169:1:336, 337:1:504]
    n = Node{Electricity}(;
        id = :test_node,
        timedata = TimeData{Electricity}(;
            time_interval = 1:504,
            subperiods = subperiods,
            subperiod_indices = [10, 20, 30],
            subperiod_weights = Dict(10 => 1.0, 20 => 1.0, 30 => 1.0),
            subperiod_map = Dict(1 => 1),
        ),
    )

    @test current_subperiod(n, 1) == 10
    @test current_subperiod(n, 168) == 10
    @test current_subperiod(n, 169) == 20
    @test current_subperiod(n, 336) == 20
    @test current_subperiod(n, 337) == 30
    @test current_subperiod(n, 504) == 30

    return n
end

function test_current_subperiod_allocation()
    n = test_current_subperiod_correctness()
    current_subperiod(n, 100)  # warm-up / compile
    bytes = @allocated current_subperiod(n, 100)
    @info "current_subperiod(y,t) allocated $(bytes) bytes"
    @test bytes == 0
    return nothing
end

@testset "current_subperiod" begin
    test_current_subperiod_correctness()
    test_current_subperiod_allocation()
end

end # module TestTimeData
