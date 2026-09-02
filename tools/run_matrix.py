#!/usr/bin/env python3
"""Run a batch of test cases through Webots without opening the GUI.

This is the instructor's tool.  It is how you verify, before class, that the
parameter space the students are given actually contains meaningful passing and
failing cases - the check the project brief calls for.  It is also a reasonable
CI job: it exits non-zero if the matrix does not contain both outcomes.

    python3 tools/run_matrix.py                       # default matrix
    python3 tools/run_matrix.py --cases my_cases.json
    python3 tools/run_matrix.py --out results/nightly

On Linux without a display, wrap the call in xvfb-run, or let this script do it
(it adds xvfb-run automatically when DISPLAY is unset and xvfb-run exists).

Requires Webots to be installed and WEBOTS_HOME to point at it.
"""

import argparse
import csv
import json
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)
DEFAULT_CASES = os.path.join(HERE, "validation_matrix.json")
WORLD = os.path.join(PROJECT, "worlds", "sw_testing_lab.wbt")


def find_webots():
    home = os.environ.get("WEBOTS_HOME")
    candidates = []
    if home:
        candidates += [os.path.join(home, "webots"),
                       os.path.join(home, "bin", "webots-bin")]
    candidates += [shutil.which("webots") or "",
                   "/usr/local/webots/webots",
                   "/Applications/Webots.app/Contents/MacOS/webots",
                   r"C:\Program Files\Webots\msys64\mingw64\bin\webotsw.exe"]
    for path in candidates:
        if path and os.path.exists(path):
            return path
    sys.exit("Could not find Webots. Set WEBOTS_HOME to your Webots "
             "installation directory.")


def run(cases_path, out_dir, timeout):
    os.makedirs(out_dir, exist_ok=True)
    results_path = os.path.join(out_dir, "results.json")

    env = dict(os.environ)
    env["LAB_BATCH"] = os.path.abspath(cases_path)
    env["LAB_RESULTS"] = os.path.abspath(results_path)
    env.setdefault("PYTHONIOENCODING", "UTF-8")

    command = [find_webots(), "--batch", "--mode=fast", "--no-rendering",
               "--stdout", "--stderr", "--minimize", WORLD]
    if sys.platform.startswith("linux") and not env.get("DISPLAY") \
            and shutil.which("xvfb-run"):
        command = ["xvfb-run", "-a"] + command

    print("Running", len(json.load(open(cases_path))), "cases ...", flush=True)
    proc = subprocess.run(command, env=env, timeout=timeout,
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    log_path = os.path.join(out_dir, "webots.log")
    with open(log_path, "wb") as handle:
        handle.write(proc.stdout)

    if not os.path.exists(results_path):
        sys.stdout.write(proc.stdout.decode("utf-8", "replace")[-4000:])
        sys.exit("\nWebots produced no results file. Full log: " + log_path)

    with open(results_path) as handle:
        return json.load(handle), results_path, log_path


def write_csv(results, path):
    columns = ["label", "verdict", "scenario", "speed", "corridor_width",
               "sensor_noise", "start_heading_deg", "obstacle_x", "obstacle_y",
               "max_time", "completion_time", "min_clearance", "goal_reached",
               "collision", "left_arena", "timed_out", "path_length",
               "final_distance_to_goal", "reason"]
    with open(path, "w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=columns, extrasaction="ignore")
        writer.writeheader()
        for r in results:
            row = dict(r)
            row.update({k: v for k, v in (r.get("params") or {}).items()})
            if r["verdict"] == "REJECTED":
                row["reason"] = " ".join(r.get("errors", []))
            writer.writerow(row)


def summarise(results):
    counts = {"PASS": 0, "FAIL": 0, "REJECTED": 0}
    print()
    header = "%-36s %-8s %8s %9s %s" % ("case", "verdict", "time s",
                                        "min clr m", "reason")
    print(header)
    print("-" * 118)
    for r in results:
        counts[r["verdict"]] = counts.get(r["verdict"], 0) + 1
        if r["verdict"] == "REJECTED":
            reason = " ".join(r.get("errors", []))
            print("%-36s %-8s %8s %9s %s"
                  % (r["label"][:36], "REJECT", "-", "-", reason[:60]))
        else:
            print("%-36s %-8s %8.2f %9.4f %s"
                  % (r["label"][:36], r["verdict"], r["completion_time"],
                     r["min_clearance"], r["reason"][:60]))
    print("-" * 118)
    print("PASS %d   FAIL %d   REJECTED %d   total %d"
          % (counts.get("PASS", 0), counts.get("FAIL", 0),
             counts.get("REJECTED", 0), len(results)))
    return counts


# Exactly reproducible: the verdict and every discrete outcome.
EXACT_KEYS = ["verdict", "goal_reached", "collision", "left_arena", "timed_out"]
# Reproducible within these tolerances.  A long run through a cluttered arena
# is a chaotic trajectory, and the physics engine is not bit-exact across a
# session, so continuous measurements are quoted with a tolerance rather than
# claimed to be identical.  The verdict a student records never moves.
NUMERIC_TOLERANCE = {
    "completion_time": 0.05,   # s
    "min_clearance": 0.002,    # m
    "path_length": 0.010,      # m
}


def check_repeatability(results):
    """Group repeated runs and confirm the verdict and measurements agree."""
    groups = {}
    for r in results:
        label = r.get("label", "")
        if "#" not in label:
            continue
        groups.setdefault(label.split("#")[0], []).append(r)

    problems = []
    for name, runs in sorted(groups.items()):
        first = runs[0]
        exact_ok = all(all(run[k] == first[k] for k in EXACT_KEYS)
                       for run in runs)
        deviations = {}
        for key, tolerance in NUMERIC_TOLERANCE.items():
            spread = max(abs(run[key] - first[key]) for run in runs)
            deviations[key] = spread
        numeric_ok = all(deviations[k] <= NUMERIC_TOLERANCE[k]
                         for k in NUMERIC_TOLERANCE)
        status = "verdict stable" if exact_ok else "VERDICT CHANGED"
        detail = "  ".join("%s max %s" % (k, ("%.4f" % v))
                           for k, v in sorted(deviations.items()))
        print("  %-34s %d runs  %-15s %s%s"
              % (name, len(runs), status, detail,
                 "" if numeric_ok else "   OVER TOLERANCE"))
        if not exact_ok or not numeric_ok:
            problems.append(name)
    return problems


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--cases", default=DEFAULT_CASES,
                        help="JSON file with a list of parameter objects")
    parser.add_argument("--out", default=os.path.join(PROJECT, "results", "matrix"),
                        help="directory for results.json, results.csv and the log")
    parser.add_argument("--timeout", type=int, default=3600,
                        help="seconds before the whole batch is abandoned")
    args = parser.parse_args()

    results, results_path, log_path = run(args.cases, args.out, args.timeout)
    counts = summarise(results)

    print("\nRepeatability groups:")
    diverged = check_repeatability(results)

    csv_path = os.path.join(args.out, "results.csv")
    write_csv(results, csv_path)
    print("\nWrote %s\n      %s\n      %s" % (results_path, csv_path, log_path))

    executed = counts.get("PASS", 0) + counts.get("FAIL", 0)
    failures = []
    if counts.get("PASS", 0) < 3:
        failures.append("fewer than 3 passing cases")
    if counts.get("FAIL", 0) < 3:
        failures.append("fewer than 3 failing cases")
    if counts.get("REJECTED", 0) < 1:
        failures.append("no rejected-input cases")
    if diverged:
        failures.append("repeated runs disagreed beyond tolerance: "
                        + ", ".join(diverged))
    if executed == 0:
        failures.append("no case actually ran")

    if failures:
        print("\nMATRIX CHECK FAILED: " + "; ".join(failures))
        return 1
    print("\nMATRIX CHECK PASSED: the parameter space contains passing cases, "
          "failing cases and rejected inputs, and repeated runs agree.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
