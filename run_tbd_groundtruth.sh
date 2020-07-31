#!/bin/bash

# Provide the scenario ID as a command-line parameter
# (e.g., `./run_tbd_groundtruth.sh scenario_1`)
scenario=$1

# TODO: Set the number of iterations of a given history PMF
num_iters=100

# TODO: Update directories for input and output
root_dir="/home/tamert/carla/PythonAPI/examples/isorc20"
output_root_dir="/home/tamert/isorc20/tracking_results"

# TODO: Update path to the TBD executable
exe="/home/tamert/opencv/build/bin/example_gpu_tbd"

# Paths to input files
pedestrian_bbox="${root_dir}/$scenario/pedestrian_bboxes_${scenario}_vis.txt"
vehicle_bbox="${root_dir}/$scenario/vehicle_bboxes_${scenario}_vis.txt"
rgb_dir="${root_dir}/$scenario/rgb/"

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

    outdir="${output_root_dir}/${scenario}/${diststr}"
    mkdir -p $outdir

    # Run tracking-by-detection
    $exe --folder $rgb_dir \
         --history_distribution $dist \
         --pedestrian_bbox_filename $pedestrian_bbox \
         --vehicle_bbox_filename $vehicle_bbox \
         --write_tracking true \
         --pedestrian_tracking_filepath "$outdir/${pedestrian_out}" \
         --vehicle_tracking_filepath "$outdir/${vehicle_out}" \
         --write_video false \
         --num_tracking_iters $num_iters \
         --num_tracking_frames 300
done