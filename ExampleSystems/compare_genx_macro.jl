using MacroEnergy
using Gurobi
using GenX
using JuMP

genx_case_path = "ExampleSystems/genx_three_zones_multistage";
#macro_case_path = "ExampleSystems/macro_three_zones_multistage_fixed_capacity";
macro_case_path = "ExampleSystems/macro_three_zones_multistage";
optimizer = JuMP.optimizer_with_attributes(Gurobi.Optimizer, "BarConvTol"=>1e-6,"Crossover" => 1, "Method" => 2)


genx_settings = GenX.get_settings_path(genx_case_path, "genx_settings.yml") 
writeoutput_settings = GenX.get_settings_path(genx_case_path, "output_settings.yml") 
genx_setup = GenX.configure_settings(genx_settings, writeoutput_settings) 


function myrun_genx_case_multistage!(case::AbstractString, mysetup::Dict, OPTIMIZER::Any)
    settings_path = GenX.get_settings_path(case)
    multistage_settings = GenX.get_settings_path(case, "multi_stage_settings.yml") # Multi stage settings YAML file path
    # merge default settings with those specified in the YAML file
    mysetup["MultiStageSettingsDict"] = GenX.configure_settings_multistage(multistage_settings)

    ### Cluster time series inputs if necessary and if specified by the user
    if mysetup["TimeDomainReduction"] == 1
        tdr_settings = GenX.get_settings_path(case, "time_domain_reduction_settings.yml") # Multi stage settings YAML file path
        TDRSettingsDict = GenX.YAML.load(open(tdr_settings))

        first_stage_path = joinpath(case, "inputs", "inputs_p1")
        TDRpath = joinpath(first_stage_path, mysetup["TimeDomainReductionFolder"])
        system_path = joinpath(first_stage_path, mysetup["SystemFolder"])
        GenX.prevent_doubled_timedomainreduction(system_path)
        if !GenX.time_domain_reduced_files_exist(TDRpath)
            if (mysetup["MultiStage"] == 1) &&
               (TDRSettingsDict["MultiStageConcatenate"] == 0)
                println("Clustering Time Series Data (Individually)...")
                for stage_id in 1:mysetup["MultiStageSettingsDict"]["NumStages"]
                    GenX.cluster_inputs(case, settings_path, mysetup, stage_id)
                end
            else
                println("Clustering Time Series Data (Grouped)...")
                GenX.cluster_inputs(case, settings_path, mysetup)
            end
        else
            println("Time Series Data Already Clustered.")
        end
    end

    model_dict = Dict()
    inputs_dict = Dict()
    mysetup["EnableJuMPStringNames"] = 1    
    for t in 1:mysetup["MultiStageSettingsDict"]["NumStages"]

        # Step 0) Set Model Year
        mysetup["MultiStageSettingsDict"]["CurStage"] = t

        # Step 1) Load Inputs
        inpath_sub = joinpath(case, "inputs", string("inputs_p", t))

        inputs_dict[t] = GenX.load_inputs(mysetup, inpath_sub)
        inputs_dict[t] = GenX.configure_multi_stage_inputs(inputs_dict[t],
            mysetup["MultiStageSettingsDict"],
            mysetup["NetworkExpansion"])

        inputs_dict[t]["pPercent_Loss"] = 0*inputs_dict[t]["pPercent_Loss"];
        inputs_dict[t]["pTrans_Loss_Coef"] = 0*inputs_dict[t]["pTrans_Loss_Coef"];

        GenX.compute_cumulative_min_retirements!(inputs_dict, t)
        # Step 2) Generate model
        model_dict[t] =  GenX.generate_model(mysetup, inputs_dict[t], OPTIMIZER)
    end

    # check that resources do not switch from can_retire = 0 to can_retire = 1 between stages
    GenX.validate_can_retire_multistage(
        inputs_dict, mysetup["MultiStageSettingsDict"]["NumStages"])

    ### Solve model
    println("Solving Model")

    # Prepare folder for results    
    outpath = GenX.get_default_output_folder(case)

    if mysetup["OverwriteResults"] == 1
        # Overwrite existing results if dir exists
        # This is the default behaviour when there is no flag, to avoid breaking existing code
        if !(isdir(outpath))
            mkdir(outpath)
        end
    else
        # Find closest unused ouput directory name and create it
        outpath = GenX.choose_output_dir(outpath)
        mkdir(outpath)
    end

    # # Step 3) Run DDP Algorithm
    # ## Solve Model
    model_dict, mystats_d, inputs_dict = GenX.run_ddp(outpath, model_dict, mysetup, inputs_dict)

    # Step 4) Write final outputs from each stage
    if mysetup["MultiStageSettingsDict"]["Myopic"] == 0 ||
       mysetup["MultiStageSettingsDict"]["WriteIntermittentOutputs"] == 0
        for p in 1:mysetup["MultiStageSettingsDict"]["NumStages"]
            mysetup["MultiStageSettingsDict"]["CurStage"] = p
            outpath_cur = joinpath(outpath, "results_p$p")
            GenX.write_outputs(model_dict[p], outpath_cur, mysetup, inputs_dict[p])
        end
    end

    ### Step 5) Write DDP summary outputs

    GenX.write_multi_stage_outputs(mystats_d, outpath, mysetup, inputs_dict)

    return model_dict, mystats_d,inputs_dict
end


function myrun_marco_case_multistage(macro_case_path)
    stages = MacroEnergy.load_stages(macro_case_path; lazy_load=true)
    for s in stages.systems
        for i in findall(typeof.(s.assets).==PowerLine)
            s.assets[i].elec_edge.loss_fraction =0.0;
        end
    end
    optimizer = MacroEnergy.create_optimizer(Gurobi.Optimizer, missing, ("BarConvTol"=>1e-6,"Crossover" => 1, "Method" => 2))

    (stages, model) = MacroEnergy.solve_stages(stages, optimizer)
    
    MacroEnergy.write_outputs(macro_case_path, stages, model)

    return stages.systems, model
end

genx_models,genx_stats,genx_inputs = myrun_genx_case_multistage!(genx_case_path, genx_setup, optimizer)

stages,macro_models = myrun_marco_case_multistage(macro_case_path);

# for i in 1:3
#     println("Relative difference in objective function for stage $i: $((objective_value(genx_models[i]) - objective_value(macro_models[i]))/objective_value(genx_models[i]))")
# end

println("")