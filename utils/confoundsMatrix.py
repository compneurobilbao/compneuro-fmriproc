import numpy as np
import os
import sys
import pandas as pd
from nilearn.glm.first_level import make_first_level_design_matrix

aroma_bool = int(sys.argv[2])
subject = sys.argv[3]
task_class = sys.argv[4]
TR = float(sys.argv[5])

gs = np.genfromtxt("Nuisance_regression/GSR.1D")
wm = np.genfromtxt("Nuisance_regression/wm_vec.1D")
csf = np.genfromtxt("Nuisance_regression/csf_vec.1D")

demean_gs = gs - gs.mean(axis=0)	
demean_wm = wm - wm.mean(axis=0)
demean_csf = csf - csf.mean(axis=0)

if aroma_bool == 1:
	aroma_mix = pd.read_csv(sys.argv[1], sep="  ", header=None, engine="python")
	aroma_noise_components = np.genfromtxt("ICA_AROMA/classified_motion_ICs.txt", delimiter=",")
	aroma_noise = aroma_mix.iloc[:,aroma_noise_components-1]
	aroma_noise_matrix = aroma_noise.values
	demean_mov = aroma_noise_matrix - aroma_noise_matrix.mean(axis=0)
else:
	mov = np.genfromtxt(sys.argv[1])
	demean_mov = mov - mov.mean(axis=0)

dim_phys = len(wm.shape)
if dim_phys == 1:
	if 'rest' in task_class:
		nuisances = np.concatenate((demean_mov, demean_wm[:,None], demean_csf[:,None]), axis=1)
		nuisancesGSR = np.concatenate((demean_mov, demean_wm[:,None], demean_csf[:,None], demean_gs[:,None]), axis=1)	
	else:
		Nvol = len(gs)
		frame_times = np.array(range(0,Nvol))*TR
		taskdata = pd.read_csv('/project/data/' + subject + '/func/' + subject + '_task-' + task_class + '_events.tsv', sep = '\t')
		desing_events = make_first_level_design_matrix(frame_times, taskdata, hrf_model='glover', drift_model = None)
		taskevents = np.array(pd.DataFrame(desing_events[np.unique(taskdata['trial_type'])]))
		nuisances = np.concatenate((demean_mov, taskevents, demean_wm[:,None], demean_csf[:,None]), axis=1)
		nuisancesGSR = np.concatenate((demean_mov, taskevents, demean_wm[:,None], demean_csf[:,None], demean_gs[:,None]), axis=1)

else:
	if 'rest' in task_class:
		nuisances = np.concatenate((demean_mov, demean_wm, demean_csf), axis=1)
		nuisancesGSR = np.concatenate((demean_mov, demean_wm, demean_csf, demean_gs[:,None]), axis=1)
	else:
		Nvol = len(gs)
		frame_times = np.array(range(0,Nvol))*TR
		taskdata = pd.read_csv('/project/data/' + subject + '/func/' + subject + '_task-' + task_class + '_events.tsv', sep = '\t')
		desing_events = make_first_level_design_matrix(frame_times, taskdata, hrf_model='glover', drift_model = None)
		taskevents = np.array(pd.DataFrame(desing_events[np.unique(taskdata['trial_type'])]))
		nuisances = np.concatenate((demean_mov, taskevents, demean_wm, demean_csf), axis=1)
		nuisancesGSR = np.concatenate((demean_mov, taskevents, demean_wm, demean_csf, demean_gs[:,None]), axis=1)


nuisances_file = "Nuisance_regression/Confounds.1D"
np.savetxt(nuisances_file, nuisances, fmt=str('%0.8f'), delimiter=' ')
nuisances_fileGSR = "Nuisance_regression/Confounds_GSR.1D"
np.savetxt(nuisances_fileGSR, nuisancesGSR, fmt=str('%0.8f'), delimiter=' ')