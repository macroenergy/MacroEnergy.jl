###### ###### ###### ###### ###### ######
# Internal functions to handle loading the system
###### ###### ###### ###### ###### ######

function generate_system!(
    system::System,
    file_path::AbstractString;
    lazy_load::Bool = true,
)::nothing
    # Load the system data file
    @info("Generating system from $file_path")
    system_data = load_system_data(file_path, system.data_dirpath; lazy_load = lazy_load)
    generate_system!(system, system_data)
    return nothing
end

function generate_system!(system::System, system_data::AbstractDict{Symbol,Any})::Nothing
    @info("Generating system")
    start_time = time();
    # Configure the settings
    system.settings = configure_settings(system_data[:settings], system.data_dirpath)

    # Load the commodities
    system.commodities = load_commodities(
        system_data[:commodities],
        system.data_dirpath;
        write_subcommodities=system.settings.WriteSubcommodities,
        allow_implicit_top_level_commodities=system.settings.AllowImplicitTopLevelCommodities,
    )

    # Load the locations
    load_locations!(system, system.data_dirpath, system_data[:locations])

    # Load the time data
    system.time_data =
        load_time_data(system_data[:time_data], system.commodities, system.data_dirpath)

    # Load the nodes
    load!(system, system_data[:nodes])

    # Load the assets
    load!(system, system_data[:assets])
    @info("Done generating system. It took $(round(time() - start_time, digits=2)) seconds")
    return nothing
end

function generate_system!(
    periods::Vector{System},
    file_path::AbstractString;
    lazy_load::Bool = true,
)::Nothing
    # Load the system data file
    @info("Generating system from $file_path")
    system_data = load_system_data(file_path, system.data_dirpath; lazy_load = lazy_load)
    generate_system!(periods, system_data)
    return nothing
end