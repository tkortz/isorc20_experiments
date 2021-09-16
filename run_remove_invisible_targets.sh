#!/bin/bash

# TODO: update the starting frames for each scenario
declare -a starting_frames=(1425 9624 16247 4023 441959)

# Run everything
declare -a scenarios=("scenario_1" "scenario_2" "scenario_3" "scenario_4" "scenario_5")
declare -a targets=("pedestrian" "vehicle")

for i in "${!scenarios[@]}"; do
    scenario=${scenarios[$i]}
    starting_frame=${starting_frames[$i]}

    for j in "${!targets[@]}"; do
        target=${targets[$j]}

        echo "Removing invisible targets for scenario $scenario and target type $target."

        # Run remove_invisible_targets.py for each scenario-target combination
        python3 remove_invisible_targets.py $scenario $target $starting_frame
    done
done