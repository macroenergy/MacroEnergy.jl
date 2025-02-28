using MacroEnergy
using Gurobi
using GenX

genx_case_path = "ExampleSystems/1_three_zones";
macro_case_path = "ExampleSystems/1_three_zones/1_three_zones_macro";
GenX.run_genx_case!(genx_case_path,Gurobi.Optimizer)

system = MacroEnergy.load_system(macro_case_path)
model = MacroEnergy.generate_model(system)
MacroEnergy.set_optimizer(model, Gurobi.Optimizer);
MacroEnergy.set_optimizer_attributes(model, "BarConvTol"=>1e-8,"Crossover" => 1, "Method" => 2)
MacroEnergy.optimize!(model)
results_dir = joinpath(macro_case_path , "results")
mkpath(results_dir)
MacroEnergy.write_capacity_results(joinpath(results_dir, "capacity.csv"), system)
MacroEnergy.write_costs(joinpath(results_dir, "costs.csv"), model)

println("")