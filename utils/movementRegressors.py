import numpy as np
import os
import sys

def calc_friston_twenty_four(in_file, out_path):
    """
    Method to calculate friston twenty four parameters

    Parameters
    ----------
    in_file: string
        input movement parameters file from motion correction

    Returns
    -------
    new_file: string
        output 1D file containing 24 parameter values

    """

    data = np.genfromtxt(in_file)

    data_squared = data ** 2
    new_data = np.concatenate((data, data_squared), axis=1)

    data_roll = np.roll(data, 1, axis=0)
    data_roll[0] = 0

    new_data = np.concatenate((new_data, data_roll), axis=1)
    data_roll_squared = data_roll ** 2

    new_data = np.concatenate((new_data, data_roll_squared), axis=1)

    new_file = os.path.join(out_path, 'movementRegressors_24.1D')
    np.savetxt(new_file, new_data, fmt=str('%0.8f'), delimiter=' ')
    return len(new_data)

def censor_mat_calc (cols):
	n_outilers = len(cols)
	frames_before = 1
	frames_after = 2

	#put the outliers matrix in a vector form where 1 values are the outliers
	outliers_vec = 0
	for i in range(0,n_outilers):
		outliers_vec = outliers_vec + cols[i]

	extra_indices = []

	#indices = outliers_vec.tolist()
	indices = [i[0] for i in (np.argwhere(outliers_vec >= 1)).tolist()]
	for i in indices:
	  #remove preceding frames
	  if i > 0 :
		  count = 1
		  while count <= frames_before:
			  extra_indices.append(i-count)
			  count+=1
			  
	  #remove following frames
	  count = 1
	  while count <= frames_after:
		  extra_indices.append(i+count)
		  count+=1

	indices = list(set(indices) | set(extra_indices))
	indices = sorted(i for i in indices if i < len(outliers_vec))

	outliers2censor = [0] * (len(outliers_vec))

	for idx in indices:
		outliers2censor[idx] = 1 

	censor_np = np.asarray(outliers2censor)
	censor_mat = (~censor_np.astype(bool)).astype(int)
	return censor_mat
	
def calc_censor_array(FD_file, DV_file, out_path, len_ts):


	if (os.path.exists(FD_file) and os.path.exists(DV_file)) :
		lines_FD = open(FD_file, 'r').readlines()
		rows_FD = [[float(x) for x in line.split()] for line in lines_FD]
		cols_FD = np.array([list(col) for col in zip(*rows_FD)])
		
		lines_DV = open(DV_file, 'r').readlines()
		rows_DV = [[float(x) for x in line.split()] for line in lines_DV]
		cols_DV = np.array([list(col) for col in zip(*rows_DV)])

		cols_with_outliers = np.concatenate((cols_FD, cols_DV))
		censors = censor_mat_calc(cols_with_outliers)
		
	elif (os.path.exists(FD_file) and not(os.path.exists(DV_file))) :
		lines_FD = open(FD_file, 'r').readlines()
		rows_FD = [[float(x) for x in line.split()] for line in lines_FD]
		cols_FD = np.array([list(col) for col in zip(*rows_FD)])
		censors = censor_mat_calc(cols_FD)
		
	elif (not(os.path.exists(FD_file)) and os.path.exists(DV_file)) :
		lines_DV = open(DV_file, 'r').readlines()
		rows_DV = [[float(x) for x in line.split()] for line in lines_DV]
		cols_DV = np.array([list(col) for col in zip(*rows_DV)])
		censors = censor_mat_calc(cols_DV)
		
	else :
		censors = np.ones((len_ts,1),dtype=int)

	return censors
  


def segment_removal(censors_vec):
	censors_new = np.zeros((5,1))

	for idx in range(10,len(censors_vec)+5,5):
		segment = censors_vec[(idx-5):idx]
		if (sum(segment) == len(segment)):
			censors_new = np.append(censors_new,np.ones(len(segment)))
		else:
			censors_new = np.append(censors_new,np.zeros(len(segment)))
			
	new_file = os.path.join(out_path, 'CensoredFrames.1D')
	np.savetxt(new_file, censors_new, fmt=str('%d'))


#Main Function
in_file = "mc/prefiltered_func_data_mcf.par"
FD_file = "Nuisance_regression/motion_outliers_fd.txt"
DV_file = "Nuisance_regression/motion_outliers_dvars.txt"
out_path = "Nuisance_regression"

ts_len = calc_friston_twenty_four(in_file, out_path)
censors = calc_censor_array(FD_file, DV_file, out_path, ts_len)
segment_removal(censors)