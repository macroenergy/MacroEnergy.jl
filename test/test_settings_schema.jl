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
    map_entry,
    input_spec,
    configure_settings,
    default_settings,
    default_benders_settings,
    default_myopic_settings,
    settings_spec,
    benders_settings_spec,
    myopic_settings_spec,
    DEPRECATED_SETTINGS,
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

    @testset "Reading map entries" begin
        switches = InputMap(:write, (:x, :y), Bool, (;); entry_default=true, key_defaults=(y=false,))
        @test map_entry(switches, (;), :x) === true              # entry_default
        @test map_entry(switches, (;), :y) === false             # key_defaults
        @test map_entry(switches, (y=true,), :y) === true        # the user's entry
        @test map_entry(switches, Dict(:x => false), :x) === false
        formats = InputMap(:format, (:x, :y), String, "csv"; entry_default="csv", allow_scalar=true)
        @test map_entry(formats, "parquet", :x) == "parquet"     # a single value applies to every key
        @test map_entry(formats, (y="parquet",), :x) == "csv"
        @test_throws ArgumentError InputMap(:write, (:x,), Bool, (;); entry_default=true, key_defaults=(z=false,))
    end
end

function test_settings_defaults()
    # Pinned values, so that changing a default is a deliberate decision
    @testset "Settings defaults" begin
        @test isequal(default_settings(), (
            PeriodLengths=[1],
            DiscountRate=0.0,
            StartYear=missing,
            ParameterScaling=false,
            ParameterScalingFactor=1e3,
            SolutionAlgorithm="Monolithic",
            ExpansionHorizon="PerfectForesight",
            BendersSettings=nothing,
            MyopicSettings=nothing,
            ConstraintScaling=false,
            EnableJuMPDirectModel=false,
            EnableJuMPStringNames=false,
            AllowImplicitTopLevelCommodities=true,
            WriteSubcommodities=true,
            AutoCreateNodes=false,
            AutoCreateLocations=true,
            Retrofitting=false,
            OutputSettings=(
                Dir="results",
                Overwrite=false,
                Format="csv",
                Layout="long",
                Write=(;),
                SignificantDigits=nothing,
                AssetTags=true,
            ),
        ))
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
    @testset "General settings" begin
        # The defaults, with the algorithm names turned into types
        @test isequal(configure_settings(NamedTuple()),
            merge(default_settings(), (SolutionAlgorithm=Monolithic(), ExpansionHorizon=PerfectForesight())))
        @test configure_settings((OutputSettings=(Layout=(Flow="wide",),),)).OutputSettings.Layout == (Flow="wide",)
        msg = error_message(() -> configure_settings((ConstraintScalling=true,)))
        @test occursin("case_settings: unknown key(s) ConstraintScalling", msg)
        @test occursin("case_settings.OutputSettings.Layout.Flow",
            error_message(() -> configure_settings((OutputSettings=(Layout=(Flow="tall",),),))))
        @test occursin("case_settings.OutputSettings: unknown key(s) Dirr",
            error_message(() -> configure_settings((OutputSettings=(Dirr="out",),))))
        # Duals is not a layout key
        @test_throws InputValidationError configure_settings((OutputSettings=(Layout=(Duals="wide",),),))
        @test_throws InputValidationError configure_settings((Retrofitting="yes",))
    end

    @testset "Unknown keys and algorithm names" begin
        @test occursin("case_settings.DiscountRate", error_message(() -> configure_settings(Dict{Symbol,Any}(:DiscountRate => -1))))
        @test occursin("case_settings.PeriodLengths", error_message(() -> configure_settings(Dict{Symbol,Any}(:PeriodLengths => [5, 0]))))
        @test occursin("case_settings: unknown key(s) SomethingElse", error_message(() -> configure_settings(Dict{Symbol,Any}(:SomethingElse => 1))))
        # Without an algorithm or horizon, the defaults apply
        settings = configure_settings(Dict{Symbol,Any}())
        @test settings.SolutionAlgorithm isa Monolithic
        @test settings.ExpansionHorizon isa PerfectForesight
        # A typo is an error, rather than silently running with the default
        @test occursin("case_settings.SolutionAlgorithm: expected one of",
            error_message(() -> configure_settings(Dict{Symbol,Any}(:SolutionAlgorithm => "Bender"))))
        @test occursin("case_settings.ExpansionHorizon: expected one of",
            error_message(() -> configure_settings(Dict{Symbol,Any}(:ExpansionHorizon => "Myopc"))))
        # The deprecated value is still translated, with a warning
        settings = @test_logs (:warn, r"deprecated") match_mode = :any configure_settings(Dict{Symbol,Any}(:SolutionAlgorithm => "Myopic"))
        @test settings.SolutionAlgorithm isa Monolithic
        @test settings.ExpansionHorizon isa Myopic
    end

    @testset "Benders and Myopic settings" begin
        benders = configure_settings(Dict{Symbol,Any}(:SolutionAlgorithm => "Benders",
            :BendersSettings => Dict{Symbol,Any}(:MaxIter => 10)))
        @test benders.SolutionAlgorithm isa Benders
        @test benders.BendersSettings[:MaxIter] == 10
        @test benders.BendersSettings[:ConvTol] == 1e-3
        @test occursin("case_settings.BendersSettings.MaxIter", error_message(() -> configure_settings(Dict{Symbol,Any}(
            :SolutionAlgorithm => "Benders", :BendersSettings => Dict{Symbol,Any}(:MaxIter => 2.5)))))
        @test occursin("case_settings.BendersSettings: unknown key(s) MaxIters", error_message(() -> configure_settings(Dict{Symbol,Any}(
            :SolutionAlgorithm => "Benders", :BendersSettings => Dict{Symbol,Any}(:MaxIters => 10)))))
        # BendersSettings is not validated when Benders is not used
        @test configure_settings(Dict{Symbol,Any}(:BendersSettings => Dict{Symbol,Any}(:MaxIter => 0))).BendersSettings[:MaxIter] == 0

        # A partial Restart block is completed from the defaults
        myopic = configure_settings(Dict{Symbol,Any}(:ExpansionHorizon => "Myopic",
            :MyopicSettings => Dict{Symbol,Any}(:Restart => Dict{Symbol,Any}(:enabled => true))))
        @test myopic.MyopicSettings[:Restart] == (enabled=true, folder="results_001", from_period=1)
        msg = error_message(() -> configure_settings(Dict{Symbol,Any}(:ExpansionHorizon => "Myopic",
            :MyopicSettings => Dict{Symbol,Any}(:StopAfterPeriod => 2,
                :Restart => Dict{Symbol,Any}(:enabled => true, :from_period => 3)))))
        @test occursin("case_settings.MyopicSettings: Restart.from_period (3) must not be after StopAfterPeriod (2)", msg)
        @test occursin("case_settings.MyopicSettings.StopAfterPeriod", error_message(() -> configure_settings(Dict{Symbol,Any}(
            :ExpansionHorizon => "Myopic", :MyopicSettings => Dict{Symbol,Any}(:StopAfterPeriod => 0)))))
        @test occursin("case_settings.MyopicSettings.Restart: unknown key(s) from", error_message(() -> configure_settings(Dict{Symbol,Any}(
            :ExpansionHorizon => "Myopic", :MyopicSettings => Dict{Symbol,Any}(:Restart => Dict{Symbol,Any}(:from => 2))))))
    end
end

# Every block of `block`, including nested ones (e.g. MyopicSettings.Restart)
nested_blocks(block::InputBlock) =
    InputBlock[block; [b for f in block.fields for b in (f isa InputBlock ? nested_blocks(f) : InputBlock[])]]

# Generic checks that apply to every key of every settings spec, so a new setting is covered
# as soon as it is declared. They do not check that a key's rules are the right ones.
function test_every_setting()
    specs = [settings_spec(), benders_settings_spec(), myopic_settings_spec()]
    @testset "Every setting in every spec" begin
        for spec in specs, block in nested_blocks(spec)
            @testset "$(block.name)" begin
                # Defaults satisfy their own rules
                @test isnothing(validate_inputs(block, input_defaults(block)))
                for map in filter(f -> f isa InputMap, block.fields)
                    @test isnothing(validate_value(map.entry, map.entry.default, "$(block.name).$(map.name)"))
                    for value in values(map.key_defaults)
                        @test isnothing(validate_value(map.entry, value, "$(block.name).$(map.name)"))
                    end
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

# Whether a key path leads to a key declared in `spec`
declares(spec::InputBlock, path) = (sub = input_spec(spec, first(path));
    !isnothing(sub) && (length(path) == 1 || declares(sub, path[2:end])))
declares(spec::InputMap, path) = length(path) == 1 && first(path) in spec.keys
declares(::InputField, path) = false

function test_deprecated_settings_table()
    @testset "Deprecated settings" begin
        spec = settings_spec()
        for (old, path) in pairs(DEPRECATED_SETTINGS)
            @test declares(spec, path)
            # A key cannot be both deprecated and current
            @test !(old in input_keys(spec))
        end
    end
end

test_input_spec_engine()
test_settings_defaults()
test_settings_validation()
test_every_setting()
test_deprecated_settings_table()

end # module TestSettingsSchema
