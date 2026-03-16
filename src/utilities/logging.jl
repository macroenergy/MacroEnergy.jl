const date_format = "yyyy-mm-dd HH:MM:SS"

timestamp() = Dates.format(now(), date_format)

# Custom transformer that adds timestamp
timestamp_logger(logger) = TransformerLogger(logger) do log
    merge(log, (; message = "$(timestamp()) $(log.message)"))
end

function concise_logger(log_file_path, log_level::LogLevel=Logging.Info)
    return MinLevelLogger(
        FormatLogger(log_file_path ; append = false) do io, args
            println(io, "$(timestamp()) | ", args.message)
        end,
        log_level
    )
end

function attributed_logger(log_file_path, log_level::LogLevel=Logging.Info)
    return MinLevelLogger(
        FormatLogger(log_file_path ; append = false) do io, args
            # Extract attribution info
            level_str = uppercase(string(args.level))
            module_str = string(args._module)
            file_info = args.file !== nothing ? "$(basename(string(args.file))):$(args.line)" : ""
            
            # Format: timestamp | LEVEL | Worker | Module | file:line | message
            if !isempty(file_info)
                println(io, "$(timestamp()) | $level_str | $(myid()) | $module_str | $file_info | $(args.message)")
            else
                println(io, "$(timestamp()) | $level_str | $(myid()) | $module_str | $(args.message)")
            end
        end,
        log_level
    )
end

function verbose_logger(log_file_path, log_level::LogLevel=Logging.Info)
    return MinLevelLogger(
        FileLogger(
            log_file_path;
            append = false,
            always_flush = true, 
        ),
        log_level
    ) |> timestamp_logger
end

function console_logger(log_level::LogLevel=Logging.Info)
    return MinLevelLogger(
        ConsoleLogger(
            stdout
        ),
        log_level
    ) |> timestamp_logger
end

function set_logger(log_to_console::Bool, log_to_file::Bool, log_level::LogLevel, log_file_path::AbstractString, log_file_attribution::Bool=false)
    if !(log_to_console || log_to_file)
        return nothing
    end

    loggers = []
    if log_to_console
        push!(loggers, console_logger(log_level))
    end
    if log_to_file
        if log_file_attribution
            file_logger = attributed_logger(log_file_path, log_level)
        else
            file_logger = concise_logger(log_file_path, log_level)
        end
        push!(loggers, file_logger)
    end
    if length(loggers) == 1
        global_logger(loggers[1])
    else
        global_logger(TeeLogger(loggers...))
    end
    return nothing
end