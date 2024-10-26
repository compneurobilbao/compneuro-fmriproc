#!/bin/bash

###########################################################
#                                                         #
#                   fMRI Preprocessing                    #
#                                                         #
###########################################################

#Patient code
patient=$1 
#Physiological removal technique 2param/PCA
phys_rem=$2
#Movement removal technique AROMA/6param+Scrubbing/24param+Scrubbing
mov_rem=$3
#Timestamp initial (using for log file name)
timestamp_initial=$4
#Folder to place the rsfmri preprocessing outputs
prep_folder=$5
#Name of the task performed during fMRI scan
task_class=$6
#Functional image Path
func=/project/Preproc/${prep_folder}/${patient}/fmri_reor.nii.gz
func_json=/project/data/${patient}/func/sub-*_task-${task_class}_*.json

#Slice order and slice time files
if [  -f $func_json ]; then
	jq .SliceTiming $func_json | sed '1d;$d' | sed 's/ //g' | sed 's/,//g' > /project/data/${patient}/func/${task_class}_slice_timing.txt
	if [ -s /project/data/${patient}/func/${task_class}_slice_timing.txt ]; then
		echo "Slice timing file created" >> /project/log/fMRIpreproc_${timestamp_initial}.txt
	else
		echo "WARNING: Slice timing file not created" >> /project/log/fMRIpreproc_${timestamp_initial}.txt
		rm /project/data/${patient}/func/${task_class}_slice_timing.txt
	fi
else
	"WARNING: JSON file not found" >> /project/log/fMRIpreproc_${timestamp_initial}.txt
fi

slice_order=/project/data/slice_order_${task_class}.txt
slice_time=/project/data/slice_timing_${task_class}.txt 
slice_time_subject=/project/data/${patient}/func/${task_class}_slice_timing.txt

#Repetition time
TR=$(fslval ${func} pixdim4) 

timepoint=$(date +"%H:%M")
echo "$timepoint    **Starting Preprocessing...**" >> /project/log/fMRIpreproc_${timestamp_initial}.txt

cd /project/Preproc/${prep_folder}/${patient}
mkdir -p mc 
mkdir -p Nuisance_regression

#Copy the functional image to the preproc directory
fslmaths ${func} prefiltered_func_data -odt float

#Slice order correction

timepoint=$(date +"%H:%M")
echo "$timepoint    **doing slice time correction...**" >> /project/log/fMRIpreproc_${timestamp_initial}.txt

if [  -f $slice_time_subject ]; then
	slicetimer -i prefiltered_func_data --out=prefiltered_func_data_st -r ${TR} --tcustom=${slice_time_subject}
elif [  -f $slice_order ]; then
    slicetimer -i prefiltered_func_data --out=prefiltered_func_data_st -r ${TR} --ocustom=${slice_order}
elif [  -f $slice_time ]; then
	slicetimer -i prefiltered_func_data --out=prefiltered_func_data_st -r ${TR} --tcustom=${slice_time}
else
    echo "WARNING: Slice order file not found, slice time correction not perfomed" >> /project/log/fMRIpreproc_${timestamp_initial}.txt
    echo "Please, if you want to perform it, place the slice-order or slice-time files in data folder" >> /project/log/fMRIpreproc_${timestamp_initial}.txt
	fslmaths prefiltered_func_data prefiltered_func_data_st
fi 

#Motion outliers
#Framewise displacement calculated following (Power et al, NeuroImage, 59(3), 2012), if you want a less restricted threshold use 0.5
fsl_motion_outliers -i prefiltered_func_data_st -o Nuisance_regression/motion_outliers_fd.txt --fd --thresh=0.2 \
	-s Nuisance_regression/fd.txt
#DVARS calculated following (see Power et al, NeuroImage, 59(3), 2012)
fsl_motion_outliers -i prefiltered_func_data_st -o Nuisance_regression/motion_outliers_dvars.txt --dvars \
	--thresh=50 -s Nuisance_regression/dvars.txt

#motion correction parameters calculation
timepoint=$(date +"%H:%M")
echo "$timepoint    **doing motion correction...**" >> /project/log/fMRIpreproc_${timestamp_initial}.txt
mcflirt -in prefiltered_func_data_st -out mc/prefiltered_func_data_mcf -mats -plots -reffile registration_folder/example_func -rmsrel -rmsabs -spline_final 

#4D image to 3D (temporal mean)
timepoint=$(date +"%H:%M")
echo "$timepoint    **doing brain straction...**" >> /project/log/fMRIpreproc_${timestamp_initial}.txt
fslmaths mc/prefiltered_func_data_mcf -Tmean mean_func 

#Brain extraction of the 3D image
bet2 mean_func mask -f 0.3 -n -m 
#Renamming of the mask
mv mask_mask.nii.gz mask.nii.gz 
#Brain extraction of the 4D image using the mask
fslmaths mc/prefiltered_func_data_mcf -mas mask prefiltered_func_data_bet 

timepoint=$(date +"%H:%M")
echo "$timepoint    **doing intensity normalization...**" >> /project/log/fMRIpreproc_${timestamp_initial}.txt
#extract the most common value of the image to eliminate the background noise
intensity_percentile=$(fslstats prefiltered_func_data_bet -p 2 -p 98 | awk '{ print $2 }') 
#establish a threshold using the common value of the image (ten percent of the value)
intensity_percentile_thr=$(echo "${intensity_percentile} / 10" | bc -l) 

#Get the new mask without the background noise
fslmaths prefiltered_func_data_bet -thr ${intensity_percentile_thr} -Tmin -bin mask -odt char 
#Applying the intensity normalization with a mode of 10000
fslmaths mc/prefiltered_func_data_mcf -ing 10000 -mas mask filtered_func_data

#Store the 3D image with temporal mean of the 4D image
fslmaths filtered_func_data -Tmean mean_func 
#delete the prefiltered images
rm -rf prefiltered_func_data* 

################################Nuisance Regression Block######################################

#White matter probability image
wm_prob=/project/Preproc/ProbTissue/${patient}_T1w_brain_WM.nii.gz 
#CSF probability image
csf_prob=/project/Preproc/ProbTissue/${patient}_T1w_brain_CSF.nii.gz 

#MNI wm average mask
wm_avg=/app/brain_templates/avg152T1_white_bin_3mm.nii.gz 
#MNI csf average mask
csf_avg=/app/brain_templates/avg152T1_csf_bin_3mm.nii.gz 

#Transforming participant tissue probability masks to the functional space
timepoint=$(date +"%H:%M")
echo "$timepoint    **Creating matrix for the confounds regression...**" >> /project/log/fMRIpreproc_${timestamp_initial}.txt
flirt -in ${wm_prob} -ref registration_folder/example_func.nii.gz -init registration_folder/anat2epi.mat -applyxfm -interp sinc -out Nuisance_regression/wm_func_space
flirt -in ${csf_prob} -ref registration_folder/example_func.nii.gz -init registration_folder/anat2epi.mat -applyxfm -interp sinc -out Nuisance_regression/csf_func_space

#Transforming standard tissue probability masks to the functional space
WarpImageMultiTransform 3 ${wm_avg} Nuisance_regression/wm_avg_func_space.nii.gz -R registration_folder/example_func.nii.gz \
    registration_folder/anat2epi.txt -i registration_folder/anat2standard0GenericAffine.mat registration_folder/anat2standard1InverseWarp.nii.gz  --use-NN
WarpImageMultiTransform 3 ${csf_avg} Nuisance_regression/csf_avg_func_space.nii.gz -R registration_folder/example_func.nii.gz \
    registration_folder/anat2epi.txt -i registration_folder/anat2standard0GenericAffine.mat registration_folder/anat2standard1InverseWarp.nii.gz  --use-NN

#Multiplying participant-tissue and standard-tissue masks to make sure final masks correspond to WM and CSF
fslmaths Nuisance_regression/wm_func_space -mul Nuisance_regression/wm_avg_func_space -mul mask -thr 0.66 -bin Nuisance_regression/wm_mask
fslmaths Nuisance_regression/csf_func_space -mul Nuisance_regression/csf_avg_func_space -mul mask -thr 0.66 -bin Nuisance_regression/csf_mask

rm Nuisance_regression/*func_space.nii.gz

#Calculating tissue time-courses for nusicance regression
if [ "$phys_rem" == '2phys' ]
then
	timepoint=$(date +"%H:%M")
	echo "$timepoint    **Calculating average WM and CSF time-courses...**" >> /project/log/fMRIpreproc_${timestamp_initial}.txt
	fslmeants -i filtered_func_data -o Nuisance_regression/wm_vec.1D -m Nuisance_regression/wm_mask
	fslmeants -i filtered_func_data -o Nuisance_regression/csf_vec.1D -m Nuisance_regression/csf_mask
elif [ "$phys_rem" == 'PCA' ]
then
	timepoint=$(date +"%H:%M")
	echo "$timepoint    **Calculating 5 PCA components of WM and CSF time-courses...**" >> /project/log/fMRIpreproc_${timestamp_initial}.txt
	3dpc -prefix Nuisance_regression/wm -vmean -vnorm -nscale -pcsave 5 -mask Nuisance_regression/wm_mask.nii.gz filtered_func_data.nii.gz
	3dpc -prefix Nuisance_regression/csf -vmean -vnorm -nscale -pcsave 5 -mask Nuisance_regression/csf_mask.nii.gz filtered_func_data.nii.gz
fi

#Global signal time-course
fslmeants -i filtered_func_data.nii.gz -o Nuisance_regression/GSR.1D -m mask

#Calculating movement regressors
if [ "$mov_rem" == 'AROMA' ]
then
	timepoint=$(date +"%H:%M")
	echo "$timepoint    **Performing ICA-AROMA...**" >> /project/log/fMRIpreproc_${timestamp_initial}.txt

	#Functional image must be transformed to MNI template and smoothed before compute ICA-AROMA
	WarpTimeSeriesImageMultiTransform 4 filtered_func_data.nii.gz filtered_func_data_toICA_AROMA.nii.gz \
		-R /app/brain_templates/MNI152_T1_3mm_brain.nii.gz \
		registration_folder/anat2standard1Warp.nii.gz registration_folder/anat2standard0GenericAffine.mat registration_folder/epi2anat.txt
	3dBlurToFWHM -FWHM 6 -mask /app/brain_templates/MNI152_T1_3mm_brain_mask.nii.gz -prefix func_ICA_AROMA_smooth.nii.gz -input filtered_func_data_toICA_AROMA.nii.gz
	
	source activate ICAaroma

	python /app/utils/ICA-AROMA/ICA_AROMA.py \
		-in /project/Preproc/${prep_folder}/${patient}/func_ICA_AROMA_smooth.nii.gz \
		-out /project/Preproc/${prep_folder}/${patient}/ICA_AROMA \
		-mc /project/Preproc/${prep_folder}/${patient}/mc/prefiltered_func_data_mcf.par \
		-m /app/brain_templates/MNI152_T1_3mm_brain_mask.nii.gz -den no

	timepoint=$(date +"%H:%M")
	echo "$timepoint    **Cleaning data" >> /project/log/fMRIpreproc_${timestamp_initial}.txt
	
	source activate neuro
	#Concatenating the confounds to regress (ICA-AROMA time courses + physiological timecourses)
	python /app/utils/confoundsMatrix.py ICA_AROMA/melodic.ica/melodic_mix 1 $patient $task_class $TR

	#Denoising and bandpass filtering data
	3dTproject -input filtered_func_data.nii.gz \
		-ort Nuisance_regression/Confounds.1D \
		-polort 2 -TR $TR -bandpass 0.01 0.08 \
		-prefix ${patient}_denoised.nii.gz 
	
	#Denoising and bandpass filtering data + GSR
	3dTproject -input filtered_func_data.nii.gz \
		-ort Nuisance_regression/Confounds_GSR.1D \
		-polort 2 -TR $TR -bandpass 0.01 0.08 \
		-prefix ${patient}_denoised_GSR.nii.gz 

elif [ "$mov_rem" == '24mov' ]
then
	timepoint=$(date +"%H:%M")
	echo "$timepoint    **Obtaining nuisance matrix for 24mov and frames to censor...**" >> /project/log/fMRIpreproc_${timestamp_initial}.txt
	source activate ICAaroma

	#Calculating movement regressors and scrubbing frames
	#If you want to remove 5-length frames with a contamined frame, put the boolean argument to 1 (0 by default)
	python /app/utils/movementRegressors.py	0

	source activate neuro
	#Concatenating the confounds to regress (24 movements time courses + physiological timecourses)
	python /app/utils/confoundsMatrix.py Nuisance_regression/movementRegressors_24.1D 0 $patient $task_class $TR 

	timepoint=$(date +"%H:%M")
	echo "$timepoint    **Cleaning data" >> /project/log/fMRIpreproc_${timestamp_initial}.txt	

	#Denoising and bandpass filtering data
	3dTproject -input filtered_func_data.nii.gz \
		-ort Nuisance_regression/Confounds.1D \
		-polort 2 -TR $TR -bandpass 0.01 0.08 \
		-censor Nuisance_regression/CensoredFrames.1D \
		-cenmode NTRP \
		-prefix ${patient}_denoised.nii.gz
	
	#Denoising and bandpass filtering data + GSR
	3dTproject -input filtered_func_data.nii.gz \
		-ort Nuisance_regression/Confounds_GSR.1D \
		-polort 2 -TR $TR -bandpass 0.01 0.08 \
		-censor Nuisance_regression/CensoredFrames.1D \
		-cenmode NTRP \
		-prefix ${patient}_denoised_GSR.nii.gz 

elif [ "$mov_rem" == '6mov' ]
then
	timepoint=$(date +"%H:%M")
	echo "$timepoint    **Obtaining nuisance matrix for 6mov and frames to censor...**" >> /project/log/fMRIpreproc_${timestamp_initial}.txt
	source activate ICAaroma
	
	#Calculating movement regressors and scrubbing frames
	#If you want to remove 5-length frames with a contamined frame, put the boolean argument to 1 (0 by default)
	python /app/utils/movementRegressors.py	0

	source activate neuro
	#Concatenating the confounds to regress (6 movements time courses + physiological timecourses)
	python /app/utils/confoundsMatrix.py mc/prefiltered_func_data_mcf.par 0 $patient $task_class $TR

	timepoint=$(date +"%H:%M")
	echo "$timepoint    **Cleaning data" >> /project/log/fMRIpreproc_${timestamp_initial}.txt	

	#Denoising and bandpass filtering data
	3dTproject -input filtered_func_data.nii.gz \
		-ort Nuisance_regression/Confounds.1D \
		-polort 2 -TR $TR -bandpass 0.01 0.08 \
		-censor Nuisance_regression/CensoredFrames.1D \
		-cenmode NTRP \
		-prefix ${patient}_denoised.nii.gz
	
	#Denoising and bandpass filtering data + GSR
	3dTproject -input filtered_func_data.nii.gz \
		-ort Nuisance_regression/Confounds_GSR.1D \
		-polort 2 -TR $TR -bandpass 0.01 0.08 \
		-censor Nuisance_regression/CensoredFrames.1D \
		-cenmode NTRP \
		-prefix ${patient}_denoised_GSR.nii.gz 
fi
timepoint=$(date +"%H:%M")
echo "$timepoint    **Transforming to MNI template...**" >> /project/log/fMRIpreproc_${timestamp_initial}.txt

#Transforming to MNI template the denoised data
WarpTimeSeriesImageMultiTransform 4 ${patient}_denoised.nii.gz ${patient}_denoised_st.nii.gz \
	-R /app/brain_templates/MNI152_T1_3mm_brain.nii.gz \
	registration_folder/anat2standard1Warp.nii.gz registration_folder/anat2standard0GenericAffine.mat registration_folder/epi2anat.txt

#Transforming to MNI template the denoised data with GSR
WarpTimeSeriesImageMultiTransform 4 ${patient}_denoised_GSR.nii.gz ${patient}_denoised_GSR_st.nii.gz \
	-R /app/brain_templates/MNI152_T1_3mm_brain.nii.gz \
	registration_folder/anat2standard1Warp.nii.gz registration_folder/anat2standard0GenericAffine.mat registration_folder/epi2anat.txt

timepoint=$(date +"%H:%M")
echo "$timepoint    **Performing Spatial smoothing...**" >> /project/log/fMRIpreproc_${timestamp_initial}.txt

#Smoothing data with gaussian kernel of 6mm FWHM
3dBlurToFWHM -FWHM 6 -mask /app/brain_templates/MNI152_T1_3mm_brain_mask.nii.gz -prefix ${patient}_preprocessed.nii.gz -input ${patient}_denoised_st.nii.gz
#Smoothing GSR-data with gaussian kernel of 6mm FWHM
3dBlurToFWHM -FWHM 6 -mask /app/brain_templates/MNI152_T1_3mm_brain_mask.nii.gz -prefix ${patient}_preprocessed_GSR.nii.gz -input ${patient}_denoised_GSR_st.nii.gz

#Filtering data without denoising for QA checks
#Denoising and bandpass filtering data
3dTproject -input filtered_func_data.nii.gz \
	-polort 0 -TR $TR -bandpass 0.01 0.08 \
	-prefix ${patient}_noDenoised.nii.gz 
#Transforming to MNI template the no denoised data
WarpTimeSeriesImageMultiTransform 4 ${patient}_noDenoised.nii.gz ${patient}_noDenoised_st.nii.gz \
	-R /app/brain_templates/MNI152_T1_3mm_brain.nii.gz \
	registration_folder/anat2standard1Warp.nii.gz registration_folder/anat2standard0GenericAffine.mat registration_folder/epi2anat.txt
#Quality checks
source activate neuro

QA_report=$(python /app/utils/qa_plots.py $prep_folder $patient)
echo $QA_report >> /project/Preproc/${prep_folder}/QA_report/QA_measures.csv

timepoint=$(date +"%H:%M")
echo "$timepoint    **END**" >> /project/log/fMRIpreproc_${timestamp_initial}.txt