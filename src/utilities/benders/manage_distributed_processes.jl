function start_distributed_processes!(number_of_processes::Int64,solver::Module,case_path::AbstractString)

    rmprocs.(workers())

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
        @async create_worker_process(p,project,solver,case_path) # add a check
    end
    
    if  "$(solver)" == "Gurobi"
        @everywhere begin
            if !(@isdefined GRB_ENV)
                const GRB_ENV = Gurobi.Env()
            end 
        end
    end

    println("Number of procs: ", nprocs())
    println("Number of workers: ", nworkers())
end


function create_worker_process(pid,project,solver::Module,case_path::AbstractString)

    Distributed.remotecall_eval(Main, pid,:(using Pkg))

    Distributed.remotecall_eval(Main, pid,:(Pkg.activate($(project))))

    Distributed.remotecall_eval(Main, pid, :(using MacroEnergy))

    Distributed.remotecall_eval(Main, pid, :(load_subcommodities_from_file($(case_path))))
    
    Distributed.remotecall_eval(Main, pid, :(using MacroEnergySolvers))

    if  "$(solver)" == "Gurobi"
        Distributed.remotecall_eval(Main, pid, :(using Gurobi))
    end

end
