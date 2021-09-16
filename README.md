Project Information
===============

This repository was used for the paper ["The Price of Schedulability in Multi-ObjectTracking: The History-vs.-Accuracy Trade-Off"](https://www.cs.unc.edu/~anderson/papers/isorc20.pdf), presented at ISORC 2020.

Since then, it has been extended as part of a journal paper.

Other relevant repositories:

* [CARLA fork](https://github.com/tkortz/carla)
* [CARLA scenario runner fork](https://github.com/tkortz/carla_scenario_runner)
* [Vehicle detector for CARLA images](https://github.com/s-nandi/carla-car-detection)
* [Tracking-by-Detection OpenCV Sample](https://github.com/tkortz/opencv)

Some relevant dependencies (see [CARLA build instructions](https://carla.readthedocs.io/en/latest/build_linux/) for more):

* Ubuntu 16.04
* Unreal Engine 4.22
* Python 3.5
* A semi-powerful NVIDIA GPU
* A lot of disk space (30-50GB recommended)

Note that the [vehicle detector repository](https://github.com/s-nandi/carla-car-detection) has additional dependencies, which include Python 3.6 and CUDA 10.0.  See that repository for more information.

In order to reproduce the results in our paper, the following steps are necessary:
1. Record the scenarios, or use our `.rec` files.
2. Replay each scenario in the CARLA client to generate the ground-truth vehicle/pedestrian detections and RGB, depth, and semantic-segmentation images.  Note that this step takes a long time.
3. Post-process the images and detections from CARLA.
4. (Optional) Process images to detect vehicles/pedestrians.
5. Use our Tracking-by-Detection to track vehicles/pedestrians in each scenario for each history probability-mass function.
6. Process the results to compute tracking metrics.

We now walk through in each step in detail.  These instructions assume the related repositories are in:

* ISORC '20 experiments: `$ISORC_DIR`
* CARLA: `$CARLA_DIR`
* CARLA scenario runner: `$CARLA_SCENARIO_RUNNER_DIR`
* Vehicle detector: `$DETECTOR_DIR`
* OpenCV with TBD sample: `$OPENCV_DIR`

## 1. Record scenarios

If you want to use our recorded scenario files, skip to [Step (g) Locating the recordings](#g-locating-the-recordings).  If, however, you plan to record the scenarios yourself, read on!

### a) Setup

First, follow the steps to [build CARLA for Linux](https://carla.readthedocs.io/en/latest/build_linux/).

Then, clone our fork of the [CARLA scenario runner repository](https://github.com/tkortz/carla_scenario_runner) and check out the `acc-vs-hist-journal` branch.

Finally, you'll need to do some setup:

* [Installing prerequisites](https://github.com/tkortz/carla_scenario_runner/blob/master/Docs/getting_started.md#installing-prerequisites)
* [Pointing to your CARLA install and running an example scenario](https://github.com/tkortz/carla_scenario_runner/blob/master/Docs/getting_started.md#running-the-follow-vehicle-example)

### b) Run the server

Now, you're ready to run and record the scenarios for yourself.  First, launch the CARLA server.  With our setup, we use the following commands:

```
cd $CARLA_DIR
./Dist/CARLA_Shipping_0.9.6-23-g89e329b/LinuxNoEditor/CarlaUE4.sh
```

### c) Run the scenario

The following table lists the scenarios we evaluated in our paper, as well as the towns they appear in and the name of the scenario in the `carla-scenario-runner` repository (`$CARLA_SCENARIO_NAME` below):

| Our Name   	| Town   	| Name in carla-scenario-runner     	|
|------------	|--------	|-----------------------------------	|
| Scenario 1 	| `Town01` 	| VehicleTurningRight_1             	|
| Scenario 2 	| `Town03` 	| SignalizedJunctionRightTurn_1     	|
| Scenario 3 	| `Town03` 	| OppositeVehicleRunningRedLight032 	|
| Scenario 4 	| `Town04` 	| SignalizedJunctionLeftTurn_3      	|
| Scenario 5 	| `Town05` 	| OtherLeadingVehicle_8             	|

To run a scenario, open a second terminal window and navigate to the root directory of this repo and run `scenario_runner.py`:

```
cd $CARLA_SCENARIO_RUNNER_DIR
python3 scenario_runner.py --scenario $CARLA_SCENARIO_NAME
```

### d) Add pedestrians

From a third terminal window, navigate to the CARLA Python API directory and use `spawn_npc.py` to add pedestrians (you don't need to add vehicles, as they are part of the scenario configuration).  Note that there are no pedestrians present in Scenario 3 or Scenario 5.

```
cd $CARLA_DIR/PythonAPI/examples
python3 spawn_npc.py -n 0 -w 400
```

Note that there will be many collisions in positions for pedestrians, but trying to spawn 400 should successfully spawn at least 250, some of which should appear in the scenario.

### e) Control the ego vehicle

From a fourth terminal window, navigate to the scenario-runner directory again and run `manual_control.py` to control the "ego vehicle":

```
cd $CARLA_SCENARIO_RUNNER_DIR
python3 manual_control.py
```

Before moving on to recording the scenario, play around with it a few times.  You can cancel the simulation at any time by hitting `escape` in the client window.  (You might need to kill the scenario_runner process.)  Good luck!

### f) Record the scenario

While controlling the ego vehicle, press `ctrl+r` in the client window to begin recording.  When you are finished, either press `escape` to close the client, or press `ctrl+r` again to end the recording.

The ID of the ego vehicle will be printed to the terminal in which you ran `manual_control.py`.  Make note of this ID, as you'll need it to replay the recorded scenario in the next step.  In the example below, the ID is 2762.

```
Hero ID: 2762
```

### g) Locating the recordings

The recordings should be saved in `~/.config/Epic/CarlaUE4/Saved/`, with the hero agent ID as the filename.  For example, using our pre-recorded scenario files you should have:
```
~/.config/Epic/CarlaUE4/Saved/2762.rec
~/.config/Epic/CarlaUE4/Saved/3698.rec
~/.config/Epic/CarlaUE4/Saved/4853.rec
~/.config/Epic/CarlaUE4/Saved/6591.rec
~/.config/Epic/CarlaUE4/Saved/7856.rec
```

Note the mapping:

* Scenario 1: 6591.rec
* Scenario 2: 4853.rec
* Scenario 3: 2762.rec
* Scenario 4: 7856.rec
* Scenario 5: 3698.rec

If you did not record your own scenarios, make sure to copy our recordings to this directory.  They can be found in `${CARLA_DIR}/PythonAPI/examples/recorded_scenarios/`.

If instead you did record your own scenarios, be sure to update lines 134-143 of `${CARLA_DIR}/PythonAPI/examples/manual_control_synchronous.py` accordingly.

## 2. Replay each scenario to generate ground-truth data and images

Again, first launch the CARLA server (you can leave it running if you just recorded the scenario(s)):

```
cd $CARLA_DIR
./Dist/CARLA_Shipping_0.9.6-23-g89e329b/LinuxNoEditor/CarlaUE4.sh
```

Next, set up the scenario you want to replay using `config.py`, where `$TOWN` comes from the table in [Step 1 (c) above](#c-run-the-scenario).

```
cd $CARLA_DIR/PythonAPI/util
python3 config.py -m $TOWN --w ClearNoon
```

Then, create the folder `${CARLA_DIR}/PythonAPI/examples/isorc20_journal/${SCENARIO_NAME}/` for each scenario you plan to run (e.g., `scenario_1`).  Once the CARLA client has started, navigate to the PythonAPI-examples directory and run the following Python script to enable the synchronous replay:

```
cd $CARLA_DIR/PythonAPI/examples
python3 manual_control_synchronous.py
```

This script will spawn a vehicle (which we'll ignore), and is ready by default to replay Scenario 1.  To change scenarios, change line 132 of `manual_control_synchronous.py` to set `$SCENARIO_NAME` accordingly.

Once the vehicle spawns, press `ctrl+p` once to replay the scenario.  This causes the following to occur:

* Enables the display of ground-truth bounding boxes for both vehicles and pedestrians.
* Writes the corresponding ground-truth positions of vehicles and pedestrians to files in the directory `${CARLA_DIR}/PythonAPI/examples/isorc20_journal/${SCENARIO_NAME}/`.
* Outputs one RGB, one depth, and one semantic segmentation image per frame from the camera on the front of the ego vehicle to per-image-type directories in `${CARLA_DIR}/PythonAPI/examples/isorc20_journal/${SCENARIO_NAME}/`.

Note that this step is very slow, as it requires running the server synchronously and outputting a lot of data per frame.  If you're just testing the workflow, you can hit `escape` after a couple of frames to close the client.

## 3. Post-process CARLA output

The images and ground-truth detections outputted by CARLA need to be post-processed.

### a) Copy the CARLA output to the ISORC experiments directory

The output from CARLA should first be copied to your ISORC experiments directory:

```
cp -r ${CARLA_DIR}/PythonAPI/examples/isorc20_journal/ ${ISORC_DIR}/carla_results/
```

### b) Remove images from before the replay started

The sensors (e.g., RGB camera) can begin saving images before the replay is entirely set up.  For this reason, the ground-truth detection files include in the filename the starting frame number, e.g., `vehicle_bboxes_96243.txt`.  Verify that the two detection files have the same starting frame, and then delete any images with a lower frame number from the following three directories:

* `${ISORC_DIR}/carla_results/${SCENARIO_NAME}/rgb`
* `${ISORC_DIR}/carla_results/${SCENARIO_NAME}/depth`
* `${ISORC_DIR}/carla_results/${SCENARIO_NAME}/semseg`

Note that it is possible that the first frame (or few frames) occurred as the ego vehicle was still being placed, so you might need to delete an extra image from each directory, remove the corresponding line(s) from the ground-truth data files (the frame number is the first value in each row), and update the ground-truth data file names.

### c) Filter out fully occluded pedestrians and vehicles

For the ground-truth detections, this means filtering out any that aren't visible to the camera on the ego vehicle.  This is done using the semantic segmentation information (it isn't perfect, but it's a close proxy).  Given a rectangle in 2D image space (the ground-truth detection result), the semantic label of each pixel in the rectangle is checked; if none matches the target type (pedestrian or vehicle), the detection is filtered out.

The script `run_remove_invisible_targets.sh` will do this processing for you.  It assumes the locations of the semantic segmentation images and the ground-truth data files within `$ISORC_DIR`.

For each scenario, you will need to update line 4 of `run_remove_invisible_targets.sh` to provide the starting frame number from the previous step.  Then, run the script from the ISORC '20 experiments repo.

```
cd $ISORC_DIR
./run_remove_invisible_targets.sh
```

This step will result in one new ground-truth detection file per target type and scenario, with a filename like `vehicle_bboxes_scenario_1_vis.txt`.  Note that the processing can take a few minutes per file.

## 4. (Optional) Detect vehicles/pedestrians in images

The RGB images in `${ISORC_DIR}/carla_results/${SCENARIO_NAME}/rgb/` can be used to perform vehicle detection.  Here is our description from the paper:

_We chose for a detector a state-of-the-art deep-learning model, Faster R-CNN [39], which has been shown to achieve a high level of accuracy.  We used TensorFlow [1] to train a Faster R-CNN model with the Inception v2 feature extractor [24] (that was pre-trained on the COCO dataset [22], [30]) on a small dataset of 2000 images of bicycles, motorbikes, and cars generated from CARLA [8]._

Our trained detector is available in our [Vehicle detector for CARLA images](https://github.com/s-nandi/carla-car-detection) repository.  Make sure to set up [Git Large File Storage](https://git-lfs.github.com/) before cloning the repository.

After cloning, navigate to `$DETECTOR_DIR`, and run `image_detection.py` to perform vehicle detection on a directory of RGB images.  Note that we used the 40k-iteration detector (`detectors-40264`) and a minimum threshold of `0.70` for our evaluation.

```
cd $DETECTOR_DIR
python3 image_detection.py --model_path=full_trained_model/detectors-40264 --images_path=${ISORC_DIR}/carla_results/${SCENARIO_NAME}/rgb --min_threshold=0.70 --output_path=${ISORC_DIR}/detector_results/${SCENARIO_NAME}
```

This program will output the detections to the file `${ISORC_DIR}/detector_results/${SCENARIO_NAME}/rgb_log.txt`.  You should update its name before moving on:

```
mv ${ISORC_DIR}/detector_results/${SCENARIO_NAME}/rgb_log.txt ${ISORC_DIR}/detector_results/${SCENARIO_NAME}/vehicle_bboxes_${SCENARIO_NAME}_detector.txt
```

## 5. Use TBD to track vehicles/pedestrians

We added a sample to OpenCV to perform tracking-by-detection.

First, follow the instructions in our [OpenCV fork](https://github.com/tkortz/opencv) to build our TBD sample.

Then, once the TBD sample is built, you can configure the scripts `run_tbd_groundtruth.sh` and `run_tbd_detector.sh` in `$ISORC_DIR` to perform tracking.  You will need to update lines 11 and 14 of both scripts based on `$ISORC_DIR` and `$OPENCV_DIR`.

Finally, run the scripts.  They take the `$SCENARIO_NAME` from the earlier steps as the only input parameter.

For example, to track based on ground-truth vehicle/pedestrian positions:

```
cd $ISORC_DIR
./run_tbd_groundtruth.sh scenario_1
```

To instead track based on detected vehicle positions (note that this will not track pedestrians):

```
cd $ISORC_DIR
./run_tbd_detector.sh scenario_1
```

By default, these scripts will perform tracking of vehicles (and pedestrians, if using ground-truth data) for a given scenario once for each single-valued PMF in our paper, and 100 times for each PMF in our paper.  The resulting log files will be placed in `${ISORC_DIR}/tracking_results/${SCENARIO_NAME}/${PMF}/`, where `$PMF` is one of the eight names listed on line 27 of `run_tbd_groundtruth.sh` and line 25 of `run_tbd_detector.sh`.  The file names have the following format:

* `${TARGET}_tracking_${SCENARIO_NAME}_vis.txt` if using ground-truth data (where `$TARGET` is one of "pedestrian" or "vehicle")
* `vehicle_tracking_${SCENARIO_NAME}_detector.txt` if using detected positions (no pedestrian detection is currently performed)

These log files will be processed in the last step, next.

## 6. Compute tracking metrics

### a) Metrics using ground-truth positions

To generate the metrics, as displayed in Tables II and III of our paper for ground-truth positions, use the `run_parse_metrics_groundtruth.sh` script:

```
cd $ISORC_DIR
./run_parse_metrics_groundtruth.sh
```

The resulting metrics will be located in `${ISORC_DIR}/metrics_results/${SCENARIO_NAME}/${TARGET}_metrics_groundtruth.txt`, again where `$TARGET` is either "pedestrian" or "vehicle".

### b) Metrics using detected positions

The results from Table IV for deep-learning-based vehicle detections can be computed using the `run_parse_metrics_detector.sh` script:

```
cd $ISORC_DIR
./run_parse_metrics_detector.sh
```

The resulting metrics will be located in `${ISORC_DIR}/metrics_results/${SCENARIO_NAME}/vehicle_metrics_detector.txt`.