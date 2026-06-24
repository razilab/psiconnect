#!/bin/env bash
#SBATCH --array=2-132 # always start from 2 for BIDS datasets in order to skip the column header in participants.tsv
#SBATCH --job-name=ROI_ts
#SBATCH --account=<insert account ID here>
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=4000
#SBATCH --time=00:45:00 # time in d-hh:mm:ss
#SBATCH --output slurm.%x.%3a.%j.out # file to save job's output (%x=job name, %j=Job ID, %t=array ID)
#SBATCH --error slurm.%x.%3a.%j.err # file to save job's error log (%x=job name, %j=Job ID, %t=array ID)
#SBATCH --open-mode=append
#SBATCH --mail-user=<insert email here>
#SBATCH --mail-type=FAIL # send email if job fails
#SBATCH --mail-type=END # send email when job ends (could be many emails!)
#SBATCH --export=NONE # do not export any of the job-submitting shell environment variables
#-----------------------------------------------------------------------------------------------
#define variables
projectmassive=${SLURM_JOB_ACCOUNT} # HPC project/account ID — set via #SBATCH --account above
scriptsdir=<insert path to scripts folder here> # folder containing ROI_time_series_extraction_single.m
funcname=ROI_time_series_extraction_single

ncpus=$SLURM_CPUS_PER_TASK


# --------------------------------------------------------------------------------------------------
module purge # always purge modules in job arrays to ensure consistent environments
module load matlab/r2024b

echo "SLURM_ARRAY_TASK_ID is ${SLURM_ARRAY_TASK_ID}" # print SLURM array task ID
echo "ncpus= $ncpus"

date +"%Y-%m-%d %T"
echo "Running ROI time series extraction..."


CMD="cd('${scriptsdir}'); disp(pwd); ${funcname}('${SLURM_ARRAY_TASK_ID}');exit"
echo ${CMD}
matlab -nodisplay -nosplash -softwareopengl -r "${CMD}"

# --------------------------------------------------------------------------------------------------
date +"%Y-%m-%d %T"
echo -e "\t\t\t ----- DONE ----- "

