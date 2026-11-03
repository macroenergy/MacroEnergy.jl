###### ###### ###### ###### ###### ###### ###### ###### ###### ###### ###### ###### ######
# Specs of Macro's settings files
#
# Each spec below is the single source for the keys, defaults and rules of one settings
# file (or block). The `default_*settings()` functions are derived from them. The engine
# (`InputField`, `InputMap`, `InputBlock`, `resolve_inputs`, …) is in
# `src/load_inputs/input_schema/input_spec.jl`.
###### ###### ###### ###### ###### ###### ###### ###### ###### ###### ###### ###### ###### 

# File formats supported by `OutputFormat`, used as the output file extension
const OUTPUT_FORMATS = ("csv", "csv.gz", "parquet")
# Output types that can be keyed in `OutputFormat` and `WriteOutputs`
const OUTPUT_KEYS = (:Capacity, :CapacitySummary, :Capex, :Costs, :Curtailment, :Duals, :Flow, :NonServedDemand, :StorageLevel, :TimeWeights)
# Output types that can be keyed in `OutputLayout`
const OUTPUT_LAYOUT_KEYS = (:Capacity, :CapacitySummary, :Costs, :Curtailment, :Flow, :NonServedDemand, :StorageLevel)
const OUTPUT_LAYOUTS = ("long", "wide")

function system_settings_spec()::InputBlock
    return InputBlock(:macro_settings, [
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
        InputField(:OverwriteResults, Bool, false;
            description="Overwrite the results directory if it already exists."),
        InputField(:OutputDir, String, "results";
            description="Directory where the results are saved."),
        InputMap(:OutputLayout, OUTPUT_LAYOUT_KEYS, String, "long";
            entry_default="long", enum=OUTPUT_LAYOUTS, allow_scalar=true,
            description="Layout of output tables, for all outputs or per output."),
        InputMap(:OutputFormat, OUTPUT_KEYS, String, "csv";
            entry_default="csv", enum=OUTPUT_FORMATS, allow_scalar=true,
            description="File format of output tables, for all outputs or per output (e.g., `{\"Flow\": \"parquet\"}`)."),
        InputMap(:WriteOutputs, OUTPUT_KEYS, Bool, (;);
            entry_default=true,
            description="Output files to skip, e.g., `{\"Curtailment\": false}`. Outputs that are not listed are written."),
        InputField(:OutputSignificantDigits, Union{Nothing,Integer}, nothing; minimum=1,
            description="If set, round time-series outputs to this many significant digits before writing."),
        InputField(:OutputAssetTags, Bool, true;
            description="Include a `tags` column in `capacity.csv`, `capacity_summary.csv` and `capex.csv`."),
        InputField(:AutoCreateNodes, Bool, false;
            description="Create a Node automatically when one of a given Commodity is requested at a Location and does not exist."),
        InputField(:AutoCreateLocations, Bool, true;
            description="Create a Location automatically when a Node is assigned to a Location that does not exist."),
        InputField(:Retrofitting, Bool, false;
            description="Consider retrofit investments."),
        InputField(:DualExportsEnabled, Union{Nothing,Bool}, nothing;
            description="Deprecated: use `WriteOutputs` with `\"Duals\": false` instead."),
    ])
end

# Unknown keys are accepted in case settings, as before the spec was introduced.
# `BendersSettings` and `MyopicSettings` are validated by their own specs, and only when active.
function case_settings_spec()::InputBlock
    return InputBlock(:case_settings, [
        InputField(:PeriodLengths, AbstractVector, [1]; eltype=Real, exclusive_minimum=0,
            description="Length of each period, in years. Its length sets the number of periods."),
        InputField(:DiscountRate, Real, 0.0; minimum=0,
            description="Discount rate used to discount costs across periods."),
        InputField(:StartYear, Union{Missing,Integer}, missing;
            description="Calendar year of the first period, used to label periods by year."),
        InputField(:WriteFullTimeseries, Bool, false;
            description="With time-domain reduction, also write time-series outputs covering every modeled hour."),
        InputField(:ParameterScaling, Bool, false;
            description="Divide extensive inputs (costs, quantities) by `ParameterScalingFactor` before building the model."),
        InputField(:ParameterScalingFactor, Real, 1e3; minimum=0,
            description="Scale factor used when `ParameterScaling` is true."),
        InputField(:SolutionAlgorithm, String, "Monolithic"; enum=("Monolithic", "Benders", "Myopic"),
            description="Solution algorithm. `\"Myopic\"` is deprecated: use `ExpansionHorizon` instead."),
        InputField(:ExpansionHorizon, String, "PerfectForesight"; enum=("PerfectForesight", "Myopic"),
            description="Optimize all periods jointly (`\"PerfectForesight\"`) or one at a time (`\"Myopic\"`)."),
    ]; additional_properties=true)
end

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
    ]; additional_properties=true)
end

function myopic_settings_spec()::InputBlock
    restart = InputBlock(:Restart, [
        InputField(:enabled, Bool, false; description="Resume a previous run from `from_period`."),
        InputField(:folder, AbstractString, "results_001"; description="Results folder of the run to resume."),
        InputField(:from_period, Int, 1; minimum=1, description="Period to resume from."),
    ]; additional_properties=true, description="Resume a previous myopic run from a given period.")
    return InputBlock(:MyopicSettings, [
        InputField(:ReturnModels, Bool, false;
            description="Keep the solved model of each period in memory and return it in `MyopicResults`."),
        InputField(:WriteModelLP, Bool, false; description="Write an LP file for each period's model."),
        restart,
        InputField(:StopAfterPeriod, Real, Inf; minimum=1, description="Stop the myopic loop after this period index."),
    ]; additional_properties=true, check=check_myopic_restart)
end

function check_myopic_restart(settings)::Union{Nothing,String}
    restart = settings[:Restart]
    if restart[:enabled] && restart[:from_period] > settings[:StopAfterPeriod]
        return "Restart.from_period ($(restart[:from_period])) must not be after StopAfterPeriod ($(settings[:StopAfterPeriod]))"
    end
    return nothing
end

default_settings() = namedtuple(input_defaults(system_settings_spec()))
default_case_settings() = Dict{Symbol,Any}(input_defaults(case_settings_spec()))
default_benders_settings() = Dict{Symbol,Any}(input_defaults(benders_settings_spec()))
default_myopic_settings() = Dict{Symbol,Any}(input_defaults(myopic_settings_spec()))
