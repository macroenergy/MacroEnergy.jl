function generate_decomposed_system(periods_full::Vector{System})
    
    number_of_subperiods = sum(length(system.time_data[:Electricity].subperiods) for system in periods_full);

    system_decomp = Vector{System}(undef,number_of_subperiods)
    subperiod_count = 0;

    for system in periods_full
        period_index = system.time_data[:Electricity].period_index;
        number_of_subperiods_per_period = length(system.time_data[:Electricity].subperiods);
        for i in 1:number_of_subperiods_per_period
            subperiod_count = subperiod_count + 1;
            system_decomp[subperiod_count] = deepcopy(system)
            w = system.time_data[:Electricity].subperiod_indices[i];
            subperiod_w = system.time_data[:Electricity].subperiods[i];
            weight_w = system.time_data[:Electricity].subperiod_weights[w];
            subperiod_map = system.time_data[:Electricity].subperiod_map;
            modeled_subperiods_all = collect(keys(subperiod_map));
            for c in keys(system.time_data)
                system_decomp[subperiod_count].time_data[c].time_interval = subperiod_w
                system_decomp[subperiod_count].time_data[c].subperiod_weights = Dict(w => weight_w)
                system_decomp[subperiod_count].time_data[c].subperiods = [subperiod_w]
                system_decomp[subperiod_count].time_data[c].subperiod_indices = [w]
                system_decomp[subperiod_count].time_data[c].period_index = period_index
                modeled_subperiods = modeled_subperiods_all[findall(subperiod_map[x]==w for x in modeled_subperiods_all)] 
                system_decomp[subperiod_count].time_data[c].subperiod_map = Dict(n => w for n in modeled_subperiods) 
            end
        end
    end


    return system_decomp
end

function get_period_to_subproblem_mapping(periods::Vector{System})
    period_to_subproblem_map = Dict{Int64,Vector{Int64}}()
    subperiod_count = 0;
    for system in periods
        period_index = system.time_data[:Electricity].period_index;
        number_of_subperiods_per_period = length(system.time_data[:Electricity].subperiods);       
        for i in 1:number_of_subperiods_per_period
            subperiod_count = subperiod_count + 1; 
            if haskey(period_to_subproblem_map, period_index)
                push!(period_to_subproblem_map[period_index], subperiod_count)
            else
                period_to_subproblem_map[period_index] = [subperiod_count]
            end
        end
    end
    return period_to_subproblem_map, subperiod_count
    
end

function start_distributed_processes!(number_of_processes::Int64,case_path::AbstractString)

    # rmprocs.(workers())

    if haskey(ENV,"SLURM_NTASKS")
        parse(Int, ENV["SLURM_NTASKS"]) > number_of_processes ? @warn("SLURM_NTASKS is greater than the number of processes specified. Only $number_of_processes processes will be used.") : nothing
        cpus_per_task = parse(Int, ENV["SLURM_CPUS_PER_TASK"]);
        addprocs(SlurmClusterManager.SlurmManager(); exeflags=["-t $cpus_per_task"])
    else
        ntasks = min(number_of_processes,Sys.CPU_THREADS)
        cpus_per_task = 1;
        addprocs(ntasks)
    end

    project = Pkg.project().path

    @sync for p in workers()
        @async create_worker_process(p,project,case_path) # add a check
    end

    @info("Number of procs: $(nprocs())")
    @info("Number of workers: $(nworkers())")
end

function solver_available(solver_name::Symbol)::Bool
    return isdefined(Main, solver_name)
end

function create_worker_process(pid,project,case_path::AbstractString)

    Distributed.remotecall_eval(Main, pid,:(using Pkg))

    Distributed.remotecall_eval(Main, pid,:(Pkg.activate($(project))))

    Distributed.remotecall_eval(Main, pid, :(using MacroEnergy))

    optional_solvers = [:Gurobi,]
    for solver in optional_solvers
        if solver_available(solver)
            Distributed.remotecall_eval(Main, pid, :(using $solver))
            @debug("Loaded $solver on worker $pid")
        end
    end

    Distributed.remotecall_eval(Main, pid, :(using MacroEnergySolvers))

    Distributed.remotecall_eval(MacroEnergy, pid, :(MacroEnergy.load_user_additions($case_path)))

end
