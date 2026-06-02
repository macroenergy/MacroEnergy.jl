#!/bin/bash

#SBATCH --job-name=ed_sl_bd        
#SBATCH --nodes=1                
#SBATCH --ntasks=80              
#SBATCH --ntasks-per-node=80
#SBATCH --cpus-per-task=1
#SBATCH --output=slurm-%j.out 
#SBATCH --mem=400GB              
#SBATCH --constraint=amd
#SBATCH --time=24:00:00          # (HH:MM:SS)
#SBATCH --mail-type=all          
#SBATCH --mail-user=ed0400@princeton.edu

module purge
module load gurobi/12.0.0
module load julia/1.12.1

julia Run_benders_oncluster.jl