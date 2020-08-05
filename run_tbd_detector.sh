#!/bin/bash

# Provide the scenario ID as a command-line parameter
# (e.g., `./run_tbd_detector.sh scenario_1`)
scenario=$1

# TODO: Set the number of iterations of a given history PMF
num_iters=100

# TODO: Update root directory for input and output
root_dir="/home/tamert/isorc20"

# TODO: Update path to the TBD executable
exe="/home/tamert/opencv/build/bin/example_gpu_tbd"

# Paths to input files
rgb_dir="${root_dir}/carla_results/$scenario/rgb/"
vehicle_bbox="${root_dir}/detector_results/$scenario/vehicle_bboxes_${scenario}_detector.txt"

# Tracking output log file name
vehicle_out="vehicle_tracking_${scenario}_detector.txt"

# Run everything
declare -a distArray=("1" "0,1" "0,0,1" "0,0,0,1" "8,2" "5,4,1" "900,90,9,1" "80,2,2,16")
declare -a distStrArray=("p1" "p2" "p3" "p4" "p8p2" "p5p4p1" "p900p90p9p1" "p80p2p2p16")

for i in "${!distArray[@]}"; do
    dist=${distArray[$i]}
    diststr=${distStrArray[$i]}
    echo $dist $diststr

    outdir="${root_dir}/tracking_results/${scenario}/${diststr}"
    mkdir -p $outdir

    # Run tracking-by-detection
    $exe --folder $rgb_dir \
         --history_distribution $dist \
         --vehicle_bbox_filename $vehicle_bbox \
         --write_tracking true \
         --vehicle_tracking_filepath "$outdir/${vehicle_out}" \
         --write_video false \
         --num_tracking_iters $num_iters \
         --num_tracking_frames 300
done