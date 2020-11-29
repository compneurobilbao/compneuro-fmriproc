#!/bin/bash

###########################################################
#                                                         #
#		    Registration Marices                  #
#                                                         #
###########################################################

#Patient code
patient=$1
#Project root 
mainPath=$2 
#Standard image Path
standard=${mainPath}/DATA/Standard/MNI152_T1_3mm_brain.nii.gz 
#Anatomical image Path
anat_orig=${mainPath}/Preproc/Anat/${patient}.anat/T1_biascorr.nii.gz 
#Functional image Path
func=${mainPath}/DATA/RAW/${patient}/func/${patient}_task-rest_bold.nii.gz 
#Anatomical brain image Path
anat_brain=${mainPath}/Preproc/BET/${patient}_T1w_brain.nii.gz 

cd ${mainPath}/Preproc/RestPrep
mkdir -p ${patient}
cd ${patient}
mkdir -p registration_folder

#get the fmri volumes number
nvol=$(fslval ${func} dim4) 
#get the fmri middle volume
midvol=$(echo "${nvol} / 2" | bc -l) 

#create 3D image as functional_example with its middle volume
fslroi ${func} registration_folder/example_func ${midvol} 1 
cd registration_folder
echo "**Doing transformation between functional and anatomical images...**"
#generate transformation matrix from fmri to anat
epi_reg --epi=example_func --t1=${anat_orig} --t1brain=${anat_brain} --out=epi2anat
#generate transformation matrix from anat to fmri
convert_xfm -inverse -omat anat2epi.mat epi2anat.mat 
echo "**Doing transformation between standard and anatomical images...**"
#generate transformation matrix and warp from anat to standard
antsRegistrationSyN.sh -d 3 -m ${anat_brain} -f ${standard} -o anat2standard
#generate matrices compatibles with convert3d
c3d_affine_tool -ref ${anat_brain} -src example_func.nii.gz \
    epi2anat.mat -fsl2ras -oitk epi2anat.txt

c3d_affine_tool -ref example_func.nii.gz -src ${anat_brain} \
    anat2epi.mat -fsl2ras -oitk anat2epi.txt