#!/bin/bash

###########################################################
#                                                         #
#		     fMRI Preprocessing Bash launcher             #
#                                                         #
###########################################################

Usage() {
    echo ""
    echo "Usage: fmri_launcher <physReg_technique>  <movReg_technique>"
    echo ""
	echo "physReg_technique: physiological noise removal technique. Options:"
    echo "1 -- 2phys: WM and CSF mean signal removal"
	echo "2 -- PCA: 5-components of CSF and WM removal "
	echo "movReg_technique: movement artifact removal technique. Options:"
	echo "1 -- 6mov: 6 movements + scrubbing"	
	echo "2 -- 24mov: 24 movements + scrubbing"	
	echo "3 -- AROMA: ICA-AROMA"	
    echo "task_class: name of the task performed during fMRI scan"
	exit 1
}

[ "$1" = "" ] && Usage

source activate ICAaroma

physReg_technique=$1
movReg_technique=$2
task_class=$3
timestamp_initial=$(date +"%H:%M")
touch /app/log/fMRIpreproc_${timestamp_initial}.txt
prep_folder=${task_class}_Prep_${physReg_technique}_${movReg_technique}
mkdir -p /project/Preproc/${prep_folder}/QA_report

echo "SubjectID; Dice_anat2funcReg; Dice_func2mniReg; CSF_mask_quality; WM_mask_quality; \
    FD_mean; FD_std; DVARS_mean; DVARS_std; FC_mean_noDenoised; FC_std_noDenoised; \
    FC_mean_Denoised; FC_std_Denoised; FC_mean_DenoisedGSR; FC_std_DenoisedGSR" > /project/Preproc/${prep_folder}/QA_report/QA_measures.csv

while read line
do
    participant=$( echo ${line} | awk '{ print $1 }')

	if [  -f "/project/Preproc/${prep_folder}/${participant}/${participant}_preprocessed.nii.gz" ]; then
        echo "$participant already processed" >> /app/log/fMRIpreproc_${timestamp_initial}.txt
    else
        echo "*********************" >> /app/log/fMRIpreproc_${timestamp_initial}.txt
        echo "$participant" >> /app/log/fMRIpreproc_${timestamp_initial}.txt
        echo "*********************" >> /app/log/fMRIpreproc_${timestamp_initial}.txt
 
        source /app/src/fmri_registration.sh $participant $timestamp_initial $prep_folder $task_class
        source /app/src/fmri_preproc.sh $participant $physReg_technique $movReg_technique $timestamp_initial $prep_folder $task_class

   fi
	
done < /project/data/participants.tsv






