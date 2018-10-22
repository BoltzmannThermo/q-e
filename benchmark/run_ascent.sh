#!/bin/bash
#BSUB -W 60
#BSUB -U hackathon
#BSUB -nnodes 1
#BSUB -P GEN109
#BSUB -alloc_flags "nvme"
#BSUB -J tio2_exx
#BSUB -o out_test.%J
#BSUB -e out_test.%J
#BSUB -q batch

#modules required
module load gcc/6.4.0
module load cuda/9.2.148
module load pgi/18.7
module load hdf5/1.10.3

#copy to nvme
rootdir=/ccsopen/home/tkurth/NESAP2/q-e
installdir=${rootdir}/buildscripts/install/6.3/p9_v100
benchmarkdir=${rootdir}/benchmark
scratchdir=$(pwd)
mkdir -p ${scratchdir}

#run
cat ${LSB_DJOB_HOSTFILE} | sort | uniq | grep -v login | grep -v batch > host_list
nprocspn=6
nnodes=$(cat host_list | wc -l)
nprocs=$(( ${nnodes} * ${nprocspn} ))

#cp run file
cp ${installdir}/bin/pw.x ${scratchdir}/
cp ${benchmarkdir}/.*.in ${scratchdir}/
cp ${benchmarkdir}/*.UPF ${scratchdir}/

#run
jsrun -n ${nnodes} -g 6 -c 42 -a ${nprocspn} --bind=proportional-packed:7 --launch_distribution=packed stdbuf -o0 ./run_ascent_wrapper.sh $(pwd) |& tee out.tio2.${LSB_JOBID}
