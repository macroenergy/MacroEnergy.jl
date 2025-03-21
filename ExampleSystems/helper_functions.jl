# Get system-wide results (objective value, co2 emissions, co2 captured)
function get_system_results(system)
    co2_node = MacroEnergy.get_nodes_sametype(system.locations, CO2)[1] # There is only 1 CO2 node
    co2_captured_node = MacroEnergy.get_nodes_sametype(system.locations, CO2Captured)[1]
    system_results_df = DataFrame(
        objective_value = MacroEnergy.objective_value(model),
        co2_emissions = MacroEnergy.value(sum(co2_node.operation_expr[:emissions])),
        co2_captured = MacroEnergy.value(sum(co2_captured_node.operation_expr[:exogenous])),
    )
    return system_results_df
end

# Get system-wide results if no CO2 cap (objective value, co2 emissions, co2 captured)
function get_system_results_no_co2_cap(system)
    co2_node = MacroEnergy.get_nodes_sametype(system.locations, CO2)[1] # There is only 1 CO2 node
    system_results_df = DataFrame(
        objective_value = MacroEnergy.objective_value(model),
        co2_emissions = MacroEnergy.value(sum(co2_node.operation_expr[:exogenous])),
    )
    return system_results_df
end

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