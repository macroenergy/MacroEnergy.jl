#!/bin/bash

#SBATCH --job-name=ed_smallcase_bd        # create a short name for your job
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=4
#SBATCH --cpus-per-task=24 
#SBATCH --mem=200GB              # total memory
#SBATCH --constraint=amd
#SBATCH --time=2:00:00          # total run time limit (HH:MM:SS)
#SBATCH --mail-type=all          # send email when job ends
#SBATCH --mail-user=ed0400@princeton.edu


module purge
module load gurobi/12.0.0
module load julia/1.12.1

julia Run_oncluster.jl