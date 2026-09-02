"""test_supervisor - the test oracle.

Everything the student sees as a "result" is produced here.  The Supervisor is
deliberately separate from the robot controller: it configures the world, it
observes ground truth from the scene tree, and it decides pass/fail.  The
controller under test has no way to influence the verdict except by driving the
robot.

Two modes:

  interactive  (default)  Talks to the Robot Window over the Webots wwi
                          channel.  Receives parameters, runs one test,
                          streams back live telemetry and a verdict.

  batch                   Set the environment variable LAB_BATCH to a JSON
                          file containing a list of parameter dicts.  Every
                          case is executed, the results are written to
                          LAB_RESULTS (default results/batch_results.json) and
                          Webots quits.  This is what tools/run_matrix.py uses
                          to verify before class that the parameter space
                          really contains passing and failing cases.
"""

import json
import math
import os
import sys

from controller import Supervisor

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lab_spec as spec  # noqa: E402


# ---------------------------------------------------------------------------
# Geometry helpers.  All obstacles are axis-aligned boxes, which keeps the
# oracle exact and explainable - a student can recompute any number by hand.
# ---------------------------------------------------------------------------

def clearance_to_box(px, py, cx, cy, sx, sy):
    """Surface-to-surface distance from the robot body to an axis-aligned box.

    Negative means the bodies overlap.
    """
    dx = abs(px - cx) - sx / 2.0
    dy = abs(py - cy) - sy / 2.0
    if dx > 0.0 and dy > 0.0:
        distance = math.hypot(dx, dy)
    else:
        distance = max(dx, dy)
    return distance - spec.ROBOT_RADIUS


def clearance_to_cylinder(px, py, cx, cy, radius):
    """Surface-to-surface distance from the robot body to an upright cylinder."""
    return math.hypot(px - cx, py - cy) - radius - spec.ROBOT_RADIUS


def clearance_to_item(px, py, item):
    if item["shape"] == "cylinder":
        return clearance_to_cylinder(px, py, item["x"], item["y"], item["radius"])
    return clearance_to_box(px, py, item["x"], item["y"], item["sx"], item["sy"])


def clearance_to_walls(px, py):
    """Surface-to-surface distance from the robot body to the nearest arena wall."""
    return (spec.ARENA_HALF - max(abs(px), abs(py))) - spec.ROBOT_RADIUS


class TestLab:
    def __init__(self):
        self.robot = Supervisor()
        self.timestep = int(self.robot.getBasicTimeStep())

        self.epuck = self.robot.getFromDef("EPUCK")
        if self.epuck is None:
            raise RuntimeError("DEF EPUCK not found in the world.")
        self.epuck_translation = self.epuck.getField("translation")
        self.epuck_rotation = self.epuck.getField("rotation")
        self.epuck_custom_data = self.epuck.getField("customData")

        self.goal_marker = self.robot.getFromDef("GOAL_MARKER").getField("translation")

        self.movables = {}
        for name in ["OBS0", "OBS1", "OBS2", "OBS3", "OBS4", "OBS5"]:
            node = self.robot.getFromDef(name)
            if node is None:
                raise RuntimeError(f"DEF {name} not found in the world.")
            self.movables[name] = {
                "node": node,
                "translation": node.getField("translation"),
                "sizes": [],
            }
        for name in ["WALL_A", "WALL_B"]:
            node = self.robot.getFromDef(name)
            shape_box = self.robot.getFromDef(name + "_BOX")
            bound_box = self.robot.getFromDef(name + "_BB")
            if node is None or shape_box is None or bound_box is None:
                raise RuntimeError(
                    f"DEF {name} / {name}_BOX / {name}_BB not found in the world.")
            self.movables[name] = {
                "node": node,
                "translation": node.getField("translation"),
                "sizes": [shape_box.getField("size"), bound_box.getField("size")],
            }

        self.run_counter = 0

    # -- world configuration -------------------------------------------------

    def park_all(self):
        for item in self.movables.values():
            item["translation"].setSFVec3f([0.0, 0.0, spec.PARKED_Z])

    def place(self, items):
        """Place the scenario obstacles; returns the list used by the oracle."""
        self.park_all()
        for item in items:
            movable = self.movables[item["name"]]
            if item["shape"] == "box":
                target = [item["sx"], item["sy"], 0.15]
                for field in movable["sizes"]:
                    if any(abs(a - b) > 1e-9
                           for a, b in zip(field.getSFVec3f(), target)):
                        field.setSFVec3f(target)
            movable["translation"].setSFVec3f(
                [item["x"], item["y"], spec.WALL_HEIGHT_Z])
        return list(items)

    def set_robot_pose(self, x, y, heading_deg):
        theta = math.radians(heading_deg)
        self.epuck_translation.setSFVec3f([x, y, 0.0])
        self.epuck_rotation.setSFRotation([0.0, 0.0, 1.0, theta])
        self.epuck.resetPhysics()

    def set_controller_config(self, payload):
        self.epuck_custom_data.setSFString(json.dumps(payload))

    # -- the test run --------------------------------------------------------

    def execute(self, params, on_sample=None):
        """Run one configured test and return the result dict.

        `params` must already be validated.  `on_sample` is an optional callback
        used in interactive mode to stream telemetry to the Robot Window.
        """
        self.run_counter += 1
        run_id = self.run_counter

        items = spec.layout(params)

        # 1. Quiesce the robot before touching the world, so no residual wheel
        #    command survives into the next test.
        self.set_controller_config({"active": False, "run_id": run_id})
        for _ in range(3):
            if self.robot.step(self.timestep) == -1:
                return None

        # 2. Configure the arena and the robot's initial condition.
        placed = self.place(items)
        self.goal_marker.setSFVec3f([params["goal_x"], params["goal_y"], 0.001])
        self.set_robot_pose(params["start_x"], params["start_y"],
                            params["start_heading_deg"])
        if self.robot.step(self.timestep) == -1:
            return None

        # 3. Hand the inputs to the controller and start the clock.
        self.set_controller_config({
            "active": True,
            "run_id": run_id,
            "speed": params["speed"],
            "goal_x": params["goal_x"],
            "goal_y": params["goal_y"],
            "sensor_noise": params["sensor_noise"],
            "seed": int(params["seed"]),
        })

        start_time = self.robot.getTime()
        max_time = params["max_time"]

        min_clearance = float("inf")
        min_clearance_at = None
        min_clearance_object = None
        path_length = 0.0
        previous = None
        goal_reached = False
        collision = False
        collision_object = None
        left_arena = False
        completion_time = None
        samples = 0

        while True:
            if self.robot.step(self.timestep) == -1:
                return None
            samples += 1
            elapsed = self.robot.getTime() - start_time

            position = self.epuck.getPosition()
            px, py = position[0], position[1]

            if previous is not None:
                path_length += math.hypot(px - previous[0], py - previous[1])
            previous = (px, py)

            # Ground-truth clearance against every placed obstacle and the walls.
            clearance = clearance_to_walls(px, py)
            nearest = "arena wall"
            for item in placed:
                candidate = clearance_to_item(px, py, item)
                if candidate < clearance:
                    clearance = candidate
                    nearest = item["name"]
            if clearance < min_clearance:
                min_clearance = clearance
                min_clearance_at = elapsed
                min_clearance_object = nearest

            distance_to_goal = math.hypot(params["goal_x"] - px,
                                          params["goal_y"] - py)

            if on_sample is not None and samples % 4 == 0:
                on_sample({
                    "t": round(elapsed, 3),
                    "x": round(px, 4),
                    "y": round(py, 4),
                    "clearance": round(clearance, 4),
                    "distance_to_goal": round(distance_to_goal, 4),
                })

            if clearance <= 0.0:
                collision = True
                collision_object = nearest
                completion_time = elapsed
                break

            if abs(px) > spec.ARENA_HALF or abs(py) > spec.ARENA_HALF:
                left_arena = True
                completion_time = elapsed
                break

            if distance_to_goal <= spec.GOAL_TOLERANCE:
                goal_reached = True
                completion_time = elapsed
                break

            if elapsed >= max_time:
                completion_time = elapsed
                break

        # The final pose is the one at the instant the run ended, taken before
        # the robot is told to stop, so that the reported numbers do not depend
        # on how the robot settles afterwards.
        final = (px, py)
        final_distance = math.hypot(params["goal_x"] - final[0],
                                    params["goal_y"] - final[1])

        # 4. Stop the robot.
        self.set_controller_config({"active": False, "run_id": run_id})
        for _ in range(2):
            if self.robot.step(self.timestep) == -1:
                return None

        return self.judge(params, {
            "run_id": run_id,
            "goal_reached": goal_reached,
            "collision": collision,
            "collision_object": collision_object,
            "left_arena": left_arena,
            "completion_time": round(completion_time, 3),
            "timed_out": (not goal_reached and not collision and not left_arena),
            "min_clearance": round(min_clearance, 4),
            "min_clearance_at": round(min_clearance_at, 3)
            if min_clearance_at is not None else None,
            "min_clearance_object": min_clearance_object,
            "path_length": round(path_length, 4),
            "final_x": round(final[0], 4),
            "final_y": round(final[1], 4),
            "final_distance_to_goal": round(final_distance, 4),
            "obstacles": placed,
        })

    # -- the verdict ---------------------------------------------------------

    @staticmethod
    def judge(params, m):
        """Evaluate the fixed requirements against the measurements."""
        checks = []

        if m["goal_reached"]:
            r1 = ("PASS", f"Goal reached after {m['completion_time']:.2f} s "
                          f"(limit {params['max_time']:.0f} s).")
        elif m["collision"]:
            r1 = ("FAIL", "Run ended in a collision before the goal was reached; "
                          f"still {m['final_distance_to_goal']:.3f} m away.")
        elif m["left_arena"]:
            r1 = ("FAIL", "Robot left the arena before reaching the goal.")
        else:
            r1 = ("FAIL", f"Timed out after {params['max_time']:.0f} s with "
                          f"{m['final_distance_to_goal']:.3f} m still to go.")
        checks.append(("REQ-1", r1[0], r1[1]))

        if m["collision"]:
            r2 = ("FAIL", f"Collided with {m['collision_object']} at "
                          f"t = {m['completion_time']:.2f} s.")
        else:
            r2 = ("PASS", "No contact with any obstacle or wall.")
        checks.append(("REQ-2", r2[0], r2[1]))

        if m["min_clearance"] >= spec.MIN_CLEARANCE_REQUIRED:
            r3 = ("PASS", f"Minimum clearance {m['min_clearance']:.3f} m "
                          f"(required {spec.MIN_CLEARANCE_REQUIRED:.2f} m).")
        else:
            r3 = ("FAIL", f"Minimum clearance {m['min_clearance']:.3f} m at "
                          f"t = {m['min_clearance_at']:.2f} s near "
                          f"{m['min_clearance_object']}, below the required "
                          f"{spec.MIN_CLEARANCE_REQUIRED:.2f} m.")
        checks.append(("REQ-3", r3[0], r3[1]))

        if m["left_arena"]:
            r4 = ("FAIL", f"Robot centre left the arena at "
                          f"({m['final_x']:.3f}, {m['final_y']:.3f}).")
        else:
            r4 = ("PASS", "Robot stayed inside the arena.")
        checks.append(("REQ-4", r4[0], r4[1]))

        checks.append(("REQ-5", "PASS", "All inputs were inside the documented ranges."))

        failed = [c for c in checks if c[1] == "FAIL"]
        verdict = "PASS" if not failed else "FAIL"
        reason = ("All requirements satisfied."
                  if not failed
                  else "; ".join(f"{c[0]}: {c[2]}" for c in failed))

        result = dict(m)
        result["params"] = params
        result["checks"] = [{"id": c[0], "status": c[1], "detail": c[2]}
                            for c in checks]
        result["verdict"] = verdict
        result["reason"] = reason
        return result

    # -- interactive mode ----------------------------------------------------

    def send(self, payload):
        self.robot.wwiSendText(json.dumps(payload))

    def send_spec(self):
        self.send({
            "type": "spec",
            "parameters": spec.PARAMETERS,
            "scenarios": spec.SCENARIOS,
            "requirements": spec.REQUIREMENTS,
            "constants": {
                "robot_radius": spec.ROBOT_RADIUS,
                "arena_half": spec.ARENA_HALF,
                "goal_tolerance": spec.GOAL_TOLERANCE,
                "min_clearance_required": spec.MIN_CLEARANCE_REQUIRED,
                "max_wheel_speed": spec.MAX_WHEEL_SPEED,
                "wheel_radius": spec.WHEEL_RADIUS,
            },
        })

    def interactive(self):
        self.park_all()
        self.set_controller_config({"active": False, "run_id": 0})
        self.send_spec()
        self.send({"type": "status", "state": "idle",
                   "message": "Ready. Choose a scenario and press Run test."})

        while self.robot.step(self.timestep) != -1:
            message = self.robot.wwiReceiveText()
            while message:
                self.handle(message)
                message = self.robot.wwiReceiveText()

    def handle(self, message):
        try:
            request = json.loads(message)
        except ValueError:
            return
        command = request.get("cmd")

        if command == "hello":
            self.send_spec()
            self.send({"type": "status", "state": "idle", "message": "Ready."})
            return

        if command == "reset":
            self.park_all()
            self.set_controller_config({"active": False, "run_id": 0})
            defaults = dict(spec.DEFAULTS)
            self.set_robot_pose(defaults["start_x"], defaults["start_y"],
                                defaults["start_heading_deg"])
            self.goal_marker.setSFVec3f([defaults["goal_x"], defaults["goal_y"], 0.001])
            self.send({"type": "status", "state": "idle",
                       "message": "Arena reset to the initial state."})
            return

        if command == "run":
            params, errors = spec.validate(request.get("params", {}))
            if errors:
                # REQ-5: reject the input, do not execute a test.
                self.send({
                    "type": "rejected",
                    "errors": errors,
                    "checks": [{
                        "id": "REQ-5", "status": "PASS",
                        "detail": "Input rejected before execution, as required.",
                    }],
                    "message": "Input rejected. No test was executed.",
                })
                self.send({"type": "status", "state": "idle",
                           "message": "Input rejected - fix the highlighted values."})
                return

            self.send({"type": "status", "state": "running",
                       "message": "Test running..."})
            result = self.execute(params, on_sample=lambda s: self.send(
                {"type": "sample", "sample": s}))
            if result is None:
                return
            result["type"] = "result"
            self.send(result)
            self.send({"type": "status", "state": "idle",
                       "message": f"Run {result['run_id']} finished: "
                                  f"{result['verdict']}."})

    # -- batch mode ----------------------------------------------------------

    def batch(self, path):
        with open(path) as handle:
            cases = json.load(handle)

        out_path = os.environ.get("LAB_RESULTS", "batch_results.json")
        results = []
        for index, case in enumerate(cases):
            label = case.pop("label", f"case-{index + 1}")
            repeats = int(case.pop("repeats", 1))
            params, errors = spec.validate(case)
            if errors:
                results.append({
                    "label": label, "verdict": "REJECTED",
                    "errors": errors, "params": case,
                })
                print(f"[{label}] REJECTED: {errors}", flush=True)
                continue
            for repeat in range(repeats):
                result = self.execute(params)
                if result is None:
                    break
                result["label"] = label if repeats == 1 else f"{label}#{repeat + 1}"
                results.append(result)
                print(f"[{result['label']}] {result['verdict']} "
                      f"t={result['completion_time']:.2f}s "
                      f"clr={result['min_clearance']:.3f}m "
                      f"goal={result['goal_reached']} "
                      f"col={result['collision']}", flush=True)

        os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
        with open(out_path, "w") as handle:
            json.dump(results, handle, indent=2)
        print(f"WROTE {out_path} ({len(results)} results)", flush=True)
        self.robot.simulationQuit(0)


if __name__ == "__main__":
    lab = TestLab()
    batch_file = os.environ.get("LAB_BATCH")
    if batch_file:
        lab.batch(batch_file)
    else:
        lab.interactive()
