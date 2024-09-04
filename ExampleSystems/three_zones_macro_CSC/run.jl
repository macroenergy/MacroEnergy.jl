using Pkg
Pkg.activate(dirname(dirname(@__DIR__)))
using Macro
using Gurobi

case_path = @__DIR__
println("###### ###### ######")
println("Running case at $(case_path)")

system = Macro.load_system(case_path)

model = Macro.generate_model(system)

Macro.set_optimizer(model,Gurobi.Optimizer);
Macro.optimize!(model)
macro_objval = Macro.objective_value(model)

println("The runtime for Macro was $(Macro.solve_time(model))")

capacity_results = Macro.get_optimal_asset_capacity(system);

println("Built technology types are:")
println([typeof(system.assets[i]) for i in keys(capacity_results)])

ng_MA = Macro.get_asset_by_id(system, :ng_MA)
ng_ccs_MA = Macro.get_asset_by_id(system, :ng_ccs_MA)
solar_pv_MA = Macro.get_asset_by_id(system, :solar_pv_MA)
electrolyzer_MA = Macro.get_asset_by_id(system, :electrolyzer_MA)
smr_MA = Macro.get_asset_by_id(system, :smr_MA)
smr_ccs_MA = Macro.get_asset_by_id(system, :smr_ccs_MA)
ng_dac_MA = Macro.get_asset_by_id(system, :ng_dac_MA)
electric_dac_MA = Macro.get_asset_by_id(system, :electric_dac_MA)

ng_CT = Macro.get_asset_by_id(system, :ng_CT)
ng_ccs_CT = Macro.get_asset_by_id(system, :ng_ccs_CT)
solar_pv_CT = Macro.get_asset_by_id(system, :solar_pv_CT)
onshore_wind_CT = Macro.get_asset_by_id(system, :onshore_wind_CT)
electrolyzer_CT = Macro.get_asset_by_id(system, :electrolyzer_CT)
smr_CT = Macro.get_asset_by_id(system, :smr_CT)
smr_ccs_CT = Macro.get_asset_by_id(system, :smr_ccs_CT)
ng_dac_CT = Macro.get_asset_by_id(system, :ng_dac_CT)
electric_dac_CT = Macro.get_asset_by_id(system, :electric_dac_CT)

ng_ME = Macro.get_asset_by_id(system, :ng_ME)
ng_ccs_ME = Macro.get_asset_by_id(system, :ng_ccs_ME)
onshore_wind_ME = Macro.get_asset_by_id(system, :onshore_wind_ME)
electrolyzer_ME = Macro.get_asset_by_id(system, :electrolyzer_ME)
smr_ME = Macro.get_asset_by_id(system, :smr_ME)
smr_ccs_ME = Macro.get_asset_by_id(system, :smr_ccs_ME)
ng_dac_ME = Macro.get_asset_by_id(system, :ng_dac_ME)
electric_dac_ME = Macro.get_asset_by_id(system, :electric_dac_ME)

println()