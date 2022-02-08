#!/bin/bash

###########################################################
#                                                         #
#		  rs-fMRI Preprocessing Bash launcher             #
#                                                         #
###########################################################

Usage() {
    echo ""
    echo "Usage: restPreproc <physReg_technique>  <movReg_technique>"
    echo ""
	echo "physReg_technique: physiological noise removal technique. Options:"
    echo "1 -- 2phys: WM and CSF mean signal removal"
	echo "2 -- PCA: 5-components of CSF and WM removal "
	echo "movReg_technique: movement artifact removal technique. Options:"
	echo "1 -- 6mov: 6 movements + scrubbing"	
	echo "2 -- 24mov: 24 movements + scrubbing"	
	echo "3 -- AROMA: ICA-AROMA"	
	exit 1
}

[ "$1" = "" ] && Usage

source activate ICAaroma

physReg_technique=$1
movReg_technique=$2
timestamp_initial=$(date +"%H:%M")
touch /app/log/rsfMRIpreproc_${timestamp_initial}.txt
restprep_folder=RestPrep_${physReg_technique}_${movReg_technique}
while read line
do
    participant=$( echo ${line} | awk '{ print $1 }')

	if [  -f "/project/Preproc/${restprep_folder}/${participant}/${participant}_preprocessed.nii.gz" ]; then
        echo "$participant already processed" >> /app/log/rsfMRIpreproc_${timestamp_initial}.txt
    else
        echo "*********************" >> /app/log/rsfMRIpreproc_${timestamp_initial}.txt
        echo "$participant" >> /app/log/rsfMRIpreproc_${timestamp_initial}.txt
        echo "*********************" >> /app/log/rsfMRIpreproc_${timestamp_initial}.txt
 
        source /app/src/rsfmri_registration.sh $participant $timestamp_initial $restprep_folder
        source /app/src/rsfmri_preproc.sh $participant $physReg_technique $movReg_technique $timestamp_initial $restprep_folder

   fi
	
done < /project/data/participants.tsv





