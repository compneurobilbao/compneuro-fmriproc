import numpy as np
import os
import sys
import pandas as pd

wm = np.genfromtxt(sys.argv[1])
csf = np.genfromtxt(sys.argv[2])
aroma_bool = int(sys.argv[4])
GSR_bool = int(sys.argv[5])
	
demean_wm = wm - wm.mean(axis=0)
demean_csf = csf - csf.mean(axis=0)

if aroma_bool == 1:
	aroma_mix = pd.read_csv(sys.argv[3], sep="  ", header=None)
	aroma_noise_components = pd.read_csv("ICA_AROMA/classified_motion_ICs.txt", sep=",", header=None)
	aroma_noise_components_index = aroma_noise_components - 1
	aroma_noise = aroma_mix.iloc[:,aroma_mix.index.isin(aroma_noise_components_index)]
	aroma_noise_matrix = aroma_noise.values
	demean_mov = aroma_noise_matrix - aroma_noise_matrix.mean(axis=0)
else:
	mov = np.genfromtxt(sys.argv[3])
	demean_mov = mov - mov.mean(axis=0)

if GSR_bool == 1:
	gs = np.genfromtxt("Nuisance_regression/GSR.1D")
	demean_gs = gs - gs.mean(axis=0)
	dim_phys = len(wm.shape)
	if dim_phys == 1:
		nuisances = np.concatenate((demean_mov, demean_wm[:,None], demean_csf[:,None], demean_gs[:,None]), axis=1)
	else:
		nuisances = np.concatenate((demean_mov, demean_wm, demean_csf, demean_gs[:,None]), axis=1)
else:
	dim_phys = len(wm.shape)
	if dim_phys == 1:
		nuisances = np.concatenate((demean_mov, demean_wm[:,None], demean_csf[:,None]), axis=1)
	else:
		nuisances = np.concatenate((demean_mov, demean_wm, demean_csf), axis=1)

nuisances_file = os.path.join(sys.argv[6], 'Confounds.1D')
np.savetxt(nuisances_file, nuisances, fmt=str('%0.8f'), delimiter=' ')