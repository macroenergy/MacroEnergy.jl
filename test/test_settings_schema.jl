module TestSettingsSchema

using Test
import MacroEnergy:
    InputValidationError,
    InputField,
    InputMap,
    InputBlock,
    input_keys,
    input_name,
    input_defaults,
    merge_defaults,
    validate_inputs,
    validate_value,
    resolve_inputs,
    configure_settings,
    configure_case,
    default_settings,
    default_case_settings,
    default_benders_settings,
    default_myopic_settings,
    system_settings_spec,
    case_settings_spec,
    benders_settings_spec,
    myopic_settings_spec,
    Benders,
    Monolithic,
    Myopic,
    PerfectForesight

# Message of the error thrown by `f`, or `nothing` if it does not throw
function error_message(f)
    try
        f()
    catch e
        return sprint(showerror, e)
    end
    return nothing
end

function test_input_spec_engine()
    inner = InputBlock(:Inner, [
        InputField(:flag, Bool, false),
        InputField(:count, Int, 1; minimum=1),
    ])
    block = InputBlock(:root, [
        InputField(:rate, Real, 0.0; minimum=0),
        InputField(:lengths, AbstractVector, [1]; eltype=Real, exclusive_minimum=0),
        InputField(:year, Union{Missing,Integer}, missing),
        InputField(:digits, Union{Nothing,Integer}, nothing; minimum=1),
        InputField(:mode, String, "a"; enum=("a", "b")),
        InputMap(:format, (:x, :y), String, "csv"; entry_default="csv", enum=("csv", "parquet"), allow_scalar=true),
        InputMap(:write, (:x, :y), Bool, (;); entry_default=true),
        inner,
    ]; check=v -> v[:rate] > 0.5 && v[:mode] == "a" ? "rate > 0.5 needs mode b" : nothing)

    @testset "Defaults and keys" begin
        @test input_keys(block) == (:rate, :lengths, :year, :digits, :mode, :format, :write, :Inner)
        d = input_defaults(block)
        @test collect(keys(d)) == collect(input_keys(block))
        @test d[:Inner] == Dict(:flag => false, :count => 1)
        @test ismissing(d[:year])
        # Each call returns fresh copies
        push!(d[:lengths], 2)
        @test input_defaults(block)[:lengths] == [1]
    end

    @testset "Merging" begin
        merged = merge_defaults(block, Dict{Symbol,Any}(:Inner => Dict{Symbol,Any}(:flag => true), :format => (x="parquet",)))
        @test merged[:Inner] == Dict(:flag => true, :count => 1)  # nested blocks are filled in
        @test merged[:format] == (x="parquet",)                 # maps are kept as given
        @test merged[:rate] == 0.0
        @test resolve_inputs(block, (rate=0.2,))[:rate] == 0.2  # NamedTuple input
    end

    @testset "Valid values" begin
        valid(values) = isnothing(validate_inputs(block, merge_defaults(block, values)))
        @test valid(Dict(:lengths => Any[5, 10.5]))
        @test valid(Dict(:year    => 2030))
        @test valid(Dict(:digits  => 3))
        @test valid(Dict(:format  => "parquet"))
        @test valid(Dict(:format  => Dict(:y => "parquet")))
        @test valid(Dict(:write   => (x=false,)))
        @test valid(Dict(:rate    => 0.7, :mode => "b"))
    end

    @testset "Invalid values name the key path" begin
        invalid(values) = error_message(() -> resolve_inputs(block, values))
        @test occursin("root.rate: expected a number ≥ 0, got -1", invalid((rate=-1,)))
        @test occursin("root.lengths: expected a list of numbers > 0", invalid((lengths=[1, 0],)))
        @test occursin("root.lengths", invalid((lengths=5,)))
        @test occursin("root.year: expected an integer", invalid((year="2030",)))
        @test occursin("root.digits: expected null or an integer ≥ 1, got 2.5", invalid((digits=2.5,)))
        @test occursin("root.mode: expected one of \"a\", \"b\"", invalid((mode="c",)))
        @test occursin("root.format.x: expected one of", invalid((format=(x="xlsx",),)))
        @test occursin("root.format: unknown key(s) z", invalid((format=(z="csv",),)))
        @test occursin("root.write: expected an object", invalid((write=true,)))
        @test occursin("root.Inner.count: expected an integer ≥ 1, got 0", invalid((Inner=(count=0,),)))
        @test occursin("root: unknown key(s) typo", invalid((typo=1,)))
        @test occursin("root: rate > 0.5 needs mode b", invalid((rate=0.7,)))
        @test_throws InputValidationError resolve_inputs(block, (rate=-1,))
    end

    @testset "Bool is not accepted as a number" begin
        @test_throws InputValidationError resolve_inputs(block, (digits=true,))
        @test_throws InputValidationError resolve_inputs(block, (rate=true,))
        @test_throws InputValidationError resolve_inputs(block, (lengths=[true],))
        @test isnothing(validate_inputs(InputBlock(:b, [InputField(:x, Union{Nothing,Bool}, nothing)]), (x=true,)))
    end

    @testset "Unknown keys can be allowed" begin
        open_block = InputBlock(:open, [InputField(:a, Bool, false)]; additional_properties=true)
        resolved = resolve_inputs(open_block, (b=1,))
        @test resolved[:b] == 1
        @test_throws InputValidationError resolve_inputs(open_block, (a=1,))
    end
end

function test_settings_defaults()
    # Pinned values: the spec must reproduce the defaults Macro had before it was introduced
    @testset "Settings defaults" begin
        @test default_settings() === (
            ConstraintScaling=false,
            EnableJuMPDirectModel=false,
            EnableJuMPStringNames=false,
            AllowImplicitTopLevelCommodities=true,
            WriteSubcommodities=true,
            OverwriteResults=false,
            OutputDir="results",
            OutputLayout="long",
            OutputFormat="csv",
            WriteOutputs=(;),
            OutputSignificantDigits=nothing,
            OutputAssetTags=true,
            AutoCreateNodes=false,
            AutoCreateLocations=true,
            Retrofitting=false,
            DualExportsEnabled=nothing,
        )
        case = default_case_settings()
        @test case isa Dict{Symbol,Any}
        @test sort(collect(keys(case))) == sort([:PeriodLengths, :DiscountRate, :StartYear, :WriteFullTimeseries,
            :ParameterScaling, :ParameterScalingFactor, :SolutionAlgorithm, :ExpansionHorizon])
        @test case[:PeriodLengths] == [1]
        @test case[:DiscountRate] === 0.0
        @test ismissing(case[:StartYear])
        @test case[:WriteFullTimeseries] === false
        @test case[:ParameterScaling] === false
        @test case[:ParameterScalingFactor] === 1e3
        @test case[:SolutionAlgorithm] == "Monolithic"
        @test case[:ExpansionHorizon] == "PerfectForesight"
        @test default_benders_settings() == Dict(
            :MaxIter => 50, :MaxCpuTime => 7200, :ConvTol => 1e-3, :StabParam => 0.0, :StabDynamic => false,
            :IntegerInvestment => false, :Distributed => false, :ExpectFeasibleSubproblems => false,
            :IncludeSubproblemSlacksAutomatically => false)
        myopic = default_myopic_settings()
        @test myopic isa Dict{Symbol,Any}
        @test myopic == Dict(
            :ReturnModels => false, :WriteModelLP => false, :StopAfterPeriod => Inf,
            :Restart => Dict(:enabled => false, :folder => "results_001", :from_period => 1))
    end
end

function test_settings_validation()
    @testset "System settings" begin
        @test configure_settings(NamedTuple()) == merge(default_settings(), (DualExportsEnabled=true,))
        @test configure_settings((OutputLayout=(Flow="wide",),)).OutputLayout == (Flow="wide",)
        msg = error_message(() -> configure_settings((ConstraintScalling=true,)))
        @test occursin("macro_settings: unknown key(s) ConstraintScalling", msg)
        @test occursin("macro_settings.OutputLayout.Flow", error_message(() -> configure_settings((OutputLayout=(Flow="tall",),))))
        # Duals is not a layout key
        @test_throws InputValidationError configure_settings((OutputLayout=(Duals="wide",),))
        @test_throws InputValidationError configure_settings((Retrofitting="yes",))
    end

    @testset "Case settings" begin
        @test occursin("case_settings.DiscountRate", error_message(() -> configure_case(Dict{Symbol,Any}(:DiscountRate => -1))))
        @test occursin("case_settings.PeriodLengths", error_message(() -> configure_case(Dict{Symbol,Any}(:PeriodLengths => [5, 0]))))
        # Unknown keys are still accepted in case settings
        @test configure_case(Dict{Symbol,Any}(:SomethingElse => 1)).SomethingElse == 1
        # Legacy values are still translated, with a warning
        settings = @test_logs (:warn, r"deprecated") match_mode = :any configure_case(Dict{Symbol,Any}(:SolutionAlgorithm => "Myopic"))
        @test settings.SolutionAlgorithm isa Monolithic
        @test settings.ExpansionHorizon isa Myopic
        settings = @test_logs (:warn, r"defaulting to Monolithic") match_mode = :any configure_case(Dict{Symbol,Any}(:SolutionAlgorithm => "Bender"))
        @test settings.SolutionAlgorithm isa Monolithic
        settings = @test_logs (:warn, r"defaulting to PerfectForesight") match_mode = :any configure_case(Dict{Symbol,Any}(:ExpansionHorizon => "Myopc"))
        @test settings.ExpansionHorizon isa PerfectForesight
    end

    @testset "Benders and Myopic settings" begin
        benders = configure_case(Dict{Symbol,Any}(:SolutionAlgorithm => "Benders",
            :BendersSettings => Dict{Symbol,Any}(:MaxIter => 10)))
        @test benders.SolutionAlgorithm isa Benders
        @test benders.BendersSettings[:MaxIter] == 10
        @test benders.BendersSettings[:ConvTol] == 1e-3
        @test occursin("case_settings.BendersSettings.MaxIter", error_message(() -> configure_case(Dict{Symbol,Any}(
            :SolutionAlgorithm => "Benders", :BendersSettings => Dict{Symbol,Any}(:MaxIter => 2.5)))))
        # BendersSettings is not validated when Benders is not used
        @test configure_case(Dict{Symbol,Any}(:BendersSettings => Dict{Symbol,Any}(:MaxIter => 0))).BendersSettings[:MaxIter] == 0

        # A partial Restart block is completed from the defaults
        myopic = configure_case(Dict{Symbol,Any}(:ExpansionHorizon => "Myopic",
            :MyopicSettings => Dict{Symbol,Any}(:Restart => Dict{Symbol,Any}(:enabled => true))))
        @test myopic.MyopicSettings[:Restart] == (enabled=true, folder="results_001", from_period=1)
        msg = error_message(() -> configure_case(Dict{Symbol,Any}(:ExpansionHorizon => "Myopic",
            :MyopicSettings => Dict{Symbol,Any}(:StopAfterPeriod => 2,
                :Restart => Dict{Symbol,Any}(:enabled => true, :from_period => 3)))))
        @test occursin("case_settings.MyopicSettings: Restart.from_period (3) must not be after StopAfterPeriod (2)", msg)
        @test occursin("case_settings.MyopicSettings.StopAfterPeriod", error_message(() -> configure_case(Dict{Symbol,Any}(
            :ExpansionHorizon => "Myopic", :MyopicSettings => Dict{Symbol,Any}(:StopAfterPeriod => 0)))))
    end
end

# Every block of `block`, including nested ones (e.g. MyopicSettings.Restart)
nested_blocks(block::InputBlock) =
    InputBlock[block; [b for f in block.fields for b in (f isa InputBlock ? nested_blocks(f) : InputBlock[])]]

# Generic checks that apply to every key of every settings spec, so a new setting is covered
# as soon as it is declared. They do not check that a key's rules are the right ones.
function test_every_setting()
    specs = [system_settings_spec(), case_settings_spec(), benders_settings_spec(), myopic_settings_spec()]
    @testset "Every setting in every spec" begin
        for spec in specs, block in nested_blocks(spec)
            @testset "$(block.name)" begin
                # Defaults satisfy their own rules
                @test isnothing(validate_inputs(block, input_defaults(block)))
                for map in filter(f -> f isa InputMap, block.fields)
                    @test isnothing(validate_value(map.entry, map.entry.default, "$(block.name).$(map.name)"))
                end
                # Every key is documented
                @test isempty([input_name(f) for f in block.fields if isempty(f.description)])
                # Every key rejects a value no rule accepts, and the error names the key's path
                for key in input_keys(block)
                    msg = error_message(() -> resolve_inputs(block, Dict{Symbol,Any}(key => :not_a_valid_value)))
                    @test occursin("$(block.name).$key: expected", something(msg, ""))
                end
            end
        end
    end
end

test_input_spec_engine()
test_settings_defaults()
test_settings_validation()
test_every_setting()

end # module TestSettingsSchema
