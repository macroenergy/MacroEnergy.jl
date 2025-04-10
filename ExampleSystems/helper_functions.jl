# Function for saving results
function save_results(results_dir, case, system)
    ## System results
    system_results_df = get_system_results(system)
    MacroEnergy.write_csv(joinpath(results_dir, case * "_system_results.csv"), system_results_df)

    ## Capacity results
    capacity_df = MacroEnergy.get_optimal_capacity(system)
    MacroEnergy.write_csv(joinpath(results_dir, case * "_capacity.csv"), capacity_df)

    ## Flow results
    flows_df = MacroEnergy.get_optimal_flow(system)  
    MacroEnergy.write_csv(joinpath(results_dir, case * "_flows.csv"), flows_df)
end

# Get system-wide results (objective value, co2 emissions, co2 captured)
function get_system_results(system)
    system_results_df = DataFrame(
        objective_value = MacroEnergy.objective_value(model),
    )
    nodes = Node[x for x in system.locations if x isa MacroEnergy.Node] # Get all nodes (and not locations) in system.locations
    co2_nodes = MacroEnergy.get_nodes_sametype(nodes, CO2) # List of CO2 nodes
    co2_captured_nodes = MacroEnergy.get_nodes_sametype(nodes, CO2Captured) # List of CO2Captured nodes
    system_results_df = get_co2_node_values(system_results_df, co2_nodes) # Push values of CO2 nodes to dataframe
    system_results_df = get_co2_node_values(system_results_df, co2_captured_nodes) # Push values of CO2Captured nodes to dataframe
    return system_results_df
end

# Get values from CO2 and CO2Captured nodes
function get_co2_node_values(df, co2_nodes)
    for co2_node in co2_nodes
        if haskey(co2_node.operation_expr, :emissions)
            df[!, co2_node.id] = [MacroEnergy.value(sum(co2_node.operation_expr[:emissions]))]
        elseif haskey(co2_node.operation_expr, :exogenous)
            df[!, co2_node.id] = [MacroEnergy.value(sum(co2_node.operation_expr[:exogenous]))]
        else
            println("There is are no values for CO2 emissions in this node")
        end
    end
    return df
end

# # Get system-wide results if no CO2 cap (objective value, co2 emissions, co2 captured)
# function get_system_results_no_co2_cap(system)
#     co2_node = MacroEnergy.get_nodes_sametype(system.locations, CO2)[1] # There is only 1 CO2 node
#     system_results_df = DataFrame(
#         objective_value = MacroEnergy.objective_value(model),
#         co2_emissions = MacroEnergy.value(sum(co2_node.operation_expr[:exogenous])),
#     )
#     return system_results_df
# end

# # Get system flows
# function get_system_flows(system)
#     results_8760_df = DataFrame()
#     # Get flows of each asset
#     for i in eachindex(system.assets)
#         get_flows(system.assets[i], results_8760_df)
#     end

#     # Function to get sorting key: returns the index of the first matching suffix or a large number
#     suffixes = ["cement", "co2"] # Define suffixes to reorder dataframe by
#     function suffix_sort_key(name)
#         idx = findfirst(s -> endswith(name, s), suffixes)
#         return isnothing(idx) ? length(suffixes) + 1 : idx  # Default to placing non-matching names at the end
#     end

#     # Resort column order based on suffix
#     sorted_cols = sort(names(results_8760_df), by=suffix_sort_key) # Sort column names based on suffix priority
#     results_8760_df = results_8760_df[:, sorted_cols] # Reorder column names

#     return results_8760_df
# end

# # Function to get sorting key: returns the index of the first matching suffix or a large number
# function suffix_sort_key(name)
#     idx = findfirst(s -> endswith(name, s), suffixes)
#     return isnothing(idx) ? length(suffixes) + 1 : idx  # Default to placing non-matching names at the end
# end

# # Function to get flows for each type of asset
# function get_flows(asset::MacroEnergy.CementPlant, df::DataFrame)
#     df[:, "trad_" * string(asset.id) * "_cement"] = MacroEnergy.value.(MacroEnergy.flow(asset.cement_edge)).data
#     df[:, "trad_" * string(asset.id) * "_co2"] = MacroEnergy.value.(MacroEnergy.flow(asset.co2_edge)).data
# end

# function get_flows(asset::MacroEnergy.ElectrochemCementPlant, df::DataFrame)
#     df[:, "echem_" * string(asset.id) * "_cement"] = MacroEnergy.value.(MacroEnergy.flow(asset.cement_edge)).data
# end

# function get_flows(asset::ElectricDAC, df::DataFrame)
#     df[:, string(asset.id) * "_co2"] = MacroEnergy.value.(MacroEnergy.flow(asset.co2_edge)).data
# end

# function get_flows(asset::PowerLine, df::DataFrame)
#     df[:, asset.id] = MacroEnergy.value.(MacroEnergy.flow(asset.elec_edge)).data
# end

# function get_flows(asset::Battery, df::DataFrame)
#     df[:, string(asset.id) * "_charge"] = -1 * MacroEnergy.value.(MacroEnergy.flow(asset.charge_edge)).data
#     df[:, string(asset.id) * "_discharge"] = MacroEnergy.value.(MacroEnergy.flow(asset.discharge_edge)).data
# end

# function get_flows(asset::ThermalPower, df::DataFrame)
#     df[:, asset.id] = MacroEnergy.value.(MacroEnergy.flow(asset.elec_edge)).data
#     df[:, string(asset.id) * "_co2"] = MacroEnergy.value.(MacroEnergy.flow(asset.co2_edge)).data
# end

# function get_flows(asset::VRE, df::DataFrame)
#     df[:, asset.id] = MacroEnergy.value.(MacroEnergy.flow(asset.edge)).data
# end