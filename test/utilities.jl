using Gurobi, Logging


macro warn_error_logger(block)
    quote
        result = redirect_stdout(devnull) do
            # Create a ConsoleLogger that prints any log messages with level >= Warn to stderr
            warnerror_logger = ConsoleLogger(stderr, Logging.Warn)
            with_logger(warnerror_logger) do
                result = $(esc(block))
            end
        end
        result
    end
end

function is_gurobi_available()
    try
        @warn_error_logger Gurobi.Env()
        return true
    catch e
        if isa(e, Gurobi.GurobiError)
            return false
        else
            rethrow()
        end
    end
end

function check_if_package_installed(optimizer_name::AbstractString)
    return Base.find_package(optimizer_name) !== nothing
end
