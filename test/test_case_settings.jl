module TestCaseSettings

using Test
using Logging
using JSON3
using HiGHS
import MacroEnergy:
    create_optimizer,
    generate_model,
    InputBlock,
    InputField,
    InputMap,
    benders_settings_spec,
    input_name,
    myopic_settings_spec,
    settings_spec,
    Benders,
    InputValidationError,
    Monolithic,
    configure_settings,
    default_settings,
    resolve_settings,
    single_system_case_settings,
    standalone_settings,
    template_settings_file,
    write_settings,
    Case,
    System,
    load_time_data,
    load_case,
    load_case_data,
    load_system,
    prep_system_data,
    prepare_to_json,
    read_json,
    write_json,
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

function test_settings_sources()
    @testset "A case without a top-level settings entry uses the conventional file" begin
        with_settings_files(case_settings=Dict("DiscountRate" => 0.07, "ConstraintScaling" => true)) do dir
            data = Dict{Symbol,Any}(:case => [Dict{Symbol,Any}()])
            settings = @test_logs min_level=Logging.Warn resolve_settings(data, dir)
            @test settings.DiscountRate == 0.07
            @test settings.ConstraintScaling
        end
    end

    @testset "A period without settings next to one with settings is an error" begin
        with_settings_files(case_settings=Dict("PeriodLengths" => [5, 5]), macro_settings=Dict("AutoCreateNodes" => true)) do dir
            msg = error_message(() -> resolve_settings(case_with(period_with("macro_settings"), Dict{Symbol,Any}()), dir))
            @test occursin("system_data.case[2].settings: this period has no settings of its own, but period 1 does", msg)
            # The same when the period points to the case-level file
            msg = error_message(() -> resolve_settings(case_with(period_with("macro_settings"), period_with("case_settings")), dir))
            @test occursin("system_data.case[2].settings: this period has no settings of its own", msg)
        end
    end

    @testset "A case's own settings entry is not a per-period file" begin
        # A custom file name, or the old name, as the only settings file of a single period
        with_settings_files(custom=Dict("DiscountRate" => 0.07), macro_settings=Dict("ConstraintScaling" => true)) do dir
            for (name, check) in (("custom", s -> s.DiscountRate == 0.07), ("macro_settings", s -> s.ConstraintScaling))
                period = period_with(name)
                data = Dict{Symbol,Any}(:settings => single_system_case_settings(joinpath(dir, "system_data.json"), period), :case => [period])
                @test check(@test_logs min_level=Logging.Warn resolve_settings(data, dir))
            end
        end
        # Loading eagerly replaces the entry by the content of the file
        path = joinpath(@__DIR__, "test_inputs", "system_data.json")
        data = load_case_data(path; lazy_load=false)
        @test (@test_logs min_level=Logging.Warn resolve_settings(data, dirname(path))).OutputSettings.Write.FullTimeseries
    end

    @testset "An entry can be a directory" begin
        with_settings_files(case_settings=Dict("DiscountRate" => 0.07)) do dir
            period = Dict{Symbol,Any}(:settings => Dict{Symbol,Any}(:path => "settings"))
            @test (@test_logs min_level=Logging.Warn standalone_settings(period, dir)).DiscountRate == 0.07
        end
        # Without case_settings.json in it, the deprecated file
        with_settings_files(macro_settings=Dict("ConstraintScaling" => true)) do dir
            period = Dict{Symbol,Any}(:settings => Dict{Symbol,Any}(:path => "settings"))
            @test standalone_settings(period, dir).ConstraintScaling
        end
    end

    @testset "An entry can be a plain path" begin
        with_settings_files(case_settings=Dict("DiscountRate" => 0.07), macro_settings=Dict("ConstraintScaling" => true)) do dir
            top_level = Dict{Symbol,Any}(:settings => "settings/case_settings.json", :case => [Dict{Symbol,Any}(:settings => "settings/macro_settings.json")])
            settings = with_logger(() -> resolve_settings(top_level, dir), NullLogger())
            @test settings.DiscountRate == 0.07
            @test settings.ConstraintScaling
            @test with_logger(() -> standalone_settings(Dict{Symbol,Any}(:settings => "settings/macro_settings.json"), dir), NullLogger()).ConstraintScaling
        end
        # Anything else is a clear error
        msg = error_message(() -> resolve_settings(Dict{Symbol,Any}(:settings => 5, :case => Any[]), pwd()))
        @test occursin("system_data.settings: expected a path or an object, got 5", msg)
    end

    @testset "load_system and load_case use the same settings" begin
        # The deprecated two-file layout, with some settings already moved to case_settings.json
        with_settings_files(case_settings=Dict("AutoCreateNodes" => true), macro_settings=Dict("ConstraintScaling" => true)) do dir
            period = period_with("macro_settings")
            standalone = @test_logs (:warn, r"given per period") min_level=Logging.Warn standalone_settings(period, dir)
            data = Dict{Symbol,Any}(:settings => single_system_case_settings(joinpath(dir, "system_data.json"), period), :case => [period])
            @test isequal(standalone, with_logger(() -> resolve_settings(data, dir), NullLogger()))
            @test standalone.AutoCreateNodes
            @test standalone.ConstraintScaling
        end
    end
end

# What older versions wrote for a new case: every default, with the old names
const OLDER_TEMPLATE = Dict(
    "ConstraintScaling" => false, "EnableJuMPDirectModel" => false, "EnableJuMPStringNames" => false,
    "AllowImplicitTopLevelCommodities" => true, "WriteSubcommodities" => true, "OverwriteResults" => false,
    "OutputDir" => "results", "OutputLayout" => "long", "OutputFormat" => "csv", "WriteOutputs" => Dict(),
    "OutputSignificantDigits" => nothing, "OutputAssetTags" => true, "AutoCreateNodes" => false,
    "AutoCreateLocations" => true, "Retrofitting" => false, "DualExportsEnabled" => nothing,
)

function test_older_settings_files()
    defaults = configure_settings(NamedTuple())
    @testset "The settings template of older versions still loads" begin
        settings = with_logger(() -> configure_settings(OLDER_TEMPLATE), NullLogger())
        @test isequal(settings, defaults)
        @test_nowarn with_logger(() -> configure_settings(Dict("DualExportsEnabled" => nothing)), NullLogger())
    end

    @testset "Old defaults do not conflict with new per-output maps" begin
        with_settings_files(case_settings=Dict("OutputSettings" => Dict(
            "Format" => Dict("Flow" => "parquet"), "Layout" => Dict("Flow" => "wide"), "Write" => Dict("FullTimeseries" => true),
        )), macro_settings=OLDER_TEMPLATE) do dir
            settings = with_logger(() -> resolve_settings(case_with(period_with("macro_settings")), dir), NullLogger())
            @test settings.OutputSettings.Format == (Flow="parquet",)
            @test settings.OutputSettings.Layout == (Flow="wide",)
            @test settings.OutputSettings.Write == (FullTimeseries=true,)
        end
        # A value that is not the default is a real conflict
        msg = error_message(() -> with_logger(() -> configure_settings((OutputFormat="parquet", OutputSettings=(Format=(Flow="csv",),))), NullLogger()))
        @test occursin("case_settings.OutputFormat: conflicts with OutputSettings.Format", msg)
    end

    @testset "Settings are combined key by key" begin
        # Different keys of a block, in the two files
        with_settings_files(case_settings=Dict("OutputSettings" => Dict("Dir" => "out")),
            macro_settings=Dict("OutputSettings" => Dict("Format" => "parquet"))) do dir
            settings = with_logger(() -> resolve_settings(case_with(period_with("macro_settings")), dir), NullLogger())
            @test settings.OutputSettings.Dir == "out"
            @test settings.OutputSettings.Format == "parquet"
        end
        # Different entries of a map, under the old and new names
        settings = with_logger(() -> configure_settings((WriteOutputs=(Flow=false,), OutputSettings=(Write=(Duals=false,),))), NullLogger())
        @test settings.OutputSettings.Write.Flow == false
        @test settings.OutputSettings.Write.Duals == false
        # The same entry with different values is a conflict, named by its full path
        msg = error_message(() -> with_logger(() -> configure_settings((WriteOutputs=(Flow=false,), OutputSettings=(Write=(Flow=true,),))), NullLogger()))
        @test occursin("case_settings.WriteOutputs: conflicts with OutputSettings.Write.Flow = true", msg)
        with_settings_files(case_settings=Dict("OutputSettings" => Dict("Dir" => "a")),
            macro_settings=Dict("OutputSettings" => Dict("Dir" => "b"))) do dir
            msg = error_message(() -> resolve_settings(case_with(period_with("macro_settings")), dir))
            @test occursin("case_settings.OutputSettings.Dir: is \"a\" in case_settings.json but \"b\" in the per-period settings", msg)
        end
    end

    @testset "Benders settings files" begin
        benders = Dict("SolutionAlgorithm" => "Benders")
        missing_file = Dict("BendersSettings" => Dict("path" => "settings/missing.json"))
        # A missing file named in the settings is reported as such
        with_settings_files(case_settings=merge(benders, missing_file)) do dir
            msg = error_message(() -> with_logger(() -> resolve_settings(case_with(Dict{Symbol,Any}()), dir), NullLogger()))
            @test occursin("case_settings.BendersSettings.path: file not found", msg)
        end
        # unless the conventional file can be used instead, with a warning
        with_settings_files(case_settings=merge(benders, missing_file), benders_settings=Dict("MaxIter" => 7)) do dir
            settings = @test_logs (:warn, r"not found") min_level=Logging.Warn match_mode=:any resolve_settings(case_with(Dict{Symbol,Any}()), dir)
            @test settings.BendersSettings[:MaxIter] == 7
        end
        # The conventional file takes priority over different settings written in case_settings.json, with a warning
        with_settings_files(case_settings=merge(benders, Dict("BendersSettings" => Dict("MaxIter" => 8))),
            benders_settings=Dict("MaxIter" => 7)) do dir
            settings = @test_logs (:warn, r"takes priority") min_level=Logging.Warn resolve_settings(case_with(Dict{Symbol,Any}()), dir)
            @test settings.BendersSettings[:MaxIter] == 7
        end
        # No warning if they agree
        with_settings_files(case_settings=merge(benders, Dict("BendersSettings" => Dict("MaxIter" => 7))),
            benders_settings=Dict("MaxIter" => 7)) do dir
            @test (@test_logs min_level=Logging.Warn resolve_settings(case_with(Dict{Symbol,Any}()), dir)).BendersSettings[:MaxIter] == 7
        end
    end
end

function test_settings_entry_forms()
    @testset "Settings paths are relative to the case, not to the current directory" begin
        with_settings_files(case_settings=Dict("DiscountRate" => 0.07)) do dir
            with_settings_files(case_settings=Dict("DiscountRate" => 0.99)) do elsewhere
                cd(elsewhere) do
                    data = Dict{Symbol,Any}(:settings => settings_file("case_settings"), :case => [period_with("case_settings")])
                    settings = @test_logs min_level=Logging.Warn resolve_settings(data, dir)
                    @test settings.DiscountRate == 0.07
                end
            end
        end
        # A named Benders file too
        with_settings_files(case_settings=Dict("SolutionAlgorithm" => "Benders", "BendersSettings" => Dict("path" => "settings/my_benders.json")),
            my_benders=Dict("MaxIter" => 7)) do dir
            with_settings_files(my_benders=Dict("MaxIter" => 99)) do elsewhere
                cd(elsewhere) do
                    @test resolve_settings(case_with(Dict{Symbol,Any}()), dir).BendersSettings[:MaxIter] == 7
                end
            end
        end
    end

    @testset "A null settings entry is the same as no entry" begin
        with_settings_files(case_settings=Dict("DiscountRate" => 0.07)) do dir
            period = Dict{Symbol,Any}(:settings => nothing)
            @test (@test_logs min_level=Logging.Warn standalone_settings(period, dir)).DiscountRate == 0.07
            data = Dict{Symbol,Any}(:settings => nothing, :case => [period])
            @test (@test_logs min_level=Logging.Warn resolve_settings(data, dir)).DiscountRate == 0.07
        end
    end

    @testset "A null BendersSettings is the same as none" begin
        with_settings_files(case_settings=Dict("SolutionAlgorithm" => "Benders", "BendersSettings" => nothing),
            benders_settings=Dict("MaxIter" => 7)) do dir
            settings = @test_logs min_level=Logging.Warn resolve_settings(case_with(Dict{Symbol,Any}()), dir)
            @test settings.BendersSettings[:MaxIter] == 7
        end
    end

    @testset "A null old name in one file does not conflict with a value in the other" begin
        with_settings_files(case_settings=Dict("OutputSignificantDigits" => 4), macro_settings=Dict("OutputSignificantDigits" => nothing)) do dir
            settings = with_logger(() -> resolve_settings(case_with(period_with("macro_settings")), dir), NullLogger())
            @test settings.OutputSettings.SignificantDigits == 4
        end
    end

    @testset "No priority warning when the Benders settings agree once defaults are filled in" begin
        with_settings_files(case_settings=Dict("SolutionAlgorithm" => "Benders"), benders_settings=Dict("MaxIter" => 7)) do dir
            data = case_with(Dict{Symbol,Any}())
            settings = @test_logs min_level=Logging.Warn resolve_settings(data, dir)
            write_settings(Case(System[], settings), joinpath(dir, "settings", "case_settings.json"))
            reloaded = @test_logs min_level=Logging.Warn resolve_settings(data, dir)
            @test isequal(reloaded, settings)
        end
    end

    @testset "A scaling factor of zero is rejected" begin
        @test occursin("case_settings.ParameterScalingFactor: expected a number > 0",
            error_message(() -> configure_settings((ParameterScaling=true, ParameterScalingFactor=0))))
    end
end

function test_system_data_survives_loading()
    @testset "Loading does not destroy a system_data.json it cannot rewrite" begin
        mktempdir() do dir
            path = joinpath(dir, "system_data.json")
            write(path, """{"settings": {"MyopicSettings": {"StopAfterPeriod": Infinity}}}""")
            prep_system_data(path)
            @test isinf(read_json(path)[:settings][:MyopicSettings][:StopAfterPeriod])
        end
    end
end

function test_old_names_before_the_model()
    @testset "Old names set from Julia are reported before building the model" begin
        case = with_logger(() -> load_case(test_path), NullLogger())
        system = case.systems[1]
        system.settings = merge(system.settings, (OverwriteResults=true,))
        message = "system.settings.OverwriteResults: is no longer used"
        optimizer = create_optimizer(HiGHS.Optimizer)
        @test occursin(message, error_message(() -> generate_model(case, optimizer, Monolithic())))
        @test occursin(message, error_message(() -> generate_model(system, optimizer, case.settings, Monolithic())))
        benders_optimizer = Dict{Symbol,Dict{Symbol,Any}}()
        @test occursin(message, error_message(() -> generate_model(case, benders_optimizer, Benders())))
        @test occursin(message, error_message(() -> generate_model(system, benders_optimizer, case.settings, Benders())))
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

# A valid value of `spec` that differs from its default, taken from the spec's own rules. It fails
# on a kind of setting it does not know, so that a new setting cannot skip the round-trip test.
sample_value(spec::InputBlock) = (; (input_name(f) => sample_value(f) for f in spec.fields)...)
sample_value(spec::InputMap) = (; first(spec.keys) => sample_entry(spec.entry))
sample_value(spec::InputField) = isnothing(spec.eltype) ? sample_entry(spec) : [sample_number(spec, spec.eltype), sample_number(spec, spec.eltype) + 1]
function sample_entry(field::InputField)
    isnothing(field.enum) || return last(filter(!=(field.default), collect(field.enum)))
    type = field.type
    type isa Union && (type = only(t for t in Base.uniontypes(type) if !(t in (Nothing, Missing))))
    type === Bool && return !something(field.default, false)
    type <: AbstractString && return "sample"
    type <: Real && return sample_number(field, type)
    type <: AbstractDict && return nothing   # BendersSettings and MyopicSettings have their own specs
    error("sample_entry does not know how to make a value of type $type for $(field.name)")
end
sample_number(field::InputField, type::Type) = (type <: Integer ? 2 : 2.5) + something(field.minimum, field.exclusive_minimum, 0)

# Write `input` through the real writer, read it back through the real loader, and compare both
# the values and their types: `isequal(0, 0.0)` is true, but the model needs a Float64.
function test_round_trip(input)
    settings = with_logger(() -> configure_settings(input), NullLogger())
    mktempdir() do dir
        path = joinpath(dir, "settings.json")
        write_settings(Case(System[], settings), path)
        data = Dict{Symbol,Any}(:settings => Dict{Symbol,Any}(:path => path), :case => Any[])
        reloaded = with_logger(() -> resolve_settings(data, dir), NullLogger())
        @test isequal(reloaded, settings)
        @test typeof(reloaded) == typeof(settings)
    end
end

function test_settings_file_reloads()
    @testset "Every setting survives the write and reload" begin
        spec = settings_spec()
        test_round_trip(NamedTuple())
        for field in spec.fields
            key = input_name(field)
            value = sample_value(field)
            # Includes every entry of a nested block, one at a time
            if field isa InputBlock
                for entry in field.fields
                    test_round_trip((; key => (; input_name(entry) => sample_value(entry))))
                end
            elseif !isnothing(value)
                test_round_trip((; key => value))
            end
        end
        for (spec, activate) in ((benders_settings_spec(), (SolutionAlgorithm="Benders",)), (myopic_settings_spec(), (ExpansionHorizon="Myopic",)))
            key = input_name(spec)
            test_round_trip(activate)
            for entry in spec.fields
                entry_input = (; input_name(entry) => sample_value(entry))
                # Restart.from_period must not be after StopAfterPeriod
                input_name(entry) == :Restart && (entry_input = (Restart=(enabled=true, folder="sample", from_period=2),))
                test_round_trip(merge(activate, (; key => entry_input)))
            end
        end
    end

    @testset "The settings in written system data can be read back" begin
        system = with_logger(() -> load_system(test_path), NullLogger())
        written = prepare_to_json(system)[:settings]
        @test !haskey(written, :StartYear)
        @test written[:SolutionAlgorithm] == "Monolithic"
        @test written[:ExpansionHorizon] == "PerfectForesight"
        mktempdir() do dir
            path = joinpath(dir, "settings.json")
            write_json(path, written)
            data = Dict{Symbol,Any}(:settings => Dict{Symbol,Any}(:path => path), :case => Any[])
            reloaded = with_logger(() -> resolve_settings(data, dir), NullLogger())
            @test isequal(reloaded, system.settings)
            @test typeof(reloaded) == typeof(system.settings)
        end
    end

    @testset "results/settings.json can be read back as case_settings.json" begin
        inputs = (
            NamedTuple(),
            (ExpansionHorizon="Myopic", PeriodLengths=[5, 5], MyopicSettings=(StopAfterPeriod=1,)),
            (SolutionAlgorithm="Benders", BendersSettings=(MaxIter=10,)),
            (StartYear=2030, DiscountRate=0.05, ParameterScaling=true, ConstraintScaling=true,
                OutputSettings=(Format=(Flow="parquet",), Layout="wide", Write=(Curtailment=false, FullTimeseries=true), SignificantDigits=4)),
        )
        for input in inputs
            settings = with_logger(() -> configure_settings(input), NullLogger())
            mktempdir() do dir
                path = joinpath(dir, "settings.json")
                write_settings(Case(System[], settings), path)
                data = Dict{Symbol,Any}(:settings => Dict{Symbol,Any}(:path => path), :case => Any[])
                reloaded = @test_logs min_level=Logging.Warn resolve_settings(data, dir)
                @test isequal(reloaded, settings)
            end
        end
    end

    @testset "A case loads with the settings.json of an earlier run" begin
        for fixture in ("test_inputs", "test_small_case")
            mktempdir() do root
                case_dir = joinpath(root, "case")
                cp(joinpath(@__DIR__, fixture), case_dir)
                rm(joinpath(case_dir, "results"); recursive=true, force=true)
                original = with_logger(() -> load_case(case_dir), NullLogger())
                # The settings written for a default discount rate include `"DiscountRate": 0`
                settings_path = joinpath(root, "settings.json")
                write_settings(original, settings_path)
                cp(settings_path, joinpath(case_dir, "settings", "case_settings.json"); force=true)
                reloaded = with_logger(() -> load_case(case_dir), NullLogger())
                @test isequal(reloaded.settings, original.settings)
                @test reloaded.settings.DiscountRate isa Float64
                @test length(reloaded.systems) == length(original.systems)
            end
        end
        # A rate written by hand as a whole number
        mktempdir() do root
            case_dir = joinpath(root, "case")
            cp(joinpath(@__DIR__, "test_inputs"), case_dir)
            for rate in ("0", "0.0")
                write(joinpath(case_dir, "settings", "case_settings.json"), """{"DiscountRate": $rate}""")
                @test with_logger(() -> load_case(case_dir), NullLogger()).settings.DiscountRate === 0.0
            end
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
test_settings_sources()
test_older_settings_files()
test_settings_entry_forms()
test_system_data_survives_loading()
test_old_names_before_the_model()
test_deprecated_period_settings()
test_single_period_settings()
test_benders_settings_sources()
test_settings_template()
test_settings_file_reloads()

end # module TestCaseSettings
