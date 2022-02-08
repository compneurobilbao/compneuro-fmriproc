import numpy as np
import os
import sys
import pandas as pd

aroma_bool = int(sys.argv[2])

gs = np.genfromtxt("Nuisance_regression/GSR.1D")
wm = np.genfromtxt("Nuisance_regression/wm_vec.1D")
csf = np.genfromtxt("Nuisance_regression/csf_vec.1D")

demean_gs = gs - gs.mean(axis=0)	
demean_wm = wm - wm.mean(axis=0)
demean_csf = csf - csf.mean(axis=0)

if aroma_bool == 1:
	aroma_mix = pd.read_csv(sys.argv[1], sep="  ", header=None)
	aroma_noise_components = pd.read_csv("ICA_AROMA/classified_motion_ICs.txt", sep=",", header=None, engine='python')
	aroma_noise_components_index = aroma_noise_components - 1
	aroma_noise = aroma_mix.iloc[:,aroma_mix.index.isin(aroma_noise_components_index)]
	aroma_noise_matrix = aroma_noise.values
	demean_mov = aroma_noise_matrix - aroma_noise_matrix.mean(axis=0)
else:
	mov = np.genfromtxt(sys.argv[1])
	demean_mov = mov - mov.mean(axis=0)

dim_phys = len(wm.shape)
if dim_phys == 1:
	nuisances = np.concatenate((demean_mov, demean_wm[:,None], demean_csf[:,None]), axis=1)
	nuisancesGSR = np.concatenate((demean_mov, demean_wm[:,None], demean_csf[:,None], demean_gs[:,None]), axis=1)
else:
	nuisances = np.concatenate((demean_mov, demean_wm, demean_csf), axis=1)
	nuisancesGSR = np.concatenate((demean_mov, demean_wm, demean_csf, demean_gs[:,None]), axis=1)


nuisances_file = "Nuisance_regression/Confounds.1D"
np.savetxt(nuisances_file, nuisances, fmt=str('%0.8f'), delimiter=' ')
nuisances_fileGSR = "Nuisance_regression/Confounds_GSR.1D"
np.savetxt(nuisances_fileGSR, nuisancesGSR, fmt=str('%0.8f'), delimiter=' ')