Project Information
===============

This repository was used for the paper ["The Price of Schedulability in Multi-ObjectTracking: The History-vs.-Accuracy Trade-Off"](https://www.cs.unc.edu/~anderson/papers/isorc20.pdf), presented at ISORC 2020.

Other relevant repositories:

* [CARLA fork](https://github.com/tkortz/carla)
* [CARLA scenario runner fork](https://github.com/Yougmark/scenario_runner/tree/isorc20)
* [Tracking-by-Detection OpenCV Sample](https://github.com/tkortz/opencv)

Some relevant dependencies (see [CARLA build instructions](https://carla.readthedocs.io/en/latest/build_linux/) for more):

* Ubuntu 16.04
* Unreal Engine 4.22
* Python 3.5
* A semi-powerful NVIDIA GPU
* A lot of disk space (30-50GB recommended)

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
* OpenCV with TBD sample: `$OPENCV_DIR`

## 1. Record scenarios

If you want to use our recorded scenario files, skip to [Step (g) Locating the recordings](#g-locating-the-recordings).  If, however, you plan to record the scenarios yourself, read on!

### a) Setup

First, follow the steps to [build CARLA for Linux](https://carla.readthedocs.io/en/latest/build_linux/).

Then, clone our fork of the [CARLA scenario runner repository](https://github.com/Yougmark/scenario_runner/tree/isorc20) and check out the `isorc20` branch.

Finally, you'll need to do some setup:

* [Installing prerequisites](https://github.com/Yougmark/scenario_runner/blob/isorc20/Docs/getting_started.md#installing-prerequisites)
* [Pointing to your CARLA install and running an example scenario](https://github.com/Yougmark/scenario_runner/blob/isorc20/Docs/getting_started.md#running-the-follow-vehicle-example)

### b) Run the server

Now, you're ready to run and record the scenarios for yourself.  First, launch the CARLA server.  With our setup, we use the following commands:

```
cd $CARLA_DIR
./Dist/CARLA_Shipping_0.9.6-23-g89e329b/LinuxNoEditor/CarlaUE4.sh
```

### c) Run the scenario

The following table lists the scenarios we evaluated in our paper, as well as the towns they appear in and the name of the scenario in the `carla-scenario-runner` repository (`$SCENARIO_NAME` below):

| Our Name   	| Town   	| Name in carla-scenario-runner     	|
|------------	|--------	|-----------------------------------	|
| Scenario 1 	| Town 1 	| VehicleTurningRight_1             	|
| Scenario 2 	| Town 3 	| SignalizedJunctionRightTurn_1     	|
| Scenario 3 	| Town 3 	| OppositeVehicleRunningRedLight032 	|
| Scenario 4 	| Town 4 	| SignalizedJunctionLeftTurn_3      	|

To run a scenario, open a second terminal window and navigate to the root directory of this repo and run `scenario_runner.py`:

```
cd $CARLA_SCENARIO_RUNNER_DIR
python3 scenario_runner.py --scenario $SCENARIO_NAME
```

### d) Add pedestrians

From a third terminal window, navigate to the CARLA Python API directory and use `spawn_npc.py` to add pedestrians (you don't need to add vehicles, as they are part of the scenario configuration).  Note that there are no pedestrians present in Scenario 3.

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
~/.config/Epic/CarlaUE4/Saved/4853.rec
~/.config/Epic/CarlaUE4/Saved/6591.rec
~/.config/Epic/CarlaUE4/Saved/7856.rec
```

Note the mapping:

* Scenario 1: 6591.rec
* Scenario 2: 4853.rec
* Scenario 3: 2762.rec
* Scenario 4: 7856.rec

If you did not record your own scenarios, make sure to copy our recordings to this directory.  They can be found in `${CARLA_DIR}/PythonAPI/examples/recorded_scenarios/`.

If instead you did record your own scenarios, be sure to update lines 134-141 of `${CARLA_DIR}/PythonAPI/examples/manual_control_synchronous.py` accordingy.

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

Then, create the folder `${CARLA_DIR}/PythonAPI/examples/isorc20/${SCENARIO_NAME}/` for each scenario you plan to run (e.g., `scenario_1`).  Once the CARLA client has started, navigate to the PythonAPI-examples directory and run the following Python script to enable the synchronous replay:

```
cd $CARLA_DIR/PythonAPI/examples
python3 manual_control_synchronous.py
```

This script will spawn a vehicle (which we'll ignore), and is ready by default to replay scenario 1.  To change scenarios, change line 132 of `manual_control_synchronous.py` to set `$SCENARIO_NAME` accordingly.

Once the vehicle spawns, press `ctrl+p` once to replay the scenario.  This causes the following to occur:

* Enables the display of ground-truth bounding boxes for both vehicles and pedestrians.
* Writes the corresponding ground-truth positions of vehicles and pedestrians to files in the directory `${CARLA_DIR}/PythonAPI/examples/isorc20/${SCENARIO_NAME}/`.
* Outputs one RGB, one depth, and one semantic segmentation image per frame from the camera on the front of the ego vehicle to per-image-type directories in `${CARLA_DIR}/PythonAPI/examples/isorc20/${SCENARIO_NAME}/`.

Note that this step is very slow, as it requires running the server synchronously and outputting a lot of data per frame.  If you're just testing the workflow, you can hit `escape` after a couple of frames to close the client.

## 3. Post-process CARLA output

The images and ground-truth detections outputted by CARLA need to be post-processed.

### a) Remove images from before the replay started

The sensors (e.g., RGB camera) can begin saving images before the replay is entirely set up.  Fortunately, the ground-truth detection files include in the filename the starting frame number, e.g., `vehicle_bboxes_96243.txt`.  Verify that the two detection files have the same starting frame, and then delete any images with a lower frame number from the following three directories:

* `${CARLA_DIR}/PythonAPI/examples/isorc20/${SCENARIO_NAME}/rgb`
* `${CARLA_DIR}/PythonAPI/examples/isorc20/${SCENARIO_NAME}/depth`
* `${CARLA_DIR}/PythonAPI/examples/isorc20/${SCENARIO_NAME}/semseg`

Note that it is possible that the first frame (or few frames) occurred as the ego vehicle was still being placed, so you might need to delete an extra image from each directory, remove the corresponding line(s) from the ground-truth data files (the frame number is the first value in each row), and update the ground-truth data file names.

### b) Filter out fully occluded pedestrians and vehicles

For the ground-truth detections, this means filtering out any that aren't visible to the camera on the ego vehicle.  This is done using the semantic segmentation information (it isn't perfect, but it's a close proxy).  Given a rectangle in 2D image space (the ground-truth detection result), the semantic label of each pixel in the rectangle is checked; if none matches the target type (pedestrian or vehicle), the detection is filtered out.

For each scenario and each target type, update lines 7, 8, and 12 of `remove_invisible_targets.py` in the ISORC '20 experiments repo and run it.  You'll need the starting frame number from the previous step.

```
cd $ISORC_DIR
python3 remove_invisible_targets.py
```

This step will result in one new ground-truth detection file per target type, with a filename like `vehicle_bboxes_scenario_1_vis.txt`.  Note that the processing can take a few minutes, and does not generate output.

## 4. (Optional) Detect vehicles/pedestrians in images

The RGB images in `${CARLA_DIR}/PythonAPI/examples/isorc20/${SCENARIO_NAME}/rgb/` can be used to perform vehicle or pedestrian detection.

```
TODO
```

## 5. Use TBD to track vehicles/pedestrians

We added a sample to OpenCV to perform tracking-by-detection.

First, follow the instructions in our [OpenCV fork](https://github.com/tkortz/opencv) to build our TBD sample.

Then, once the same is built, you can configure the script `run_tbd_groundtruth.sh` in this repository to perform tracking.  You will need to update lines 11, 12, and 15 based on `$CARLA_DIR`, `$ISORC_DIR`, and `$OPENCV_DIR`.

Finally, run the script.  It takes the `$SCENARIO_NAME` from the earlier steps as its only input parameter.

For example:

```
./run_tbd_groundtruth.sh scenario_1
```

By default, it will perform tracking of vehicles and pedestrians for a given scenario 100 times for each PMF in our paper.  The resulting log files will be placed in `${ISORC_DIR}/tracking_results/${SCENARIO_NAME}/${PMF}/${TARGET}_tracking_${SCENARIO_NAME}_vis.txt`, where `$PMF` is one of the eight names listed on line 28 of `run_tbd_groundtruth.sh` and `$TARGET` is one of "pedestrian" or "vehicle".  These log files will be processed in the last step.

## 6. Compute tracking metrics

### Metrics using ground-truth positions

To generate the metrics, as displayed in Tables II and III of our paper for ground-truth "detections", use the `run_parse_metrics_groundtruth.sh` script:

```
./run_parse_metrics_groundtruth.sh
```

The resulting metrics will be located in `${ISORC_DIR}/metrics_results/${SCENARIO_NAME}/${TARGET}_metrics.txt`, again where `$TARGET` is either "pedestrian" or "vehicle".

### Metrics using detected positions

```
TODO
```