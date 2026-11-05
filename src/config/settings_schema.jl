###### ###### ###### ###### ###### ###### ###### ###### ###### ###### ###### ###### ######
# Specs of Macro's settings files
#
# `settings_spec()` is the single source for the keys, defaults and rules of `case_settings.json`,
# and the other specs for its nested blocks. The `default_*settings()` functions are derived
# from them. The engine
# (`InputField`, `InputMap`, `InputBlock`, `resolve_inputs`, …) is in
# `src/load_inputs/input_schema/input_spec.jl`.
###### ###### ###### ###### ###### ###### ###### ###### ###### ###### ###### ###### ###### 

# File formats supported by `OutputSettings.Format`, used as the output file extension
const OUTPUT_FORMATS = ("csv", "csv.gz", "parquet")
# Output types that can be keyed in `OutputSettings.Format`
const OUTPUT_KEYS = (:Capacity, :CapacitySummary, :Capex, :Costs, :Curtailment, :Duals, :Flow, :NonServedDemand, :StorageLevel, :TimeWeights)
# Outputs that can be switched on or off in `OutputSettings.Write`
const OUTPUT_WRITE_KEYS = (OUTPUT_KEYS..., :FullTimeseries)
# Output types that can be keyed in `OutputSettings.Layout`
const OUTPUT_LAYOUT_KEYS = (:Capacity, :CapacitySummary, :Costs, :Curtailment, :Flow, :NonServedDemand, :StorageLevel)
const OUTPUT_LAYOUTS = ("long", "wide")

# `case_settings.json` holds all the settings of a case, which apply to every period
const CASE_SETTINGS_FILENAME = "case_settings.json"
# Before all settings moved to `case_settings.json`, each period pointed to its own file
const LEGACY_SYSTEM_SETTINGS_FILENAME = "macro_settings.json"

function output_settings_spec()::InputBlock
    return InputBlock(:OutputSettings, [
        InputField(:Dir, String, "results";
            description="Directory where the results are saved."),
        InputField(:Overwrite, Bool, false;
            description="Overwrite the results directory if it already exists."),
        InputMap(:Format, OUTPUT_KEYS, String, "csv";
            entry_default="csv", enum=OUTPUT_FORMATS, allow_scalar=true,
            description="File format of output tables, for all outputs or per output (e.g., `{\"Flow\": \"parquet\"}`)."),
        InputMap(:Layout, OUTPUT_LAYOUT_KEYS, String, "long";
            entry_default="long", enum=OUTPUT_LAYOUTS, allow_scalar=true,
            description="Layout of output tables, for all outputs or per output."),
        InputMap(:Write, OUTPUT_WRITE_KEYS, Bool, (;);
            entry_default=true, key_defaults=(FullTimeseries=false,),
            description="Outputs to write or skip, e.g., `{\"Curtailment\": false}`. Outputs that are not listed are written, except `FullTimeseries`."),
        InputField(:SignificantDigits, Union{Nothing,Integer}, nothing; minimum=1,
            description="If set, round time-series outputs to this many significant digits before writing."),
        InputField(:AssetTags, Bool, true;
            description="Include a `tags` column in `capacity.csv`, `capacity_summary.csv` and `capex.csv`."),
    ]; description="Which results to write, where, and in which format.")
end

function settings_spec()::InputBlock
    return InputBlock(:case_settings, [
        InputField(:PeriodLengths, AbstractVector, [1]; eltype=Integer, exclusive_minimum=0,
            description="Length of each period, in whole years. Its length sets the number of periods."),
        InputField(:DiscountRate, Real, 0.0; minimum=0,
            description="Discount rate used to discount costs across periods."),
        InputField(:StartYear, Union{Missing,Integer}, missing;
            description="Calendar year of the first period, used to label periods by year."),
        InputField(:ParameterScaling, Bool, false;
            description="Divide extensive inputs (costs, quantities) by `ParameterScalingFactor` before building the model."),
        InputField(:ParameterScalingFactor, Real, 1e3; minimum=0,
            description="Scale factor used when `ParameterScaling` is true."),
        InputField(:SolutionAlgorithm, String, "Monolithic"; enum=("Monolithic", "Benders", "Myopic"),
            description="Solution algorithm. `\"Myopic\"` is deprecated: use `ExpansionHorizon` instead."),
        InputField(:ExpansionHorizon, String, "PerfectForesight"; enum=("PerfectForesight", "Myopic"),
            description="Optimize all periods jointly (`\"PerfectForesight\"`) or one at a time (`\"Myopic\"`)."),
        # Validated by their own specs, and only when Benders or Myopic is used
        InputField(:BendersSettings, Union{Nothing,AbstractDict}, nothing;
            description="Settings of the Benders algorithm, used when `SolutionAlgorithm` is `\"Benders\"`."),
        InputField(:MyopicSettings, Union{Nothing,AbstractDict}, nothing;
            description="Settings of the myopic iterations, used when `ExpansionHorizon` is `\"Myopic\"`."),
        InputField(:ConstraintScaling, Bool, false;
            description="Scale the optimization model constraints to make it more numerically stable."),
        InputField(:EnableJuMPDirectModel, Bool, false;
            description="Generate a JuMP direct model. Ignored when Benders decomposition is used."),
        InputField(:EnableJuMPStringNames, Bool, false;
            description="Attach a string name to each JuMP variable. Ignored when Benders decomposition is used."),
        InputField(:AllowImplicitTopLevelCommodities, Bool, true;
            description="Treat unknown plain commodity names in `commodities.json` as new top-level commodities instead of raising an error."),
        InputField(:WriteSubcommodities, Bool, true;
            description="Write the subcommodities created by the user to file."),
        InputField(:AutoCreateNodes, Bool, false;
            description="Create a Node automatically when one of a given Commodity is requested at a Location and does not exist."),
        InputField(:AutoCreateLocations, Bool, true;
            description="Create a Location automatically when a Node is assigned to a Location that does not exist."),
        InputField(:Retrofitting, Bool, false;
            description="Consider retrofit investments."),
        output_settings_spec(),
    ])
end

# Settings keys that were renamed, and the key path that replaces each. They are translated
# in this order, so `WriteOutputs` becomes `OutputSettings.Write` before its entries are added.
const DEPRECATED_SETTINGS = (
    OutputDir = (:OutputSettings, :Dir),
    OverwriteResults = (:OutputSettings, :Overwrite),
    OutputFormat = (:OutputSettings, :Format),
    OutputLayout = (:OutputSettings, :Layout),
    WriteOutputs = (:OutputSettings, :Write),
    OutputSignificantDigits = (:OutputSettings, :SignificantDigits),
    OutputAssetTags = (:OutputSettings, :AssetTags),
    WriteFullTimeseries = (:OutputSettings, :Write, :FullTimeseries),
    DualExportsEnabled = (:OutputSettings, :Write, :Duals),
)

function benders_settings_spec()::InputBlock
    return InputBlock(:BendersSettings, [
        InputField(:MaxIter, Int, 50; exclusive_minimum=0, description="Maximum number of Benders iterations."),
        InputField(:MaxCpuTime, Int, 7200; exclusive_minimum=0, description="Maximum CPU time, in seconds."),
        InputField(:ConvTol, Real, 1e-3; exclusive_minimum=0,
            description="Convergence tolerance (relative gap between upper and lower bound)."),
        InputField(:StabParam, Real, 0.0; minimum=0, description="Stabilization parameter (set > 0 to enable stabilization)."),
        InputField(:StabDynamic, Bool, false; description="Enable dynamic stabilization."),
        InputField(:IntegerInvestment, Bool, false; description="Use integer investment decisions in the planning problem."),
        InputField(:Distributed, Bool, false; description="Solve subproblems in parallel on distributed workers."),
        InputField(:ExpectFeasibleSubproblems, Bool, false;
            description="Skip feasibility cuts (use only if subproblems are always feasible)."),
        InputField(:IncludeSubproblemSlacksAutomatically, Bool, false;
            description="Automatically add slack variables to subproblems."),
    ])
end

function myopic_settings_spec()::InputBlock
    restart = InputBlock(:Restart, [
        InputField(:enabled, Bool, false; description="Resume a previous run from `from_period`."),
        InputField(:folder, AbstractString, "results_001"; description="Results folder of the run to resume."),
        InputField(:from_period, Int, 1; minimum=1, description="Period to resume from."),
    ]; description="Resume a previous myopic run from a given period.")
    return InputBlock(:MyopicSettings, [
        InputField(:ReturnModels, Bool, false;
            description="Keep the solved model of each period in memory and return it in `MyopicResults`."),
        InputField(:WriteModelLP, Bool, false; description="Write an LP file for each period's model."),
        restart,
        InputField(:StopAfterPeriod, Real, Inf; minimum=1, description="Stop the myopic loop after this period index."),
    ]; check=check_myopic_restart)
end

function check_myopic_restart(settings)::Union{Nothing,String}
    restart = settings[:Restart]
    if restart[:enabled] && restart[:from_period] > settings[:StopAfterPeriod]
        return "Restart.from_period ($(restart[:from_period])) must not be after StopAfterPeriod ($(settings[:StopAfterPeriod]))"
    end
    return nothing
end

default_settings() = namedtuple(input_defaults(settings_spec()))
default_benders_settings() = Dict{Symbol,Any}(input_defaults(benders_settings_spec()))
default_myopic_settings() = Dict{Symbol,Any}(input_defaults(myopic_settings_spec()))
