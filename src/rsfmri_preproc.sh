#!/bin/bash

###########################################################
#                                                         #
#            Resting-State fMRI Preprocessing             #
#                                                         #
###########################################################

#Patient code
patient=$1 
#Project root
mainPath=$2
#Physiological removal technique 2param/PCA
phys_rem=$3
#GSR removal
GSR_bool=$4
#Movement removal technique AROMA/6param+Scrubbing/24param+Scrubbing
mov_rem=$5
#Functional image Path
func=${mainPath}/Preproc/RestPrep/${patient}/rest_reor.nii.gz
#Slice order file
slice_order=${mainPath}/DATA/slice_order.txt 
#Repetition time
TR=$(fslval ${func} pixdim4) 


timepoint=$(date +"%H:%M")
echo "$timepoint    **Starting Preprocessing...**"

cd ${mainPath}/Preproc/RestPrep/${patient}
mkdir -p mc 
mkdir -p Nuisance_regression

#Copy the functional image to the preproc directory
fslmaths ${func} prefiltered_func_data -odt float

#motion correction parameters calculation
timepoint=$(date +"%H:%M")
echo "$timepoint    **doing motion correction...**"
mcflirt -in prefiltered_func_data -out mc/prefiltered_func_data_mcf -mats -plots -reffile registration_folder/example_func -rmsrel -rmsabs -spline_final 

timepoint=$(date +"%H:%M")
echo "$timepoint    **doing slice time correction...**"
#Slice order correction
slicetimer -i mc/prefiltered_func_data_mcf --out=prefiltered_func_data_st -r ${TR} --ocustom=${slice_order} 

#4D image to 3D (temporal mean)
timepoint=$(date +"%H:%M")
echo "$timepoint    **doing brain straction...**"
fslmaths prefiltered_func_data_st -Tmean mean_func 
#Brain extraction of the 3D image
bet2 mean_func mask -f 0.3 -n -m 
#Renamming of the mask
immv mask_mask mask 
#Brain extraction of the 4D image using the mask
fslmaths prefiltered_func_data_st -mas mask prefiltered_func_data_bet 

timepoint=$(date +"%H:%M")
echo "$timepoint    **doing intensity normalization...**"
#extract the most common value of the image to eliminate the background noise
intensity_percentile=$(fslstats prefiltered_func_data_bet -p 2 -p 98 | awk '{ print $2 }') 
#establish a threshold using the common value of the image (ten percent of the value)
intensity_percentile_thr=$(echo "${intensity_percentile} / 10" | bc -l) 

#Get the new mask without the background noise
fslmaths prefiltered_func_data_bet -thr ${intensity_percentile_thr} -Tmin -bin mask -odt char 

#get the mean value of the image to normalize the entire data
intensity_norm=$(fslstats prefiltered_func_data_st -k mask -p 50)
#get the normalization factor 
intensity_norm_val=$(echo "10000 / ${intensity_norm}" | bc -l) 

#apply the mask to get the 4D data without skull and background noise
fslmaths prefiltered_func_data_st -mas mask prefiltered_func_data_thresh 
#Apply the factor to normalize the intensity of the image
fslmaths prefiltered_func_data_thresh -mul ${intensity_norm_val} prefiltered_func_data_intnorm 
#Store the preprocessed 4D image
fslmaths prefiltered_func_data_intnorm filtered_func_data 
#Store the 3D image with temporal mean of the 4D image
fslmaths filtered_func_data -Tmean mean_func 
#Motion outliers
fsl_motion_outliers -i filtered_func_data -o Nuisance_regression/motion_outliers_fd.txt --fd --thresh=0.5
fsl_motion_outliers -i filtered_func_data -o Nuisance_regression/motion_outliers_dvars.txt --dvars --thresh=75
#delete the prefiltered images
rm -rf prefiltered_func_data* 

################################Nuisance Regression Block######################################



#White matter probability image
wm_prob=${mainPath}/Preproc/ProbTissue/${patient}_T1w_brain_WM.nii.gz 
#CSF probability image
csf_prob=${mainPath}/Preproc/ProbTissue/${patient}_T1w_brain_CSF.nii.gz 

#MNI wm average mask
wm_avg=${mainPath}/DATA/Standard/avg152T1_white_bin_3mm.nii.gz 
#MNI csf average mask
csf_avg=${mainPath}/DATA/Standard/avg152T1_csf_bin_3mm.nii.gz 

timepoint=$(date +"%H:%M")
echo "$timepoint    **Creating matrix for the confounds regression...**"
flirt -in ${wm_prob} -ref registration_folder/example_func.nii.gz -init registration_folder/anat2epi.mat -applyxfm -interp sinc -out Nuisance_regression/wm_func_space
flirt -in ${csf_prob} -ref registration_folder/example_func.nii.gz -init registration_folder/anat2epi.mat -applyxfm -interp sinc -out Nuisance_regression/csf_func_space


WarpImageMultiTransform 3 ${wm_avg} Nuisance_regression/wm_avg_func_space.nii.gz -R registration_folder/example_func.nii.gz \
    registration_folder/anat2epi.txt -i registration_folder/anat2standard0GenericAffine.mat registration_folder/anat2standard1InverseWarp.nii.gz  --use-NN
WarpImageMultiTransform 3 ${csf_avg} Nuisance_regression/csf_avg_func_space.nii.gz -R registration_folder/example_func.nii.gz \
    registration_folder/anat2epi.txt -i registration_folder/anat2standard0GenericAffine.mat registration_folder/anat2standard1InverseWarp.nii.gz  --use-NN

fslmaths Nuisance_regression/wm_func_space -mul Nuisance_regression/wm_avg_func_space -mul mask -thr 0.66 -bin Nuisance_regression/wm_mask
fslmaths Nuisance_regression/csf_func_space -mul Nuisance_regression/csf_avg_func_space -mul mask -thr 0.66 -bin Nuisance_regression/csf_mask

rm Nuisance_regression/*func_space.nii.gz


#Physiological regression technique
if [ "$phys_rem" == '2phys' ]
then
	timepoint=$(date +"%H:%M")
	echo "$timepoint    **Performing Regression of WM and CSF signals...**"
	fslmeants -i filtered_func_data -o Nuisance_regression/wm_vec.1D -m Nuisance_regression/wm_mask
	fslmeants -i filtered_func_data -o Nuisance_regression/csf_vec.1D -m Nuisance_regression/csf_mask
elif [ "$phys_rem" == 'PCA' ]
then
	timepoint=$(date +"%H:%M")
	echo "$timepoint    **Performing Regression of 5 PCA components of WM and 5 PCA components of CSF...**"
	3dpc -prefix Nuisance_regression/wm -vmean -vnorm -nscale -pcsave 5 -mask Nuisance_regression/wm_mask.nii.gz filtered_func_data.nii.gz
	3dpc -prefix Nuisance_regression/csf -vmean -vnorm -nscale -pcsave 5 -mask Nuisance_regression/csf_mask.nii.gz filtered_func_data.nii.gz
fi

#GSR
if [ $GSR_bool -eq 1 ]
then
	timepoint=$(date +"%H:%M")
	echo "$timepoint    **Performing Global Signal Regression...**"
	fslmeants -i filtered_func_data.nii.gz -o Nuisance_regression/GSR.1D -m mask
fi

#Movement regression technique
if [ "$mov_rem" == 'AROMA' ]
then
	timepoint=$(date +"%H:%M")
	echo "$timepoint    **Performing ICA-AROMA...**"

	WarpTimeSeriesImageMultiTransform 4 filtered_func_data.nii.gz filtered_func_data_toICA_AROMA.nii.gz \
		-R ${mainPath}/DATA/Standard/MNI152_T1_3mm_brain.nii.gz \
		registration_folder/anat2standard1Warp.nii.gz registration_folder/anat2standard0GenericAffine.mat registration_folder/epi2anat.txt
	3dBlurToFWHM -FWHM 6 -mask ${mainPath}/DATA/Standard/MNI152_T1_3mm_brain_mask.nii.gz -prefix func_ICA_AROMA_smooth.nii.gz -input filtered_func_data_toICA_AROMA.nii.gz
	
	source activate ICAaroma

	python ${mainPath}/Scripts/ICA-AROMA/ICA_AROMA.py \
		-in ${mainPath}/Preproc/RestPrep/${patient}/func_ICA_AROMA_smooth.nii.gz \
		-out ${mainPath}/Preproc/RestPrep/${patient}/ICA_AROMA \
		-mc ${mainPath}/Preproc/RestPrep/${patient}/mc/prefiltered_func_data_mcf.par \
		-m ${mainPath}/DATA/Standard/MNI152_T1_3mm_brain_mask.nii.gz -den no

	timepoint=$(date +"%H:%M")
	echo "$timepoint    **Cleaning data"
	
	python ${mainPath}/Scripts/confoundsMatrix.py \
		Nuisance_regression/wm_vec.1D \
		Nuisance_regression/csf_vec.1D \
		ICA_AROMA/melodic.ica/melodic_mix 1 \
		$GSR_bool Nuisance_regression
	
	3dTproject -input filtered_func_data.nii.gz \
		-ort Nuisance_regression/Confounds.1D \
		-polort 2 -TR $TR -bandpass 0.01 0.08 \
		-prefix ${patient}_denoised.nii.gz 
elif [ "$mov_rem" == '24mov' ]
then
	timepoint=$(date +"%H:%M")
	echo "$timepoint    **Obtaining nuisance matrix for 24mov and frames to censor...**"
	source activate ICAaroma
	# MovementRegressors params:
		#Argv1: 6 movement file
		#Argv2: FD outliers
		#Argv3: DVARS outliers
		#Argv4: Nuisance folder
		#Argv5: Volume which define where the 5-length-segments start, discarding the volumes
			#from 0 to Argv5 minus 5
	python ${mainPath}/Scripts/movementRegressors.py \
		mc/prefiltered_func_data_mcf.par \
		Nuisance_regression/motion_outliers_fd.txt \
		Nuisance_regression/motion_outliers_dvars.txt Nuisance_regression 8
	python ${mainPath}/Scripts/confoundsMatrix.py \
		Nuisance_regression/wm_vec.1D \
		Nuisance_regression/csf_vec.1D \
		Nuisance_regression/movementRegressors_24.1D 0 \
		$GSR_bool Nuisance_regression
	
	timepoint=$(date +"%H:%M")
	echo "$timepoint    **Performing Scrubbing...**"
	source ${mainPath}/Scripts/rsfmri_scrubbing.sh filtered_func_data.nii.gz
	
	timepoint=$(date +"%H:%M")
	echo "$timepoint    **Performing denoise and temporal filtering...**"
	
	3dTproject -input ${file_func}_scrubb.nii.gz \
		-ort Nuisance_regression/Confounds_scrubb.1D \
		-polort 2 -TR $TR -bandpass 0.01 0.08 \
		-prefix ${patient}_denoised.nii.gz 
elif [ "$mov_rem" == '6mov' ]
then
	timepoint=$(date +"%H:%M")
	echo "$timepoint    **Obtaining nuisance matrix for 6mov and frames to censor...**"
	source activate ICAaroma
	# MovementRegressors params:
		#Argv1: 6 movement file
		#Argv2: FD outliers
		#Argv3: DVARS outliers
		#Argv4: Nuisance folder
		#Argv5: Volume which define where the 5-length-segments start, discarding the volumes
			#from 0 to Argv5 minus 5
	python ${mainPath}/Scripts/movementRegressors.py \
		mc/prefiltered_func_data_mcf.par \
		Nuisance_regression/motion_outliers_fd.txt \
		Nuisance_regression/motion_outliers_dvars.txt Nuisance_regression 8
	python ${mainPath}/Scripts/confoundsMatrix.py \
		Nuisance_regression/wm_vec.1D \
		Nuisance_regression/csf_vec.1D \
		mc/prefiltered_func_data_mcf.par 0 \
		$GSR_bool Nuisance_regression
	
	timepoint=$(date +"%H:%M")
	echo "$timepoint    **Performing Scrubbing...**"
	source ${mainPath}/Scripts/rsfmri_scrubbing.sh filtered_func_data.nii.gz
	
	timepoint=$(date +"%H:%M")
	echo "$timepoint    **Performing denoise and temporal filtering...**"
	
	3dTproject -input filtered_func_data_scrubb.nii.gz \
		-ort Nuisance_regression/Confounds_scrubb.1D \
		-polort 2 -TR $TR -bandpass 0.01 0.08 \
		-prefix ${patient}_denoised.nii.gz 
fi
timepoint=$(date +"%H:%M")
echo "$timepoint    **Transforming to MNI template...**"

WarpTimeSeriesImageMultiTransform 4 ${patient}_denoised.nii.gz ${patient}_denoised_st.nii.gz \
	-R ${mainPath}/DATA/Standard/MNI152_T1_3mm_brain.nii.gz \
	registration_folder/anat2standard1Warp.nii.gz registration_folder/anat2standard0GenericAffine.mat registration_folder/epi2anat.txt

timepoint=$(date +"%H:%M")
echo "$timepoint    **Performing Spatial smoothing...**"
3dBlurToFWHM -FWHM 6 -mask ${mainPath}/DATA/Standard/MNI152_T1_3mm_brain_mask.nii.gz -prefix ${patient}_preprocessed.nii.gz -input ${patient}_denoised_st.nii.gz

timepoint=$(date +"%H:%M")
echo "$timepoint    **END**"

