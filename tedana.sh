#!/bin/env bash
#SBATCH --array=2-66 # always start from 2 for BIDS datasets in order to skip the column header in participants.tsv
#SBATCH --job-name=tedana
#SBATCH --account=<insert account ID here>
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=16000
#SBATCH --time=04:00:00 # time in d-hh:mm:ss
#SBATCH --output slurm.%x.%3a.%j.out # file to save job's output (%x=job name, %j=Job ID, %t=array ID)
#SBATCH --error slurm.%x.%3a.%j.err # file to save job's error log (%x=job name, %j=Job ID, %t=array ID)
#SBATCH --open-mode=append
#SBATCH --mail-user=<insert email here>
#SBATCH --mail-type=FAIL # send email if job fails
#SBATCH --mail-type=END # send email when job ends (could be many emails!)
#SBATCH --export=NONE # do not export any of the job-submitting shell environment variables
#-----------------------------------------------------------------------------------------------
#define variables
tedanaversion=0.0.12 # tedana version to use
fmriprepversion=22.0.2 # fmriprep folder to use
projectmassive=${SLURM_JOB_ACCOUNT} # MASSIVE project ID set at the top of the script, e.g. #SBATCH --account=fc37
datasetname=PsiConnect # dataset folder name
datasetdir=/scratch2/${projectmassive}/${datasetname}
bidsdir=${datasetdir}/bids # path to a valid BIDS dataset (check with BIDS validator first!)
fmriprepdir=${datasetdir}/derivatives/fmriprep-${fmriprepversion}
tedanadir=${datasetdir}/derivatives/tedana-${tedanaversion}
tedanaenv=<insert path to python env here> # e.g. my-folder/env-tedana/bin/activate
subject=$(cut -f1 ${bidsdir}/participants.tsv | sed -n ${SLURM_ARRAY_TASK_ID}p) # read first column of participants.tsv, then pick rows corresponding to SLURM job array number (remember to start the array number from 2 to skip the column header in participants.tsv)
space=MNI152NLin2009cAsym # space of preprocessed BOLD data
tasks=('meditation' 'movie' 'music' 'rest')
echotime1=0.01260 # Echo times (in seconds)
echotime2=0.02923
echotime3=0.04586
echotime4=0.06249


# --------------------------------------------------------------------------------------------------
module load fsl/6.0.5.1
module load mrtrix/3.0.3
module load ants/2.3.4 # must load after mrtrix to avoid error in loading h5
module load python/3.9.10-linux-centos7-cascadelake-gcc11.2.0 # Python version seems to be critical, it's the one used for creating the virtual environment
source ${tedanaenv}

#---------------------------------------------------------------------------------------------------
echo "SLURM_ARRAY_TASK_ID is ${SLURM_ARRAY_TASK_ID}" # print SLURM array task ID
echo "subject ${subject}" # print subject ID

shopt -s globstar # enable to list files in subdirectories using **/*

cd ${fmriprepdir}/${subject}
sessions=($(ls -d ses*)) # all directories starting with ses*
for ses in "${sessions[@]}"; do
	echo "${subject} ${ses}"

	dir_func="${fmriprepdir}/${subject}/${ses}/func"
	cd ${dir_func}

	for task in "${tasks[@]}"; do
		echo "${subject} ${ses} task:${task}"

		derivsdir=${tedanadir}/${subject}/${ses}/task-${task} # where the derivatives will go
		mkdir -p ${derivsdir} # creates dir only if it doesn't already exist

		# get number of runs for that task:
		runs=($(ls *"${task}"_run-*_desc-confounds_timeseries.json))
		nRuns=${#runs[@]}

		# for each run:
		for run in $(seq 1 ${nRuns}); do
			echo "${subject} ${ses} task:${task} run:${run}"

			# find brain mask in T1 space
			mask_T1=$(ls ${fmriprepdir}/${subject}/**/anat/*run-1_desc-brain_mask.nii.gz)
			echo ${mask_T1}

			# transform T1 mask to BOLD space using fmriprep-generated transforms
			echo "transforming T1 mask to BOLD space..."
			output=${dir_func}/${subject}_${ses}_task-${task}_run-${run}_desc-brainfromT1_mask.nii.gz
			reference=${dir_func}/${subject}_${ses}_task-${task}_run-${run}_desc-brain_mask.nii.gz 
			transform=${dir_func}/${subject}_${ses}_task-${task}_run-${run}_from-T1w_to-scanner_mode-image_xfm.txt
			antsApplyTransforms \
			--input ${mask_T1} \
			--interpolation NearestNeighbor \
			--output ${output} \
			--reference-image ${reference} \
			--transform ${transform} \
			--dimensionality 3 \
			--verbose

			# dilate mask by one voxel
			maskfilter -npass 1 -force -info "${output}" dilate "${output}"

			brainmask=${output}

			echobold1=${subject}_${ses}_task-${task}_run-${run}_echo-1_desc-preproc_bold.nii.gz
			echobold2=${subject}_${ses}_task-${task}_run-${run}_echo-2_desc-preproc_bold.nii.gz
			echobold3=${subject}_${ses}_task-${task}_run-${run}_echo-3_desc-preproc_bold.nii.gz
			echobold4=${subject}_${ses}_task-${task}_run-${run}_echo-4_desc-preproc_bold.nii.gz

			echo "Running tedana..."
			tedana \
			-d ${echobold1} ${echobold2} ${echobold3} ${echobold4} \
			-e ${echotime1} ${echotime2} ${echotime3} ${echotime4} \
			--mask ${brainmask} \
			--out-dir ${derivsdir} \
			--fittype curvefit

			# threshold and binarise tedana adaptiveGoodSignal mask
			input=${derivsdir}/desc-adaptiveGoodSignal_mask.nii.gz
			output=${derivsdir}/${subject}_${ses}_task-${task}_run-${run}_space-${space}_desc-adaptiveGoodSignalThr_mask.nii.gz
			fslmaths ${input} -thr 1.9 ${output} # at least 2 good echoes
			fslmaths ${output} -bin ${output}
			echo "binarised tedana adaptiveGoodSignal mask"
			# transform adaptiveGoodSignal mask to BOLD space using fmriprep-generated transforms
			echo "transforming tedana adaptiveGoodSignal mask to MNI space..."
			transform_scanner_to_T1=${dir_func}/${subject}_${ses}_task-${task}_run-${run}_from-scanner_to-T1w_mode-image_xfm.txt
			transform_T1_to_MNI=$(ls ${fmriprepdir}/${subject}/**/*from-T1w_to-${space}_mode-image_xfm.h5)
			reference=${dir_func}/${subject}_${ses}_task-${task}_run-${run}_space-${space}_desc-brain_mask.nii.gz
			antsApplyTransforms \
			--input ${output} \
			--interpolation NearestNeighbor \
			--output ${output} \
			--reference-image ${reference} \
			--transform ${transform_T1_to_MNI} \
			--transform ${transform_scanner_to_T1} \
			--dimensionality 3 \
			--verbose

			# normalize optimally combined image (prior to cleaning) from BOLD space to MNI space using fmriprep-generated transforms
			echo "transforming optimally combined image from BOLD space to MNI space..."
			input=${derivsdir}/desc-optcom_bold.nii.gz
			output=${derivsdir}/${subject}_${ses}_task-${task}_run-${run}_space-${space}_desc-optcom_bold.nii.gz
			reference=${dir_func}/${subject}_${ses}_task-${task}_run-${run}_space-${space}_boldref.nii.gz
			#note that --input-image-type 3 indicates a time series
			antsApplyTransforms \
			--input ${input} \
			--interpolation LanczosWindowedSinc \
			--output ${output} \
			--reference-image ${reference} \
			--transform ${transform_T1_to_MNI} \
			--transform ${transform_scanner_to_T1} \
			--dimensionality 3 \
			--input-image-type 3 \
			--verbose

			# normalize cleaned image from BOLD space to MNI space using fmriprep-generated transforms
			echo "transforming denoised results from BOLD space to MNI space..."
			input=${derivsdir}/desc-optcomDenoised_bold.nii.gz
			output=${derivsdir}/${subject}_${ses}_task-${task}_run-${run}_space-${space}_desc-optcomDenoised_bold.nii.gz
			#note that --input-image-type 3 indicates a time series
			antsApplyTransforms \
			--input ${input} \
			--interpolation LanczosWindowedSinc \
			--output ${output} \
			--reference-image ${reference} \
			--transform ${transform_T1_to_MNI} \
			--transform ${transform_scanner_to_T1} \
			--dimensionality 3 \
			--input-image-type 3 \
			--verbose

		done
	done
done

# --------------------------------------------------------------------------------------------------
date +"%Y-%m-%d %T"
echo -e "\t\t\t ----- DONE ----- "


