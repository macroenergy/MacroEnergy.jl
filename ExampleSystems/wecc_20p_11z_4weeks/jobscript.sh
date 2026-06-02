#!/bin/bash

#SBATCH --job-name=ed_sl        # create a short name for your job
#SBATCH --nodes=1                # node count
#SBATCH --ntasks=1               # total number of tasks across all nodes
#SBATCH --cpus-per-task=32      # cpu-cores per task (>1 if multi-threade>
#SBATCH --mem=600GB              # total memory
#SBATCH --output=slurm-%j.out 
#SBATCH --constraint=amd 
#SBATCH --time=12:00:00          # total run time limit (HH:MM:SS)
#SBATCH --mail-type=all          # send email when job ends
#SBATCH --mail-user=ed0400@princeton.edu


module purge
module load gurobi/12.0.0
module load julia/1.12.1

julia Run_oncluster.jl