#!/bin/bash

#SBATCH --job-name=macro_test       # create a short name for your job
#SBATCH --nodes=1                # node count
#SBATCH --ntasks=1               # total number of tasks across all nodes
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=5       # cpu-cores per task (>1 if multi-threaded tasks)
#SBATCH --mem-per-cpu=5GB       # memory per cpu-core 
#SBATCH --time=1:00:00          # total run time limit (HH:MM:SS)
#SBATCH --mail-type=all          # send email when job ends
#SBATCH --mail-user=al3792@princeton.edu
######## #SBATCH --exclude=della-h12n16
######## #SBATCH --constraint=cascade
######## #SBATCH --nodelist=della-h12n16

module purge
module load gurobi/10.0.1
module load julia/1.9.1

julia --project="/home/al3792/Macro" run.jl
