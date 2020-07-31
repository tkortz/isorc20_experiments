#!/bin/bash

# Run everything
declare -a scenarios=("scenario_1" "scenario_2" "scenario_3" "scenario_4")
declare -a targets=("pedestrian" "vehicle")

for i in "${!scenarios[@]}"; do
    scenario=${scenarios[$i]}

    mkdir -p "metrics_results/$scenario"

    for j in "${!targets[@]}"; do
        target=${targets[$j]}

        # Run parse_metrics.py for each scenario-target combination
        python3 parse_metrics_groundtruth.py $scenario $target
    done
done