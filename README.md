# compneuro-rsfmriproc
Resting State fMRI preprocessing and analysis codes used by the Computational Neuroimaging Lab at Biocruces Bizkaia HRI. 

All the code can be executed using the singularity image "compneuro_img" which recipe is located in singularity_recipes/ . To build the image you need to install first singularity-container (https://singularity.lbl.gov/) and then execute "singularity build compneuro.simg singularity_recipes/compneuro_img"

To run this pipeline, you first need to have a folder with the brain extracted images and a folder with the tissue-priors segmentations. You can use the our pipeline also to a better integration! (https://github.com/ajimenezmarin/compneuro-anatproc)

