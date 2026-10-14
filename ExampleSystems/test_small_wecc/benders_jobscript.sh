#!/bin/bash

#SBATCH --job-name=wecc_sl
#SBATCH --nodes=1
#SBATCH --ntasks=80
#SBATCH --ntasks-per-node=80
#SBATCH --cpus-per-task=1
#SBATCH --mem=400GB
#SBATCH --output=logs/slurm-%j.out
#SBATCH --time=10:00:00          # (HH:MM:SS)
#SBATCH --mail-type=all          
#SBATCH --mail-user=ed0400@princeton.edu

module purge
module load gurobi/12.0.0
module load julia/1.12.1

julia Run_benders_oncluster.jl