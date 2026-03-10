#!/bin/env bash
#SBATCH --array=2-66 # always start from 2 for BIDS datasets in order to skip the column header in participants.tsv
#SBATCH --job-name=fmriprep
#SBATCH --account=<insert account here>
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem-per-cpu=4000
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
version=22.0.2 # fmriprep version to use
projectmassive=${SLURM_JOB_ACCOUNT} # MASSIVE project ID set at the top of the script, e.g. #SBATCH --account=fc37
datasetname=PsiConnect # dataset folder name
datasetdir=/scratch2/${projectmassive}/${datasetname}
bidsdir=${datasetdir}/bids # path to a valid BIDS dataset (check with BIDS validator first!)
derivsdir=${datasetdir}/derivatives/fmriprep-${version} # where the derivatives will go
fsdir=${datasetdir}/derivatives/freesurfer-7.2
fslicense=${HOME}/Freesurfer_license.txt # path to FreeSurfer license needed to run fMRIprep. Download your own from https://surfer.nmr.mgh.harvard.edu/registration.html and save it in your home folder with the name "Freesurfer_license.txt"
singularity_image=<insert path to .simg file here>
subject=$(cut -f1 ${bidsdir}/participants.tsv | sed -n ${SLURM_ARRAY_TASK_ID}p) # read first column of participants.tsv, then pick rows corresponding to SLURM job array number (remember to start the array number from 2 to skip the column header in participants.tsv)
workdir=/tmp/fmriprep-${version}/${subject} # subject-specific temporary directory for intermediate output files. Useful to resume the process after a potential crash.
TEMPLATEFLOW_HOST_HOME=$HOME/.cache/templateflow
FMRIPREP_HOST_CACHE=$HOME/.cache/fmriprep
ncpus=$SLURM_CPUS_PER_TASK
memmb=$((($ncpus-2) * $SLURM_MEM_PER_CPU)) # the -2 is to leave some buffer
# --------------------------------------------------------------------------------------------------
module purge # always purge modules in job arrays to ensure consistent environments
unset PYTHONPATH
module load singularity/3.7.1

echo "SLURM_ARRAY_TASK_ID is ${SLURM_ARRAY_TASK_ID}" # print SLURM array task ID
echo "subject ${subject}" # print subject ID
echo "ncpus= $ncpus"
echo "mem= $memmb"

mkdir -p $derivsdir # creates dir only if it doesn't already exist
mkdir -p $fsdir # creates dir only if it doesn't already exist
mkdir -p $workdir # creates dir only if it doesn't already exist
mkdir -p ${TEMPLATEFLOW_HOST_HOME}
mkdir -p ${FMRIPREP_HOST_CACHE}

# Make sure FS_LICENSE is defined in the container.
export SINGULARITYENV_FS_LICENSE=$fslicense

# Designate a templateflow bind-mount point
export SINGULARITYENV_TEMPLATEFLOW_HOME="/templateflow"
SINGULARITY_CMD="singularity run --cleanenv -B ${bidsdir}:/bids -B ${derivsdir}:/output -B ${TEMPLATEFLOW_HOST_HOME}:${SINGULARITYENV_TEMPLATEFLOW_HOME} -B ${workdir}:/work -B ${fsdir}:/fsdir ${singularity_image}"

# Remove IsRunning files from FreeSurfer
if [ -d ${fsdir}/$subject ]; then
	find ${fsdir}/$subject/ -name "*IsRunning*" -type f -delete
fi

# Compose the command line
cmd="${SINGULARITY_CMD} /bids /output participant --participant-label $subject --fs-subjects-dir /fsdir --work-dir /work --n-cpus ${ncpus} --mem-mb ${memmb} --me-output-echos --output-spaces {MNI152NLin2009cAsym,T1w,run} --skip-bids-validation | tee ${derivsdir}/${subject}_consoleoutput.log"

cd ${datasetdir}

# Setup done, run the command
date +"%Y-%m-%d %T"
echo "Running fmriprep..."
echo Commandline: $cmd
eval $cmd

# other options:
# --me-output-echos: output individual echo time series with slice, motion and susceptibility correction. Useful for further Tedana processing post-fMRIPrep. Only available in versions >21.0.0
# --task-id: select a specific task (e.g. music)
# --output-spaces e.g. {T1w,MNI152NLin6Asym}. By default, fMRIPrep uses MNI152NLin2009cAsym as spatial-standardization reference, see https://fmriprep.org/en/stable/spaces.html . Valid template identifiers (MNI152NLin6Asym, MNI152NLin2009cAsym, etc.) come from the TemplateFlow repository. Other spaces are added implicitly when using flags such as --use-syn-sdc and --use-aroma, but they will not be saved to the derivatives directory.
# --use-syn-sdc: turns on a map-free distortion correction method that is currently listed as experimental by fmriprep developers.
# --fs-no-reconall: disables surface preprocessing, which saves a lot of time. If your registration looks okay without it, then great! If you’re seeing issues with the registration, like 'brain' is identified outside of the brain, then give it a try by removing --fs-no-reconall.
# --fs-subjects-dir: Path to existing FreeSurfer subjects directory to reuse. (default: $derivsdir/sourcedata/freesurfer)
# --cifti-output 91k (or 170k) to output preprocessed BOLD time series in CIFTI dense format. 91k or 170k is the number of grayordinates.
# --n-cpus ${ncpus} maximum number of threads across all processes
# --mem-mb ${memmb} upper bound memory limit for fMRIPrep processes
# --skip-bids-validation to skip the initial BIDS validation (not recommended)
# --------------------------------------------------------------------------------------------------
date +"%Y-%m-%d %T"
echo -e "\t\t\t ----- DONE ----- "

