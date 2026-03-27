#!/bin/env bash
#SBATCH --array=2-66 # always start from 2 for BIDS datasets in order to skip the column header in participants.tsv
#SBATCH --job-name=mriqc
#SBATCH --account=<insert account ID here>
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=7
#SBATCH --mem-per-cpu=8000
#SBATCH --time=06:00:00 # time in d-hh:mm:ss
#SBATCH --output slurm.%x.%3a.%j.out # file to save job's output (%x=job name, %j=Job ID, %t=array ID)
#SBATCH --error slurm.%x.%3a.%j.err # file to save job's error log (%x=job name, %j=Job ID, %t=array ID)
#SBATCH --open-mode=append
#SBATCH --mail-user=<insert email here>
#SBATCH --mail-type=FAIL # send email if job fails
#SBATCH --mail-type=END # send email when job ends (could be many emails!)
#SBATCH --export=NONE # do not export any of the job-submitting shell environment variables
#-----------------------------------------------------------------------------------------------
#define variables
version=22.0.6 # mriqc version to use
projectmassive=${SLURM_JOB_ACCOUNT} # MASSIVE project ID set at the top of the script, e.g. #SBATCH --account=fc37
datasetname=PsiConnect # dataset folder name
datasetdir=/scratch2/${projectmassive}/${datasetname}
bidsdir=${datasetdir}/bids # path to a valid BIDS dataset (check with BIDS validator first!)
derivsdir=${datasetdir}/derivatives/mriqc-${version} # where the derivatives will go
singularity_image=<insert path to .simg file here>
subject=$(cut -f1 ${bidsdir}/participants.tsv | sed -n ${SLURM_ARRAY_TASK_ID}p) # read first column of participants.tsv, then pick rows corresponding to SLURM job array number (remember to start the array number from 2 to skip the column header in participants.tsv)
workdir=/tmp/mriqc-${version}/${subject} # subject-specific temporary directory for intermediate output files. Useful to resume the process after a potential crash.
TEMPLATEFLOW_HOST_HOME=$HOME/.cache/templateflow
ncpus=$SLURM_CPUS_PER_TASK
memmb=$((($ncpus-1) * $SLURM_MEM_PER_CPU)) # the -1 is to leave some buffer
memgb=$(($memmb / 1000)) # divide to get GB
# --------------------------------------------------------------------------------------------------
module purge # always purge modules in job arrays to ensure consistent environments
unset PYTHONPATH
module load singularity/3.7.1

echo "SLURM_ARRAY_TASK_ID is ${SLURM_ARRAY_TASK_ID}" # print SLURM array task ID
echo "subject ${subject}" # print subject ID
echo "ncpus= $ncpus"
echo "mem= $memgb"

mkdir -p $derivsdir # creates dir only if it doesn't already exist
mkdir -p $workdir # creates dir only if it doesn't already exist
mkdir -p ${TEMPLATEFLOW_HOST_HOME}

# Designate a templateflow bind-mount point
export SINGULARITYENV_TEMPLATEFLOW_HOME="/templateflow"

cd ${datasetdir}

# Compose the command line
cmd="singularity run --cleanenv -B ${bidsdir}:/bids -B ${derivsdir}:/output -B ${TEMPLATEFLOW_HOST_HOME}:${SINGULARITYENV_TEMPLATEFLOW_HOME} -B ${workdir}:/work ${singularity_image} /bids /output participant --participant-label $subject --work-dir /work/ --nprocs ${ncpus} --mem-gb ${memgb} | tee ${derivsdir}/sub-${subject}_consoleoutput.log"

# Setup done, run the command
date +"%Y-%m-%d %T"
echo "Running mriqc for a single participant..."
echo Commandline: $cmd
eval $cmd

# Additional options
# --task-id to filter input dataset by task id
# --modalities to filter input dataset by MRI type

# group report
# Compose the command line
cmd="singularity run --cleanenv -B ${bidsdir}:/bids -B ${derivsdir}:/output ${singularity_image} /bids /output group | tee ${derivsdir}/groupanalysis_consoleoutput.log"
# run the command
date +"%Y-%m-%d %T"
echo "Generating group report..."
echo Commandline: $cmd
eval $cmd

#-----------------------------------------------------------------------------------------------
echo -e "\t\t\t ------ DONE ------"
