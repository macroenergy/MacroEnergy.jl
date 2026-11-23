using Logging


# Test suite selection. "short" (the default) skips the tests that solve full
# cases; "long" runs everything. Select the suite with either:
#   julia> Pkg.test("MacroEnergy"; test_args=["long"])
#   $ MACRO_TEST_SUITE=long julia --project=. test/runtests.jl
function macro_test_suite()
    for arg in ARGS
        suite = lowercase(lstrip(arg, '-'))
        suite in ("short", "long") && return suite
    end
    return lowercase(get(ENV, "MACRO_TEST_SUITE", "short"))
end

const TEST_SUITE = macro_test_suite()

run_long_tests() = TEST_SUITE == "long"

# A copy of a System built by hand, with other settings: the settings of a System cannot be
# changed once they are set. The copy shares everything else with the original.
# (`typeof(system)` is MacroEnergy.System: some test modules import names from MacroEnergy only.)
with_settings(system, settings::NamedTuple) = typeof(system)(system.data_dirpath, settings,
    system.commodities, system.time_data, system.assets, system.locations, system.input_data, system.constraints)

macro log_with_level(log_level, block)
    quote
        result = redirect_stdout(devnull) do
            # Create a ConsoleLogger that prints any log messages with the specified log level to stderr
            logger = ConsoleLogger(stderr, $(esc(log_level)))
            with_logger(logger) do
                result = $(esc(block))
            end
        end
        result
    end
end

# Backward compatibility for previous version
macro warn_error_logger(block)
    quote
        @log_with_level($(esc(Logging.Warn)), $(esc(block)))
    end
end

macro error_logger(block)
    quote
        @log_with_level($(esc(Logging.Error)), $(esc(block)))
    end
end

function is_gurobi_available()
    Base.find_package("Gurobi") === nothing && return false

    try
        @eval using Gurobi
        return !isnothing(Base.get_extension(MacroEnergy, :MacroEnergyGurobiExt))
    catch e
        @warn "Gurobi is available but could not be loaded; using HiGHS for tests" exception =
            (e, catch_backtrace())
        return false
    end
end

function check_if_package_installed(optimizer_name::AbstractString)
    return Base.find_package(optimizer_name) !== nothing
end
