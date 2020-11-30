#!/bin/bash

###########################################################
#                                                         #
#        Resting-State fMRI Preprocessing launcher        #
#                                                         #
###########################################################
#
#SBATCH -J rsfmriPreproc # A single job name for the array
#SBATCH -n 1 # Number of cores
#SBATCH -p medium # Partition
#SBATCH --mem 12000 # Memory request
#SBATCH -o LOG/func/prep_%A_%a.out # Standard output
#SBATCH -e LOG/func/prep_%A_%a.err # Standard error

Usage() {
    echo ""
    echo "Usage: restPreproc <physReg_technique> <GSR_boolean> <movReg_technique>"
    echo ""
	echo "physReg_technique: physiological noise removal technique. Options:"
    echo "1 -- 2phys: WM and CSF mean signal removal"
	echo "2 -- PCA: 5-components of CSF and WM removal "
	echo "GSR_boolean: indicate if global signal is removed"
	echo "movReg_technique: movement artifact removal technique. Options:"
	echo "1 -- 6mov: 6 movements + scrubbing"	
	echo "2 -- 24mov: 24 movements + scrubbing"	
	echo "3 -- AROMA: ICA-AROMA"	
	exit 1
}

[ "$1" = "" ] && Usage

ml load FSL
export FSLOUTPUTTYPE=NIFTI_GZ

physReg_technique=$1
GSR_boolean=$2
movReg_technique=$3


cd PROJECT_PATH
patients=( DATA/RAW/* )

mainRoot=PROJECT_PATH
preprocRoot=PROJECT_PATH/Scripts
patientsPreprocessingRoot=PROJECT_PATH/Preproc/RestPrep
patient="${patients[${SLURM_ARRAY_TASK_ID}]}"
patientname=$( basename $patient )

if [  -f "${patientsPreprocessingRoot}/${patientname}/${patientname}_preprocessed.nii.gz" ]; then
   echo "$patientname already processed"
else
   echo "*********************"
   echo "$patientname"
   echo "*********************"

   singularity exec PROJECT_PATH/compneuro.simg ${preprocRoot}/rsfmri_registration.sh $patientname $mainRoot
   singularity exec PROJECT_PATH/compneuro.simg ${preprocRoot}/rsfmri_preproc.sh $patientname $mainRoot $physReg_technique $GSR_boolean $movReg_technique

fi


