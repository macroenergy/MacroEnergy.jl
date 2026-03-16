module TestTimeData

using Test
import MacroEnergy: TimeData, Hydrogen, NaturalGas, Electricity
import MacroEnergy: load_time_data, load_subperiod_map!, validate_and_set_default_total_hours_modeled!

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
            @test getfield(v, i) == getfield(expected_data[k], i)
        end
    end
end

function test_load_time_data()
    rel_path = joinpath(@__DIR__, "test_inputs")
    
    # Test different input data
    scenarios = [
        (input_data_no_period_map, time_data_true_no_period_map, "No period map"),
        (input_data_with_period_map, time_data_true_with_period_map, "With period map"),
        (input_data_with_total_hours_modeled, time_data_true_with_total_hours_modeled, "With weight total")
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

time_data_true_with_total_hours_modeled  = Dict{Symbol,TimeData}(
    :Hydrogen => TimeData{Hydrogen}(time_interval=1:1:504, hours_per_timestep=1, subperiods=[1:1:168, 169:1:336, 337:1:504], subperiod_indices=[6, 17, 32], subperiod_weights=Dict(6 => 21, 17 =>  13, 32 => 18), subperiod_map=subperiod_map),
    :NaturalGas => TimeData{NaturalGas}(time_interval=1:1:504, hours_per_timestep=1, subperiods=[1:1:168, 169:1:336, 337:1:504], subperiod_indices=[6, 17, 32], subperiod_weights=Dict(6 => 21, 17 =>  13, 32 => 18), subperiod_map=subperiod_map),
    :Electricity => TimeData{Electricity}(time_interval=1:1:504, hours_per_timestep=1, subperiods=[1:1:168, 169:1:336, 337:1:504], subperiod_indices=[6, 17, 32], subperiod_weights=Dict(6 => 21, 17 =>  13, 32 => 18), subperiod_map=subperiod_map)
)
test_load_time_data()

end # module TestTimeData