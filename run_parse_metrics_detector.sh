#!/bin/bash

# Run everything
declare -a scenarios=("scenario_1" "scenario_2" "scenario_3" "scenario_4")

for i in "${!scenarios[@]}"; do
    scenario=${scenarios[$i]}

    mkdir -p "metrics_results/$scenario"

    # Run parse_metrics_detector.py for each scenario
    python3 parse_metrics_detector.py $scenario "vehicle"
done