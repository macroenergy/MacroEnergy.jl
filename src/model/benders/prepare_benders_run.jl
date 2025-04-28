function generate_decomposed_system(systems_full::Vector{System})
    
    number_of_subperiods = sum(length(system.time_data[:Electricity].subperiods) for system in systems_full);

    system_decomp = Vector{System}(undef,number_of_subperiods)
    subperiod_count = 0;

    for system in systems_full
        stage_index = system.time_data[:Electricity].stage_index;
        number_of_subperiods_per_stage = length(system.time_data[:Electricity].subperiods);
        for i in 1:number_of_subperiods_per_stage
            subperiod_count = subperiod_count + 1;
            system_decomp[subperiod_count] = deepcopy(system)
            w = system.time_data[:Electricity].subperiod_indices[i];
            subperiod_w = system.time_data[:Electricity].subperiods[i];
            weight_w = system.time_data[:Electricity].subperiod_weights[w];
            period_map = system.time_data[:Electricity].period_map;
            modeled_periods_all = collect(keys(period_map));
            for c in keys(system.time_data)
                system_decomp[subperiod_count].time_data[c].time_interval = subperiod_w
                system_decomp[subperiod_count].time_data[c].subperiod_weights = Dict(w => weight_w)
                system_decomp[subperiod_count].time_data[c].subperiods = [subperiod_w]
                system_decomp[subperiod_count].time_data[c].subperiod_indices = [w]
                system_decomp[subperiod_count].time_data[c].stage_index = stage_index
                modeled_periods = modeled_periods_all[findall(period_map[x]==w for x in modeled_periods_all)] 
                system_decomp[subperiod_count].time_data[c].period_map = Dict(n => w for n in modeled_periods) 
            end
        end
    end


    return system_decomp
end

function get_stage_to_subproblem_mapping(systems::Vector{System})
    stage_to_subproblem_map = Dict{Int64,Vector{Int64}}()
    subperiod_count = 0;
    for system in systems
        stage_index = system.time_data[:Electricity].stage_index;
        number_of_subperiods_per_stage = length(system.time_data[:Electricity].subperiods);       
        for i in 1:number_of_subperiods_per_stage
            subperiod_count = subperiod_count + 1; 
            if haskey(stage_to_subproblem_map, stage_index)
                push!(stage_to_subproblem_map[stage_index], subperiod_count)
            else
                stage_to_subproblem_map[stage_index] = [subperiod_count]
            end
        end
    end
    return stage_to_subproblem_map, collect(1:subperiod_count)
    
end

function start_distributed_processes!(number_of_processes::Int64,case_path::AbstractString)

    # rmprocs.(workers())

    if haskey(ENV,"SLURM_NTASKS")
        ntasks = min(number_of_processes,parse(Int, ENV["SLURM_NTASKS"]));
        cpus_per_task = parse(Int, ENV["SLURM_CPUS_PER_TASK"]);
        addprocs(ClusterManagers.SlurmManager(ntasks);exeflags=["-t $cpus_per_task"])
    else
        ntasks = min(number_of_processes,Sys.CPU_THREADS)
        cpus_per_task = 1;
        addprocs(ntasks)
    end

    project = Pkg.project().path

    @sync for p in workers()
        @async create_worker_process(p,project,case_path) # add a check
    end
    

    @info("Number of procs: ", nprocs())
    @info("Number of workers: ", nworkers())
end


function create_worker_process(pid,project,case_path::AbstractString)

    Distributed.remotecall_eval(Main, pid,:(using Pkg))

    Distributed.remotecall_eval(Main, pid,:(Pkg.activate($(project))))

    Distributed.remotecall_eval(Main, pid, :(using MacroEnergy))

    Distributed.remotecall_eval(Main, pid, :(load_subcommodities_from_file($(case_path))))
    
    Distributed.remotecall_eval(Main, pid, :(using MacroEnergySolvers))

end
