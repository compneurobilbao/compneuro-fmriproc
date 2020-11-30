#!/bin/bash

img_name=$1

filename_withoutPath=$(basename -- "$img_name")
filename="${filename_withoutPath%%.*}"
TR=$(fslval $img_name pixdim4)

mkdir -p rfSplit
fslsplit ${img_name} rfSplit/frame

count=0
if [ -f Nuisance_regression/Confounds_scrubb.1D ]
then
    rm Nuisance_regression/Confounds_scrubb.1D
else
    touch Nuisance_regression/Confounds_scrubb.1D
fi

while IFS= read -r -u 4 line_f1 && IFS= read -r -u 5 line_f2 
do
    
    slice_name=rfSplit/frame$(printf "%04d" $count)
    
    if [ $line_f1 -eq 0 ]
    then
        rm $slice_name.nii.gz
    else
        echo "$line_f2" >> Nuisance_regression/Confounds_scrubb.1D
    fi
    
    count=$[$count +1]

done 4<Nuisance_regression/CensoredFrames.1D 5<Nuisance_regression/Confounds.1D



cd rfSplit 

fslmerge -tr ../${filename}_scrubb.nii.gz *.nii.gz $TR

cd ..

rm -rf rfSplit
