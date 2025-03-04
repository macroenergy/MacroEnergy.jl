using MacroEnergy
using Gurobi
using GenX

# genx_case_path = "ExampleSystems/genx_three_zones";
# macro_case_path = "ExampleSystems/genx_three_zones/macro_inputs";

genx_case_path = "ExampleSystems/64zones_genx_0_4";
macro_case_path = "ExampleSystems/64zones_genx_0_4/macro_inputs";

genx_settings = GenX.get_settings_path(genx_case_path, "genx_settings.yml") 
writeoutput_settings = GenX.get_settings_path(genx_case_path, "output_settings.yml") 
mysetup = GenX.configure_settings(genx_settings, writeoutput_settings) 
if mysetup["TimeDomainReduction"] == 1
    TDRpath = joinpath(genx_case_path, mysetup["TimeDomainReductionFolder"])
    system_path = joinpath(genx_case_path, mysetup["SystemFolder"])
    GenX.prevent_doubled_timedomainreduction(system_path)
    if !GenX.time_domain_reduced_files_exist(TDRpath)
        println("Clustering Time Series Data (Grouped)...")
        GenX.cluster_inputs(genx_case_path, settings_path, mysetup)
    else
        println("Time Series Data Already Clustered.")
    end
end
### Configure solver
println("Configuring Solver")
OPTIMIZER = GenX.optimizer_with_attributes(Gurobi.Optimizer, "BarConvTol"=>1e-8,"Crossover" => 1, "Method" => 2)
println("Loading Inputs")
myinputs = GenX.load_inputs(mysetup, genx_case_path)

myinputs["pPercent_Loss"] = 0*myinputs["pPercent_Loss"];
myinputs["pTrans_Loss_Coef"] = 0*myinputs["pTrans_Loss_Coef"];

println("Generating the Optimization Model")
time_elapsed = @elapsed EP = GenX.generate_model(mysetup, myinputs, OPTIMIZER)
println("Time elapsed for model building is")
println(time_elapsed)
println("Solving Model")
EP, solve_time = GenX.solve_model(EP, mysetup)

myinputs["solve_time"] = solve_time 
println("Writing Output")
outputs_path = GenX.get_default_output_folder(genx_case_path)
elapsed_time = @elapsed outputs_path = GenX.write_outputs(EP,
    outputs_path,
    mysetup,
    myinputs)
println("Time elapsed for writing is")
println(elapsed_time)

system = MacroEnergy.load_system(macro_case_path)
for i in findall(typeof.(system.assets).==PowerLine)
    system.assets[i].elec_edge.loss_fraction =0.0;
end

model = MacroEnergy.generate_model(system)
MacroEnergy.set_optimizer(model, Gurobi.Optimizer);
MacroEnergy.set_optimizer_attributes(model, "BarConvTol"=>1e-8,"Crossover" => 1, "Method" => 2)
MacroEnergy.optimize!(model)
results_dir = joinpath(macro_case_path , "results")
mkpath(results_dir)
MacroEnergy.write_capacity_results(joinpath(results_dir, "capacity.csv"), system)
MacroEnergy.write_costs(joinpath(results_dir, "costs.csv"), model)

println(abs(GenX.objective_value(EP) - MacroEnergy.objective_value(model))/GenX.objective_value(EP))

println("")