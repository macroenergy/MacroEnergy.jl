module TestCaseSettings

using Test
import MacroEnergy:
    default_case_settings,
    configure_case,
    load_time_data,
    load_case_data,
    generate_case,
    year,
    period_index,
    Electricity

const test_path = joinpath(@__DIR__, "test_inputs")
const test_path_data = joinpath(test_path, "system_data.json")

function test_default_case_settings_start_year()
    @testset "default_case_settings has StartYear = missing" begin
        settings = default_case_settings()
        @test haskey(settings, :StartYear)
        @test ismissing(settings[:StartYear])
    end
end

function test_configure_case_start_year()
    @testset "configure_case StartYear handling" begin
        # Not provided: stays missing, still passes validation
        settings = configure_case(Dict{Symbol,Any}(:SolutionAlgorithm => "Monolithic"))
        @test ismissing(settings[:StartYear])

        # Provided as an Integer
        settings2 = configure_case(Dict{Symbol,Any}(:SolutionAlgorithm => "Monolithic", :StartYear => 2030))
        @test settings2[:StartYear] == 2030

        # Provided as a non-Integer: fails validation
        @test_throws AssertionError configure_case(Dict{Symbol,Any}(:SolutionAlgorithm => "Monolithic", :StartYear => "2030"))
    end
end

function test_load_time_data_year_via_path()
    @testset "load_time_data threads :Year through the :path redirect" begin
        commodities = Dict(:Electricity => Electricity)

        mktempdir(".") do tmp_dir
            write(joinpath(tmp_dir, "time_data.json"), """
            {
                "HoursPerTimeStep": {"Electricity": 1},
                "HoursPerSubperiod": {"Electricity": 24},
                "NumberOfSubperiods": 3
            }
            """)

            # Path-based time_data with no :Year provided: falls back to `missing`
            path_data_no_year = Dict{Symbol,Any}(:path => "time_data.json")
            time_data_missing = load_time_data(path_data_no_year, commodities, tmp_dir)
            @test all(td -> ismissing(td.year), values(time_data_missing))
        end
    end
end

function test_generate_case_start_year()
    @testset "generate_case computes distinct years per period from StartYear" begin
        case_data = load_case_data(test_path_data)
        single_system = case_data[:case][1]

        multi_case_data = Dict{Symbol,Any}(
            :case => [deepcopy(single_system), deepcopy(single_system)],
            :settings => Dict{Symbol,Any}(
                :SolutionAlgorithm => "Monolithic",
                :PeriodLengths => [5, 10],
                :StartYear => 2030
            )
        )
        case = generate_case(test_path_data, multi_case_data)
        @test year.(case.systems) == [2030, 2035]
        @test period_index.(case.systems) == [1, 2]
    end

    @testset "generate_case leaves year missing when StartYear is not configured" begin
        case_data = load_case_data(test_path_data)
        case = generate_case(test_path_data, case_data)
        @test all(ismissing, year.(case.systems))
    end
end

test_default_case_settings_start_year()
test_configure_case_start_year()
test_load_time_data_year_via_path()
test_generate_case_start_year()

end # module TestCaseSettings
