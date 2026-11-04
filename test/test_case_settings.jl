module TestCaseSettings

using Test
using Logging
using JSON3
import MacroEnergy:
    Benders,
    InputValidationError,
    Monolithic,
    configure_settings,
    default_settings,
    resolve_settings,
    single_system_case_settings,
    standalone_settings,
    template_settings_file,
    load_time_data,
    load_case_data,
    generate_case,
    year,
    period_index,
    Electricity

const test_path = joinpath(@__DIR__, "test_inputs")
const test_path_data = joinpath(test_path, "system_data.json")

function test_default_settings_start_year()
    @testset "default_settings has StartYear = missing" begin
        settings = default_settings()
        @test haskey(settings, :StartYear)
        @test ismissing(settings[:StartYear])
    end
end

function test_configure_settings_start_year()
    @testset "configure_settings StartYear handling" begin
        # Not provided: stays missing, still passes validation
        settings = configure_settings(Dict{Symbol,Any}(:SolutionAlgorithm => "Monolithic"))
        @test ismissing(settings[:StartYear])

        # Provided as an Integer
        settings2 = configure_settings(Dict{Symbol,Any}(:SolutionAlgorithm => "Monolithic", :StartYear => 2030))
        @test settings2[:StartYear] == 2030

        # Provided as a non-Integer: fails validation
        @test_throws InputValidationError configure_settings(Dict{Symbol,Any}(:SolutionAlgorithm => "Monolithic", :StartYear => "2030"))
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
        # The Case and every period share one settings object
        @test case.systems[1].settings === case.systems[2].settings
        @test case.settings === case.systems[1].settings
    end

    @testset "generate_case leaves year missing when StartYear is not configured" begin
        case_data = load_case_data(test_path_data)
        case = generate_case(test_path_data, case_data)
        @test all(ismissing, year.(case.systems))
    end
end

# Message of the error thrown by `f`, or `nothing` if it does not throw
function error_message(f)
    try
        f()
    catch e
        return sprint(showerror, e)
    end
    return nothing
end

# Run `f(dir)` in a temporary case folder holding the given settings files in `settings/`
function with_settings_files(f; files...)
    mktempdir() do dir
        mkpath(joinpath(dir, "settings"))
        for (name, settings) in files
            write(joinpath(dir, "settings", "$name.json"), JSON3.write(settings))
        end
        f(dir)
    end
end

settings_file(name) = Dict{Symbol,Any}(:path => "settings/$name.json")
period_with(name) = Dict{Symbol,Any}(:settings => settings_file(name))
# Case data with `settings/case_settings.json` and the given periods
case_with(periods...) = Dict{Symbol,Any}(:settings => settings_file("case_settings"), :case => Dict{Symbol,Any}[periods...])

function test_one_settings_file()
    @testset "One settings file for the whole case" begin
        with_settings_files(case_settings=Dict(
            "PeriodLengths" => [5, 5], "DiscountRate" => 0.05, "ConstraintScaling" => true,
            "OutputSettings" => Dict("Format" => "parquet"),
        )) do dir
            data = case_with(Dict{Symbol,Any}(), Dict{Symbol,Any}())
            settings = @test_logs min_level=Logging.Warn resolve_settings(data, dir)
            @test settings.PeriodLengths == [5, 5]
            @test settings.DiscountRate == 0.05
            # SolutionAlgorithm is not required in the file
            @test settings.SolutionAlgorithm isa Monolithic
            @test settings.ConstraintScaling
            @test settings.OutputSettings.Format == "parquet"
        end
    end

    @testset "A period pointing to case_settings.json has no separate settings" begin
        with_settings_files(case_settings=Dict("ConstraintScaling" => true)) do dir
            # As for a single-period case: the case-level path is absolute, the period's is relative
            data = Dict{Symbol,Any}(
                :settings => Dict{Symbol,Any}(:path => joinpath(dir, "settings", "case_settings.json")),
                :case => [period_with("case_settings")],
            )
            settings = @test_logs min_level=Logging.Warn resolve_settings(data, dir)
            @test settings.ConstraintScaling
        end
    end

    @testset "Unknown keys are errors" begin
        with_settings_files(case_settings=Dict("DiscountRat" => 0.05)) do dir
            msg = error_message(() -> resolve_settings(case_with(Dict{Symbol,Any}()), dir))
            @test occursin("case_settings: unknown key(s) DiscountRat", msg)
            @test occursin("DiscountRate", msg)
            @test occursin("ConstraintScaling", msg)
        end
    end

    @testset "Deprecated keys are translated" begin
        with_settings_files(case_settings=Dict("DiscountRate" => 0.05, "WriteFullTimeseries" => true, "OutputDir" => "out")) do dir
            settings = @test_logs (:warn, r"deprecated") min_level=Logging.Warn resolve_settings(case_with(Dict{Symbol,Any}()), dir)
            @test settings.DiscountRate == 0.05
            @test !haskey(settings, :WriteFullTimeseries)
            @test settings.OutputSettings.Write.FullTimeseries
            @test settings.OutputSettings.Dir == "out"
        end
    end
end

function test_comment_keys()
    @testset "Keys starting with # are comments" begin
        with_settings_files(case_settings=Dict(
            "DiscountRate" => 0.05,
            "#DiscountRate" => "a note",
            "OutputSettings" => Dict(
                "#Format" => "a note in a nested block",
                "Format" => "parquet",
                "Write" => Dict("Curtailment" => false, "#Curtailment" => "a note in a map"),
            ),
        )) do dir
            settings = @test_logs min_level=Logging.Warn resolve_settings(case_with(Dict{Symbol,Any}()), dir)
            @test settings.DiscountRate == 0.05
            @test !haskey(settings, Symbol("#DiscountRate"))
            @test settings.OutputSettings.Format == "parquet"
            @test !haskey(settings.OutputSettings, Symbol("#Format"))
            @test settings.OutputSettings.Write == (Curtailment=false,)
        end

        # A typo without the # is still an error
        with_settings_files(case_settings=Dict("#DiscountRate" => "a note", "DiscountRat" => 0.05)) do dir
            msg = error_message(() -> resolve_settings(case_with(Dict{Symbol,Any}()), dir))
            @test occursin("case_settings: unknown key(s) DiscountRat.", msg)
        end

        # In a separate Benders settings file
        with_settings_files(case_settings=Dict("SolutionAlgorithm" => "Benders"),
            benders_settings=Dict("MaxIter" => 7, "#MaxIter" => "a note")) do dir
            settings = resolve_settings(case_with(Dict{Symbol,Any}()), dir)
            @test settings.BendersSettings[:MaxIter] == 7
        end

        # Per-period files that differ only in their comments have the same settings
        with_settings_files(case_settings=Dict("PeriodLengths" => [5, 5]),
            first_period=Dict("ConstraintScaling" => true, "#note" => "first"),
            second_period=Dict("ConstraintScaling" => true, "#note" => "second")) do dir
            data = case_with(period_with("first_period"), period_with("second_period"))
            settings = @test_logs (:warn, r"given per period") min_level=Logging.Warn resolve_settings(data, dir)
            @test settings.ConstraintScaling
        end

        @test !haskey(configure_settings(Dict{Symbol,Any}(Symbol("#note") => "a note")), Symbol("#note"))
    end
end

function test_deprecated_period_settings()
    @testset "Per-period settings are still read, with a warning" begin
        with_settings_files(case_settings=Dict("PeriodLengths" => [5, 5]), macro_settings=Dict("ConstraintScaling" => true)) do dir
            data = case_with(period_with("macro_settings"), period_with("macro_settings"))
            settings = @test_logs (:warn, r"given per period") min_level=Logging.Warn resolve_settings(data, dir)
            @test settings.PeriodLengths == [5, 5]
            @test settings.ConstraintScaling
        end
    end

    @testset "Different files with the same settings are fine" begin
        same = Dict("ConstraintScaling" => true)
        with_settings_files(case_settings=Dict("PeriodLengths" => [5, 5]), first_period=same, second_period=same) do dir
            data = case_with(period_with("first_period"), period_with("second_period"))
            settings = @test_logs (:warn, r"given per period") min_level=Logging.Warn resolve_settings(data, dir)
            @test settings.ConstraintScaling
        end
    end

    @testset "Settings that differ between periods are errors" begin
        with_settings_files(case_settings=Dict("PeriodLengths" => [5, 5]),
            first_period=Dict("ConstraintScaling" => true, "Retrofitting" => false),
            second_period=Dict("ConstraintScaling" => false, "Retrofitting" => false)) do dir
            data = case_with(period_with("first_period"), period_with("second_period"))
            msg = error_message(() -> resolve_settings(data, dir))
            @test occursin("system_data.case[2].settings: differs from period 1 in ConstraintScaling.", msg)
        end
    end

    @testset "Per-period settings must not contradict case_settings.json" begin
        with_settings_files(case_settings=Dict("ConstraintScaling" => true), macro_settings=Dict("ConstraintScaling" => false)) do dir
            msg = error_message(() -> resolve_settings(case_with(period_with("macro_settings")), dir))
            @test occursin("case_settings.ConstraintScaling: is true in case_settings.json but false in the per-period settings", msg)
        end
        with_settings_files(case_settings=Dict("ConstraintScaling" => true), macro_settings=Dict("ConstraintScaling" => true)) do dir
            settings = @test_logs (:warn, r"given per period") min_level=Logging.Warn resolve_settings(case_with(period_with("macro_settings")), dir)
            @test settings.ConstraintScaling
        end
    end

    @testset "The deprecated layout of the small test case" begin
        path = joinpath(@__DIR__, "test_small_case", "system_data.json")
        settings = resolve_settings(load_case_data(path), dirname(path))
        @test settings.ConstraintScaling
        @test settings.OutputSettings.Layout == "wide"
    end
end

function test_single_period_settings()
    @testset "A single period without a settings entry" begin
        with_settings_files(case_settings=Dict("DiscountRate" => 0.05, "ConstraintScaling" => true)) do dir
            data = Dict{Symbol,Any}(:settings => single_system_case_settings(joinpath(dir, "system_data.json")), :case => [Dict{Symbol,Any}()])
            settings = @test_logs min_level=Logging.Warn resolve_settings(data, dir)
            @test settings.DiscountRate == 0.05
            @test settings.ConstraintScaling
        end
        mktempdir() do dir
            data = Dict{Symbol,Any}(:settings => single_system_case_settings(joinpath(dir, "system_data.json")), :case => [Dict{Symbol,Any}()])
            settings = @test_logs min_level=Logging.Warn resolve_settings(data, dir)
            @test isequal(settings, configure_settings(NamedTuple()))
        end
    end

    @testset "A System loaded on its own" begin
        with_settings_files(case_settings=Dict("DiscountRate" => 0.05, "ConstraintScaling" => true)) do dir
            # Its `settings` entry
            settings = standalone_settings(period_with("case_settings"), dir)
            @test settings.ConstraintScaling
            @test settings.DiscountRate == 0.05
            # No `settings` entry: the conventional file
            @test standalone_settings(Dict{Symbol,Any}(), dir).ConstraintScaling
            # Settings written inline
            inline = Dict{Symbol,Any}(:settings => Dict{Symbol,Any}(:Retrofitting => true))
            @test standalone_settings(inline, dir).Retrofitting
        end
        mktempdir() do dir
            @test isequal(standalone_settings(Dict{Symbol,Any}(), dir), configure_settings(NamedTuple()))
        end
    end
end

function test_benders_settings_sources()
    @testset "Where Benders settings come from" begin
        benders = Dict("SolutionAlgorithm" => "Benders")
        # The conventional file
        with_settings_files(case_settings=benders, benders_settings=Dict("MaxIter" => 7)) do dir
            settings = resolve_settings(case_with(Dict{Symbol,Any}()), dir)
            @test settings.SolutionAlgorithm isa Benders
            @test settings.BendersSettings[:MaxIter] == 7
        end
        # Settings written in case_settings.json
        with_settings_files(case_settings=merge(benders, Dict("BendersSettings" => Dict("MaxIter" => 8)))) do dir
            settings = resolve_settings(case_with(Dict{Symbol,Any}()), dir)
            @test settings.BendersSettings[:MaxIter] == 8
        end
        # As documented, the conventional file has priority over settings written in case_settings.json
        with_settings_files(case_settings=merge(benders, Dict("BendersSettings" => Dict("MaxIter" => 8))),
            benders_settings=Dict("MaxIter" => 7)) do dir
            settings = resolve_settings(case_with(Dict{Symbol,Any}()), dir)
            @test settings.BendersSettings[:MaxIter] == 7
        end
        # A file named in case_settings.json has priority over the conventional file
        with_settings_files(case_settings=merge(benders, Dict("BendersSettings" => Dict("path" => "settings/other.json"))),
            other=Dict("MaxIter" => 9), benders_settings=Dict("MaxIter" => 7)) do dir
            settings = resolve_settings(case_with(Dict{Symbol,Any}()), dir)
            @test settings.BendersSettings[:MaxIter] == 9
        end
    end
end

function test_settings_template()
    @testset "The new-case template is a valid settings file" begin
        mktempdir() do dir
            path = joinpath(dir, "case_settings.json")
            template_settings_file(path)
            data = Dict{Symbol,Any}(:settings => Dict{Symbol,Any}(:path => path), :case => [Dict{Symbol,Any}()])
            settings = @test_logs min_level=Logging.Warn resolve_settings(data, dir)
            @test isequal(settings, configure_settings(NamedTuple()))
        end
    end
end

test_default_settings_start_year()
test_configure_settings_start_year()
test_load_time_data_year_via_path()
test_generate_case_start_year()
test_one_settings_file()
test_comment_keys()
test_deprecated_period_settings()
test_single_period_settings()
test_benders_settings_sources()
test_settings_template()

end # module TestCaseSettings
