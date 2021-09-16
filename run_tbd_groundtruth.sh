#!/bin/bash

# Provide the scenario ID as a command-line parameter
# (e.g., `./run_tbd_groundtruth.sh scenario_1`)
scenario=$1

# TODO: Set the number of iterations of a given history PMF
num_iters=100

# TODO: Update root directory for input and output
root_dir="/home/tamert/isorc20_journal"

# TODO: Update path to the TBD executable
exe="/home/tamert/opencv/build/bin/example_gpu_tbd"

# Paths to input files
rgb_dir="${root_dir}/carla_results/$scenario/rgb/"
pedestrian_bbox="${root_dir}/carla_results/$scenario/pedestrian_bboxes_${scenario}_vis.txt"
vehicle_bbox="${root_dir}/carla_results/$scenario/vehicle_bboxes_${scenario}_vis.txt"

# Tracking output log file names
pedestrian_out="pedestrian_tracking_${scenario}_vis.txt"
vehicle_out="vehicle_tracking_${scenario}_vis.txt"

# Run everything
declare -a distArray=("1" "0,1" "0,0,1" "0,0,0,1" "8,2" "5,4,1" "900,90,9,1" "80,2,2,16")
declare -a distStrArray=("p1" "p2" "p3" "p4" "p8p2" "p5p4p1" "p900p90p9p1" "p80p2p2p16")

for i in "${!distArray[@]}"; do
    dist=${distArray[$i]}
    diststr=${distStrArray[$i]}
    echo $dist $diststr

    outdir="${root_dir}/tracking_results/${scenario}/${diststr}"
    mkdir -p $outdir

    # Only do the repetitions for PMFs with more than one possible value
    num_vals_in_PMF=`echo "${diststr}" | tr -cd 'p' | wc -c`
    if [ $num_vals_in_PMF -eq 1 ];
    then
        iters=1
    else
        iters=$num_iters
    fi

    # Run tracking-by-detection
    $exe --folder $rgb_dir \
         --history_distribution $dist \
         --pedestrian_bbox_filename $pedestrian_bbox \
         --vehicle_bbox_filename $vehicle_bbox \
         --write_tracking true \
         --pedestrian_tracking_filepath "$outdir/${pedestrian_out}" \
         --vehicle_tracking_filepath "$outdir/${vehicle_out}" \
         --write_video false \
         --num_tracking_iters $iters \
         --num_tracking_frames 300
done