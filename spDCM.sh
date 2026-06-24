#!/bin/env bash
#SBATCH --array=2-66 # always start from 2 for BIDS datasets in order to skip the column header in participants.tsv
#SBATCH --job-name=spDCM
#SBATCH --account=<insert account ID here>
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=4000
#SBATCH --time=00:30:00 # time in d-hh:mm:ss
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
datasetname=PsiConnect # dataset folder name
scriptsdir=<insert path to scripts folder here> # folder containing spDCM_single_run.m
funcname=spDCM_single_run
datasetdir=${HOME}/${projectmassive}_scratch/${datasetname}
bidsdir=${datasetdir}/bids # path to a valid BIDS dataset (check with BIDS validator first!)
derivsdir=${datasetdir}/derivatives/spDCM # where the derivatives will go
subject=$(cut -f1 ${bidsdir}/participants.tsv | sed -n ${SLURM_ARRAY_TASK_ID}p) # read first column of participants.tsv, then pick rows corresponding to SLURM job array number (remember to start the array number from 2 to skip the column header in participants.tsv)
ncpus=$SLURM_CPUS_PER_TASK

sessions=('ses-01' 'ses-02') 
tasks=('meditation' 'movie' 'music' 'rest') 

#ses=ses-01
#task=meditation

# --------------------------------------------------------------------------------------------------
module purge # always purge modules in job arrays to ensure consistent environments
module load matlab/r2022a

echo "SLURM_ARRAY_TASK_ID is ${SLURM_ARRAY_TASK_ID}" # print SLURM array task ID
echo "subject ${subject}" # print subject ID
echo "ncpus= $ncpus"

#echo "ses= $ses"
#echo "task= $task"

date +"%Y-%m-%d %T"
echo "Running spDCM..."

for ses in "${sessions[@]}"; do
	for task in "${tasks[@]}"; do
		CMD="cd('${scriptsdir}'); disp(pwd); ${funcname}('${subject}','${ses}','${task}','1');exit"
		echo ${CMD}
		matlab -nodisplay -nosplash -softwareopengl -r "${CMD}"
	done
done

# --------------------------------------------------------------------------------------------------
date +"%Y-%m-%d %T"
echo -e "\t\t\t ----- DONE ----- "

