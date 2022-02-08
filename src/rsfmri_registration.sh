#!/bin/bash

###########################################################
#                                                         #
#   Resting-State fMRI resgistration to MNI152 template   #
#                                                         #
###########################################################



#Patient code
patient=$1
#Timestamp initial (using for log file name)
timestamp_initial=$2
#Folder to place the rsfmri preprocessing outputs
restprep_folder=$3
#Standard image Path
standard=/app/brain_templates/MNI152_T1_3mm_brain.nii.gz
#Anatomical image Path
anat_orig=/project/Preproc/Anat/${patient}_acpc/${patient}_acpc.nii.gz
#Anatomical brain image Path
anat_brain=/project/Preproc/BET/${patient}_T1w_brain.nii.gz 

mkdir -p /project/Preproc/${restprep_folder}/${patient}
cd /project/Preproc/${restprep_folder}/${patient}

mkdir -p registration_folder

fslreorient2std /project/data/${patient}/func/*.nii.gz rest_reor
func_r=/project/Preproc/${restprep_folder}/${patient}/rest_reor.nii.gz

#get the fmri volumes number
nvol=$(fslval ${func_r} dim4) 
#get the fmri middle volume
midvol=$(echo "${nvol} / 2" | bc -l) 

#create 3D image as functional_example with its middle volume
fslroi ${func_r} registration_folder/example_func ${midvol} 1 
cd registration_folder
timepoint=$(date +"%H:%M")
echo "$timepoint    **Doing transformation between functional and anatomical images...**" >> /app/log/rsfMRIpreproc_${timestamp_initial}.txt
#generate transformation matrix from fmri to anat
epi_reg --epi=example_func --t1=${anat_orig} --t1brain=${anat_brain} --out=epi2anat
#generate transformation matrix from anat to fmri
convert_xfm -inverse -omat anat2epi.mat epi2anat.mat 
timepoint=$(date +"%H:%M")
echo "$timepoint    **Doing transformation between standard and anatomical images...**" >> /app/log/rsfMRIpreproc_${timestamp_initial}.txt
#generate transformation matrix and warp from anat to standard
antsRegistrationSyN.sh -d 3 -m ${anat_brain} -f ${standard} -o anat2standard
#generate matrices compatibles with convert3d
c3d_affine_tool -ref ${anat_brain} -src example_func.nii.gz \
    epi2anat.mat -fsl2ras -oitk epi2anat.txt

c3d_affine_tool -ref example_func.nii.gz -src ${anat_brain} \
    anat2epi.mat -fsl2ras -oitk anat2epi.txt
