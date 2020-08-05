import os
import matplotlib.pyplot as plt
import sys

redValForTargetType = {"pedestrian":  4,
                       "vehicle":    10}

def doesPixelMatchTarget(color, targetType):
    redVal = round(color[0] * 255)
    return redVal == redValForTargetType[targetType]

def doesRectContainTarget(image, rectangle, targetType):
    for x in range(rectangle[0], rectangle[1] + 1):
        if x < 0 or x >= image.shape[1]:
            continue
        for y in range(rectangle[2], rectangle[3] + 1):
            if y < 0 or y >= image.shape[0]:
                continue

            color = image[y, x, :]
            if doesPixelMatchTarget(color, targetType):
                return True

    return False

def shouldKeepLine(line, semsegFolder, targetType):
    s = line.strip().split("|")
    if len(s) == 0:
        return False

    # Always keep the camera information
    if s[1] == "-1":
        return True

    # Look up the corresponding image
    imagePath = "{0}/{1:08d}.png".format(semsegFolder, int(s[0]))
    image = plt.imread(imagePath)

    xmin, xmax, ymin, ymax = s[2:6]
    rect = (int(xmin), int(xmax), int(ymin), int(ymax))
    return doesRectContainTarget(image, rect, targetType)

def parseFile(inFilepath, semsegFolder, targetType, outFilepath):
    fin = open(inFilepath, 'r')
    fout = open(outFilepath, 'w')

    for line in fin:
        if shouldKeepLine(line, semsegFolder, targetType):
            fout.write(line)

    fin.close()
    fout.close()

if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("Must provide scenario, tracking target type, and starting frame, e.g.:\n",
              "\tpython3 remove_invisible_targets.py scenario_2 vehicle 9624")
        raise Exception()

    scenario, target_type, starting_frame = sys.argv[1], sys.argv[2], sys.argv[3]
    isorc20_dir = os.getcwd()

    semseg_folder = isorc20_dir + "/carla_results/{0}/semseg".format(scenario)
    bbox_infilepath = isorc20_dir + "/carla_results/{0}/{1}_bboxes_{2}.txt".format(scenario, target_type, starting_frame)
    bbox_outfilepath = isorc20_dir + "/carla_results/{0}/{1}_bboxes_{2}_vis.txt".format(scenario, target_type, scenario)

    parseFile(bbox_infilepath, semseg_folder, target_type, bbox_outfilepath)