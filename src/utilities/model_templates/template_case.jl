macro default_new_system_name()
    return quote
        "new_system"
    end
end

macro input_formats()
    return quote
        ["json", "csv"]
    end
end

function find_file(filepath, default_filename, make_file::Bool=true)
    if isfile(filepath)
        @debug("Reading existing file from $filepath")
        return filepath
    elseif isfile(joinpath(filepath, default_filename))
        filepath = joinpath(filepath, default_filename)
        @debug("Reading existing file from $filepath")
        return filepath
    elseif make_file
        filepath = joinpath(filepath, default_filename)
        mkpath(dirname(filepath))
        @debug("Creating new file at $filepath")
        return filepath
    else
        @error("Cannot find file at $filepath")
        return ""
    end
end

function template_nodes_file(filepath::AbstractString)
    write_json(filepath, Dict(:nodes => []))
    return nothing
end

function template_locations_file(filepath::AbstractString)
    write_json(filepath, Dict(:locations => []))
    return nothing
end

function template_commodities_file(filepath::AbstractString)
    commodity_names = collect(keys(commodity_types()))
    write_json(filepath, Dict(:commodities => commodity_names))
    return nothing
end

function template_timedata_file(filepath::AbstractString)
    default_time_data = Dict{Symbol,Any}(
        :TotalHoursModeled => 8760,
        :HoursPerSubperiod => 8760,
        :HoursPerTimeStep => 1,
        :NumberOfSubperiods => 1,
    )
    time_data = Dict{Symbol,Any}()
    for (k, v) in default_time_data
        if k in [:HoursPerSubperiod, :HoursPerTimeStep]
            time_data[k] = Dict{Symbol,Any}(c => v for c in collect(keys(commodity_types())))
        else
            time_data[k] = v
        end
    end
    write_json(filepath, time_data)
end

function template_settings_file(filepath::AbstractString)
    # All defaults of case_settings.json, except the optional settings that are not set by default
    settings = filter(entry -> !ismissing(last(entry)) && !isnothing(last(entry)), input_defaults(settings_spec()))
    write_json(filepath, settings)
    return nothing
end

function template_run_file(filepath::AbstractString)
    # Create a run file for the system
    open(filepath, "w") do io
        write(
            io,
            """
            using MacroEnergy
            # using HiGHS

            (case, model) = run_case(@__DIR__);
            # (case, model) = run_case(@__DIR__; optimizer=Gurobi.Optimizer);
            """
        )
    end
    return nothing
end

function template_system(dirpath::AbstractString, system_name::AbstractString=@default_new_system_name)
    if isdir(dirpath)
        system_path = joinpath(dirpath, system_name)
    else
        if system_name == @default_new_system_name
            system_path = dirpath
        else
            system_path = joinpath(dirpath, system_name)
        end
    end
    mkpath(system_path)

    system_data = copy(load_default_system_data())

    write_json(joinpath(system_path, "system_data.json"), system_data)

    mkpath(joinpath(system_path, "system"))
    mkpath(joinpath(system_path, system_data[:assets][:path]))
    template_nodes_file(joinpath(system_path, system_data[:nodes][:path]))
    template_locations_file(joinpath(system_path, system_data[:locations][:path]))
    template_commodities_file(joinpath(system_path, system_data[:commodities][:path]))
    template_timedata_file(joinpath(system_path, system_data[:time_data][:path]))

    settings_path = joinpath(system_path, system_data[:settings][:path])
    mkpath(dirname(settings_path))
    template_settings_file(settings_path)

    template_run_file(joinpath(system_path, "run.jl"))

    system = empty_system(system_path)

    return system
end