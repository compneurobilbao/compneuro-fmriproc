import nibabel as nib
import numpy as np
import sys
import os
from matplotlib import pyplot as plt
from nilearn import plotting
from nilearn import image
from nilearn.maskers import NiftiLabelsMasker
from nilearn.connectome import ConnectivityMeasure

projectfolder = '/project/Preproc'
restfolder = sys.argv[1]
subject = sys.argv[2]
outputpath = os.path.join(projectfolder, restfolder, 'QA_report')

epi_img = nib.load(os.path.join(projectfolder,restfolder,subject,'mean_func.nii.gz'))
anat2func = nib.load(os.path.join(projectfolder,restfolder,subject, 'registration_folder','anat2func_mask.nii.gz'))
csf_mask = nib.load(os.path.join(projectfolder,restfolder,subject, 'Nuisance_regression','csf_mask.nii.gz'))
csf_mask_mni = nib.load(os.path.join(projectfolder,restfolder,subject, 'registration_folder','CSF2standard_mask.nii.gz')).get_fdata()
wm_mask = nib.load(os.path.join(projectfolder,restfolder,subject, 'Nuisance_regression','wm_mask.nii.gz'))
wm_mask_mni = nib.load(os.path.join(projectfolder,restfolder,subject, 'registration_folder','WM2standard_mask.nii.gz')).get_fdata()
proc = nib.load(os.path.join(projectfolder,restfolder,subject,subject  + '_denoised_st.nii.gz'))
procGSR = nib.load(os.path.join(projectfolder,restfolder,subject,subject  + '_denoised_GSR_st.nii.gz'))
no_proc = nib.load(os.path.join(projectfolder,restfolder,subject,subject + '_noDenoised_st.nii.gz'))
atlas = nib.load('/app/brain_templates/rest7netw_subcort_3mm.nii.gz')
mni_mask = nib.load('/app/brain_templates/MNI152_T1_3mm_brain_mask.nii.gz')
csf_standard_mask = nib.load('/app/brain_templates/avg152T1_csf_bin_3mm.nii.gz').get_fdata()
wm_standard_mask = nib.load('/app/brain_templates/avg152T1_white_bin_3mm.nii.gz').get_fdata()
first_proc = image.index_img(proc, 0)

fd = np.genfromtxt(os.path.join(projectfolder,restfolder,subject, 'Nuisance_regression','fd.txt'))
dvars = np.genfromtxt(os.path.join(projectfolder,restfolder,subject, 'Nuisance_regression','dvars.txt'))

#####Creating QA image#####


masker = NiftiLabelsMasker(labels_img=atlas, standardize=True,
                         memory='nilearn_cache', verbose=0)

time_series_proc = masker.fit_transform(proc,
                                   confounds=None)
time_series_procGSR = masker.fit_transform(procGSR,
                                   confounds=None)
time_series_unproc = masker.fit_transform(no_proc,
                                   confounds=None)
correlation_measure = ConnectivityMeasure(kind='correlation', vectorize = True, discard_diagonal = True)
FC_proc = correlation_measure.fit_transform([time_series_proc])[0]
FC_procGSR = correlation_measure.fit_transform([time_series_procGSR])[0]
FC_unproc = correlation_measure.fit_transform([time_series_unproc])[0]
FC_proc = FC_proc[FC_proc != 0.0]
FC_procGSR = FC_procGSR[FC_procGSR != 0.0]
FC_unproc = FC_unproc[FC_unproc != 0.0]

fig, ax = plt.subplots(nrows=2, ncols=2, figsize=(22, 12))

# QA =  plotting.plot_anat(epi_img, title='Physio-masks registration', draw_cross=False, axes = ax[0,0])
# QA.add_overlay(csf_mask,  cmap='spring')
# QA.add_overlay(wm_mask,  cmap='summer')




QA = plotting.plot_carpet(no_proc, mask_img = mni_mask,  
    axes = ax[0,0], title = 'Unprocessed image')

QA = plotting.plot_carpet(proc, mask_img = mni_mask,  
    axes = ax[1,0], title = 'Processed image')

QA =  plotting.plot_stat_map(first_proc, bg_img = None, title='Registration to standard',
     draw_cross=False, cut_coords = [-19, 20, 8], axes = ax[0,1], colorbar = False)
QA.add_overlay(atlas, cmap='tab20b')

ax[1,1].hist(FC_unproc, bins=50, density = True, alpha = 0.5, range = (-1,1), label='Unprocessed')
ax[1,1].hist(FC_proc, bins=50, density = True, alpha = 0.5, range = (-1,1), label='Processed')
ax[1,1].hist(FC_procGSR, bins=50, density = True, alpha = 0.5, range = (-1,1), label='Processed with GSR')
ax[1,1].set_title(label = 'Connectivity distributions')
ax[1,1].legend(loc='upper left')


QA.savefig(outputpath + '/QA_' + subject + '.png')


#####Creating QA textReport#####

proc_data_mask = np.where(first_proc.get_fdata() != 0, 1, 0)
mni_mask_data = mni_mask.get_fdata()
epi_img_mask = np.where(epi_img.get_fdata() != 0, 1, 0)
anat2epi_mask = anat2func.get_fdata()

# Compute Dice coefficient
intersection_mni = np.logical_and(proc_data_mask, mni_mask_data)
dice_mask_mni = 2. * intersection_mni.sum() / (proc_data_mask.sum() + mni_mask_data.sum())

intersection_anat = np.logical_and(epi_img_mask, anat2epi_mask)
dice_mask_anat = 2. * intersection_anat.sum() / (epi_img_mask.sum() + anat2epi_mask.sum())

csf_mask_quality = (np.logical_and(csf_mask_mni, csf_standard_mask)).sum() / csf_standard_mask.sum()
wm_mask_quality = (np.logical_and(wm_mask_mni, wm_standard_mask)).sum() / wm_standard_mask.sum()

fd_mean = fd.mean(axis=0)
fd_std = fd.std(axis=0)
dvars_mean = dvars.mean(axis=0)
dvars_std = dvars.std(axis=0)
FC_unproc_mean = FC_unproc.mean()
FC_unproc_std = FC_unproc.std()
FC_proc_mean = FC_proc.mean()
FC_proc_std = FC_proc.std()
FC_procGSR_mean = FC_procGSR.mean()
FC_procGSR_std = FC_procGSR.std()

print(subject + '; ' + str(dice_mask_anat) + '; ' + str(dice_mask_mni) + '; ' + str(csf_mask_quality) + '; ' + str(wm_mask_quality) + 
    '; ' + str(fd_mean) + '; ' + str(fd_std) + '; ' + str(dvars_mean) + '; ' + str(dvars_std) + '; ' + str(FC_unproc_mean) + 
    '; ' + str(FC_unproc_std) + '; ' + str(FC_proc_mean) + '; ' + str(FC_proc_std) + '; ' + str(FC_procGSR_mean) + '; ' + str(FC_procGSR_std))
