import os
import sys

inputfolder = "tracking_results"
outputfolder = "metrics_results"

def parseArguments(isorc20_dir, scenario, target):
    infolder = isorc20_dir + "/" + inputfolder + "/" + scenario
    filename = target + "_tracking_" + scenario + "_vis.txt"
    outfilename = isorc20_dir + "/" + outputfolder + "/" + scenario + "/" + target + "_metrics.txt"
    return infolder, filename, outfilename

# History distribution names from log files
dists = ["p5p4p1", "p80p2p2p16", "p8p2", "p900p90p9p1", "p1", "p2", "p3", "p4"]

def parseMetricsFromFile(filepath):
    f = open(filepath, 'r')
    
    repeats = []
    firstIter = True
    
    for line in f:
        if line.strip() == "":
            continue
            
        # If the line contains "history", then it's starting a new iteration
        if "history" in line:
            # If this isn't the first iteration, store the results in the
            # repeats list
            if not firstIter:
                repeats.append(metrics)
                
            firstIter = False
        
            metrics = {}
            metrics["TP"] = []
            metrics["FN"] = []
            metrics["FP"] = []
            metrics["GT"] = []
            metrics["IDSW"] = []
            metrics["sum_di"] = []
            metrics["c"] = []
            metrics["FM"] = []
    
        if "scenario" in line:
            s = line.strip().split("|")[1]
            m = s.split(';')
            for pair in m:
                label, num = pair.split(',')
                if label in ["MT", "PT", "ML"]:
                    metrics[label] = int(num)
                else:
                    metrics[label] = float(num)
            continue

        if "object" in line:
            label, num = line.strip().split("|")[-1].split(',')
            if label == "FM":
                metrics[label].append(int(num))

        if "frame" in line:
            s = line.strip().split("|")

            frameNum = s[1]

            m = s[2].split(';')

            for pair in m:
                label, num = pair.split(',')

                if label in metrics:
                    metrics[label].append(float(num))
                
    repeats.append(metrics)

    f.close()
    
    # Get the average metrics across all iterations
    avgMetrics = {}
    for metric in ["A-MOTA", "MOTP"]:
        avgMetrics[metric] = sum([r[metric] for r in repeats]) / len(repeats)
        
    # Also get average FM
    avgMetrics["Avg.FM"] = sum([sum(r["FM"]) / len(r["FM"]) for r in repeats]) / len(repeats)        

    return avgMetrics

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Must provide scenario and tracking target type, e.g.:\n",
              "\tpython3 parse_metrics_groundtruth.py scenario_2 vehicle")
        raise Exception()

    scenario, target = sys.argv[1], sys.argv[2]
    isorc20_dir = os.getcwd()
    infolder, filename, outfilepath = parseArguments(isorc20_dir, scenario, target)

    metricDictByHistory = {}

    outfile = open(outfilepath, 'w')

    for dist in dists:
        filepath = infolder + "/" + dist + "/" + filename

        metrics = parseMetricsFromFile(filepath)
        
        outfile.write("{0:12s}: A-MOTA: {1}, MOTP: {2}, Avg.FM: {3}\n".format(dist, metrics["A-MOTA"], metrics["MOTP"], metrics["Avg.FM"]))

    outfile.close()