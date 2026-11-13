module TestMigrateSettings

using Test
using Logging
using JSON3
using MacroEnergy
import MacroEnergy: migrate_settings, resolve_settings, standalone_settings, settings_dict, read_json, InputValidationError

# Write the files of a case, given as `relative path => JSON text`
function write_case(dir, files)
    for (path, text) in files
        mkpath(dirname(joinpath(dir, path)))
        write(joinpath(dir, path), text)
    end
    return dir
end

# Every file of a case, to check that nothing was written
function snapshot(dir)
    files = Dict{String,String}()
    for (root, _, names) in walkdir(dir), name in names
        files[relpath(joinpath(root, name), dir)] = read(joinpath(root, name), String)
    end
    return files
end

# The settings `load_case` uses for the case in `dir`
function loaded_settings(dir)
    data = settings_dict(read_json(joinpath(dir, "system_data.json")))
    haskey(data, :case) || return standalone_settings(data, dir)
    data[:case] = Any[settings_dict(period) for period in data[:case]]
    return resolve_settings(data, dir)
end
quietly(f) = with_logger(f, NullLogger())
same_settings(a, b) = isequal(settings_dict(a), settings_dict(b))
json(text) = settings_dict(JSON3.read(text))

# The example of "Updating older cases" in the settings guide
const OLD_CASE_SETTINGS = """{"SolutionAlgorithm": "Monolithic", "PeriodLengths": [5, 5], "DiscountRate": 0.045, "WriteFullTimeseries": true}"""
const OLD_SYSTEM_SETTINGS = """{"ConstraintScaling": true, "AutoCreateNodes": true, "OverwriteResults": true, "OutputDir": "results",
    "OutputFormat": "csv.gz", "OutputLayout": {"Capacity": "wide", "Flow": "long"}, "WriteOutputs": {"Curtailment": false}}"""
const NEW_CASE_SETTINGS = """{"SolutionAlgorithm": "Monolithic", "PeriodLengths": [5, 5], "DiscountRate": 0.045,
    "ConstraintScaling": true, "AutoCreateNodes": true, "OutputSettings": {"Dir": "results", "Overwrite": true,
    "Format": "csv.gz", "Layout": {"Capacity": "wide", "Flow": "long"}, "Write": {"Curtailment": false, "FullTimeseries": true}}}"""
period(name) = """{"time_data": {"path": "$name.json"}, "settings": {"path": "settings/macro_settings.json"}, "nodes": {"path": "nodes.json"}}"""

@testset "migrate_settings" begin
    @testset "The example of the migration guide" begin
        mktempdir() do dir
            write_case(dir, ["settings/case_settings.json" => OLD_CASE_SETTINGS, "settings/macro_settings.json" => OLD_SYSTEM_SETTINGS,
                "system_data.json" => """{"settings": {"path": "settings/case_settings.json"}, "case": [$(period("a")), $(period("b"))]}"""])
            original_files, original_settings = snapshot(dir), quietly(() -> loaded_settings(dir))
            expected = json(NEW_CASE_SETTINGS)

            # A dry run reports the changes and writes nothing
            settings = @test_logs (:info, r"Dry run") migrate_settings(dir)
            @test isequal(settings, expected)
            # In the order of the guide
            @test collect(keys(settings)) == collect(keys(expected))
            @test snapshot(dir) == original_files

            @test isequal(migrate_settings(dir; dry_run=false), expected)
            @test collect(keys(read_json(joinpath(dir, "settings", "case_settings.json")))) == collect(keys(expected))
            system_data = read_json(joinpath(dir, "system_data.json"))
            @test system_data[:settings][:path] == "settings/case_settings.json"
            # Only the settings entries are removed, and the other keys keep their order
            @test [collect(keys(p)) for p in system_data[:case]] == [[:time_data, :nodes], [:time_data, :nodes]]
            # Old files are kept
            @test isfile(joinpath(dir, "settings", "macro_settings.json"))
            # The case loads the same settings, without warnings
            @test same_settings((@test_logs min_level=Logging.Warn loaded_settings(dir)), original_settings)

            migrated = snapshot(dir)
            @test_logs (:info, r"already up to date") migrate_settings(dir; dry_run=false)
            @test snapshot(dir) == migrated
        end
    end

    @testset "A single-period case written without a case key" begin
        mktempdir() do dir
            write_case(dir, ["settings/macro_settings.json" => """{"ConstraintScaling": true, "OutputDir": "out"}""",
                "system_data.json" => """{"settings": {"path": "settings/macro_settings.json"}, "time_data": {"path": "t.json"}}"""])
            original = quietly(() -> loaded_settings(dir))
            @test isequal(migrate_settings(dir; dry_run=false), json("""{"ConstraintScaling": true, "OutputSettings": {"Dir": "out"}}"""))
            @test !haskey(read_json(joinpath(dir, "system_data.json")), :settings)
            @test isfile(joinpath(dir, "settings", "case_settings.json"))
            @test same_settings((@test_logs min_level=Logging.Warn loaded_settings(dir)), original)
        end
        # With case_settings.json too, the two files are merged
        mktempdir() do dir
            write_case(dir, ["settings/case_settings.json" => """{"DiscountRate": 0.05, "WriteFullTimeseries": true}""",
                "settings/macro_settings.json" => """{"ConstraintScaling": true}""",
                "system_data.json" => """{"settings": {"path": "settings/macro_settings.json"}, "time_data": {"path": "t.json"}}"""])
            original = quietly(() -> loaded_settings(dir))
            @test isequal(migrate_settings(dir; dry_run=false),
                json("""{"DiscountRate": 0.05, "ConstraintScaling": true, "OutputSettings": {"Write": {"FullTimeseries": true}}}"""))
            @test !haskey(read_json(joinpath(dir, "system_data.json")), :settings)
            @test same_settings((@test_logs min_level=Logging.Warn loaded_settings(dir)), original)
        end
    end

    @testset "A case key with macro_settings.json only" begin
        mktempdir() do dir
            write_case(dir, ["settings/macro_settings.json" => """{"ConstraintScaling": true, "WriteOutputs": {"Duals": false}}""",
                "system_data.json" => """{"case": [$(period("a")), $(period("b"))]}"""])
            original = quietly(() -> loaded_settings(dir))
            @test isequal(migrate_settings(dir; dry_run=false),
                json("""{"ConstraintScaling": true, "OutputSettings": {"Write": {"Duals": false}}}"""))
            @test isfile(joinpath(dir, "settings", "case_settings.json"))
            @test !any(p -> haskey(p, :settings), read_json(joinpath(dir, "system_data.json"))[:case])
            @test same_settings((@test_logs min_level=Logging.Warn loaded_settings(dir)), original)
        end
    end

    # File names are case-insensitive on Windows and, by default, on macOS: there, a path spelled
    # with different case is the same file. Elsewhere the file does not exist, and there is no test.
    @testset "A path spelled with different case is the same file" begin
        mktempdir() do dir
            write_case(dir, ["settings/case_settings.json" => """{"ConstraintScaling": true}""",
                "system_data.json" => """{"settings": {"path": "settings/case_settings.json"},
                    "case": [{"time_data": {"path": "t.json"}, "settings": {"path": "Settings/Case_Settings.json"}}]}"""])
            if isfile(joinpath(dir, "Settings", "Case_Settings.json"))
                # The period has no settings of its own: no warning, and nothing to migrate
                @test_logs min_level=Logging.Warn loaded_settings(dir)
                @test_logs (:info, r"already up to date") migrate_settings(dir)
            end
        end
    end

    @testset "Old defaults next to new names" begin
        # What older versions wrote for every new case, next to a new setting added by hand
        mktempdir() do dir
            write_case(dir, ["settings/macro_settings.json" => """{"OverwriteResults": false, "OutputDir": "results",
                    "OutputFormat": "csv", "OutputLayout": "long", "WriteOutputs": {}, "OutputAssetTags": true}""",
                "settings/case_settings.json" => """{"OutputSettings": {"Overwrite": true}}""",
                "system_data.json" => """{"case": [$(period("a"))]}"""])
            original = quietly(() -> loaded_settings(dir))
            @test original.OutputSettings.Overwrite
            settings = migrate_settings(dir; dry_run=false)
            @test settings[:OutputSettings][:Overwrite] == true
            @test same_settings((@test_logs min_level=Logging.Warn loaded_settings(dir)), original)
        end
    end

    @testset "Files are found next to system_data.json only" begin
        mktempdir() do root
            # The case's top-level settings file is missing; another case's is in the current directory
            other, dir = mkpath(joinpath(root, "other")), mkpath(joinpath(root, "case"))
            write_case(other, ["settings/case_settings.json" => """{"DiscountRate": 0.99}"""])
            write_case(dir, ["settings/macro_settings.json" => """{"ConstraintScaling": true}""",
                "system_data.json" => """{"settings": {"path": "settings/case_settings.json"}, "case": [$(period("a"))]}"""])
            original = snapshot(other)
            cd(other) do
                @test_throws ErrorException quietly(() -> migrate_settings(dir; dry_run=false))
            end
            @test snapshot(other) == original
        end
        # A file outside the case is reported in full
        mktempdir() do root
            shared, dir = mkpath(joinpath(root, "shared")), mkpath(joinpath(root, "case"))
            write_case(shared, ["case_settings.json" => """{"DiscountRate": 0.05}"""])
            target = joinpath(shared, "case_settings.json")
            write_case(dir, ["settings/macro_settings.json" => """{"ConstraintScaling": true}""",
                "system_data.json" => """{"settings": {"path": $(repr(target))}, "case": [$(period("a"))]}"""])
            @test_logs (:info, Regex("these settings to \\Q$target\\E:")) migrate_settings(dir)
        end
    end

    @testset "Settings that cannot be loaded are not migrated" begin
        mktempdir() do dir
            # Periods with different settings
            write_case(dir, ["settings/a.json" => """{"ConstraintScaling": true}""", "settings/b.json" => """{"ConstraintScaling": false}""",
                "system_data.json" => """{"case": [{"settings": {"path": "settings/a.json"}}, {"settings": {"path": "settings/b.json"}}]}"""])
            original = snapshot(dir)
            @test_throws InputValidationError migrate_settings(dir; dry_run=false)
            @test snapshot(dir) == original
            # An unknown setting
            write_case(dir, ["settings/b.json" => """{"ConstraintScaling": true, "NoSuchSetting": 1}"""])
            original = snapshot(dir)
            @test_throws InputValidationError migrate_settings(dir; dry_run=false)
            @test snapshot(dir) == original
        end
        # case_settings.json and macro_settings.json disagree, under the same name or an old and a new one
        for (case_settings, system_settings) in (("""{"ConstraintScaling": true}""", """{"ConstraintScaling": false}"""),
                ("""{"WriteFullTimeseries": true}""", """{"WriteOutputs": {"FullTimeseries": false}}"""))
            mktempdir() do dir
                write_case(dir, ["settings/case_settings.json" => case_settings, "settings/macro_settings.json" => system_settings,
                    "system_data.json" => """{"case": [$(period("a"))]}"""])
                original = snapshot(dir)
                @test_throws InputValidationError migrate_settings(dir; dry_run=false)
                @test snapshot(dir) == original
            end
        end
    end

    @testset "Benders settings stay where they are" begin
        mktempdir() do dir
            write_case(dir, ["settings/case_settings.json" => """{"SolutionAlgorithm": "Benders", "BendersSettings": {"path": "settings/my_benders.json"}}""",
                "settings/my_benders.json" => """{"MaxIter": 7}""",
                "settings/macro_settings.json" => """{"OutputDir": "out"}""",
                "system_data.json" => """{"case": [{"settings": {"path": "settings/macro_settings.json"}}]}"""])
            settings = migrate_settings(dir; dry_run=false)
            @test isequal(settings[:BendersSettings], json("""{"path": "settings/my_benders.json"}"""))
            @test (@test_logs min_level=Logging.Warn loaded_settings(dir)).BendersSettings[:MaxIter] == 7
        end
    end

    @testset "Settings written in the top-level entry stay there" begin
        mktempdir() do dir
            write_case(dir, ["settings/macro_settings.json" => """{"ConstraintScaling": true}""",
                "system_data.json" => """{"settings": {"OutputDir": "out"}, "case": [{"settings": {"path": "settings/macro_settings.json"}}]}"""])
            migrate_settings(dir; dry_run=false)
            @test isequal(settings_dict(read_json(joinpath(dir, "system_data.json"))[:settings]),
                json("""{"ConstraintScaling": true, "OutputSettings": {"Dir": "out"}}"""))
            @test !isfile(joinpath(dir, "settings", "case_settings.json"))
        end
    end

    @testset "Comments that are not carried over are reported" begin
        mktempdir() do dir
            write_case(dir, ["settings/case_settings.json" => """{"#": "my case", "OutputDir": "out"}""",
                "system_data.json" => """{"case": [{"time_data": {"path": "t.json"}}]}"""])
            @test_logs (:info, r"will:(.|\n)*leave out the comments") migrate_settings(dir)
        end
    end

    @testset "A case migrated from the test inputs loads with the same settings" begin
        mktempdir() do dir
            cp(joinpath(@__DIR__, "test_inputs"), joinpath(dir, "case"))
            case_dir = joinpath(dir, "case")
            system = JSON3.read(read(joinpath(case_dir, "system_data.json"), String), Dict{String,Any})
            system["settings"] = Dict("path" => "settings/macro_settings.json")
            MacroEnergy.write_json(joinpath(case_dir, "system_data.json"),
                Dict("settings" => Dict("path" => "settings/case_settings.json"), "case" => [system, system]))
            write_case(case_dir, ["settings/case_settings.json" => OLD_CASE_SETTINGS, "settings/macro_settings.json" => OLD_SYSTEM_SETTINGS])
            # Only the settings warnings: under Pkg.test (--depwarn=yes), Julia's own deprecation
            # warnings are logged too
            deprecations(logger) = count(record -> occursin(r"given per period|translated automatically",
                string(record.message)), logger.logs)

            before_logs = Test.TestLogger(min_level=Logging.Warn)
            before = with_logger(() -> load_case(case_dir), before_logs)
            migrate_settings(case_dir; dry_run=false)
            after_logs = Test.TestLogger(min_level=Logging.Warn)
            after = with_logger(() -> load_case(case_dir), after_logs)
            @test deprecations(before_logs) == 2
            @test deprecations(after_logs) == 0
            @test same_settings(after.settings, before.settings)
            @test all(system -> system.settings === after.settings, after.systems)
        end
    end
end

end # module TestMigrateSettings
