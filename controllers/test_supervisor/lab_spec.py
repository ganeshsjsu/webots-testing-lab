"""Single source of truth for the test lab: parameters, ranges, scenarios and
requirements.

Both the Supervisor (test oracle) and the offline batch runner import this
module, so the documented input ranges and the enforced input ranges can never
drift apart.  The Robot Window also receives this specification at start-up and
builds its form from it, so there is exactly one place to change a range.
"""

# ---------------------------------------------------------------------------
# Physical constants of the world.  These are geometry facts, not tunables.
# ---------------------------------------------------------------------------

ROBOT_RADIUS = 0.037          # e-puck body radius [m]
WHEEL_RADIUS = 0.0205         # e-puck wheel radius [m]
MAX_WHEEL_SPEED = 6.28        # e-puck RotationalMotor maxVelocity [rad/s]

ARENA_HALF = 0.99             # inner face of the arena wall, floorSize 2 x 2,
                              # wallThickness 0.02 [m]
OBSTACLE_RADIUS = 0.075       # OBS0..OBS5 are cylinders [m]
WALL_THICKNESS = 0.05         # corridor barrier thickness in x [m]
WALL_HEIGHT_Z = 0.075         # z of a barrier/obstacle centre so it sits on the floor
PARKED_Z = -5.0               # where unused objects are parked, out of sight

GOAL_TOLERANCE = 0.10         # robot centre within this distance = goal reached [m]

# ---------------------------------------------------------------------------
# Fixed requirements.  Students vary inputs; they do not redefine these.
# ---------------------------------------------------------------------------

# [m] surface-to-surface.  Chosen deliberately: the e-puck proximity sensors
# saturate at 0.07 m, so a clearance requirement much above that could not be
# met by reactive avoidance at all and every obstacle test would fail for the
# same uninteresting reason.  At 0.03 m the requirement is satisfiable at low
# speed and violated at high speed, which is what makes it worth testing.
MIN_CLEARANCE_REQUIRED = 0.03

REQUIREMENTS = [
    {
        "id": "REQ-1",
        "text": "The robot shall reach the target position (centre within "
                f"{GOAL_TOLERANCE:.2f} m) before the maximum execution time elapses.",
    },
    {
        "id": "REQ-2",
        "text": "The robot shall not collide with any obstacle or arena wall.",
    },
    {
        "id": "REQ-3",
        "text": "The robot shall maintain a clearance of at least "
                f"{MIN_CLEARANCE_REQUIRED:.2f} m from every obstacle and arena wall "
                "for the whole run.",
    },
    {
        "id": "REQ-4",
        "text": "The robot shall remain inside the arena at all times.",
    },
    {
        "id": "REQ-5",
        "text": "The system shall accept only documented input ranges and shall "
                "reject any out-of-range or malformed input without running a test.",
    },
]

# ---------------------------------------------------------------------------
# Scenarios.  `params` lists which inputs are meaningful for that scenario;
# the others are still validated but have no effect on the layout.
# ---------------------------------------------------------------------------

SCENARIOS = {
    "OPEN_FIELD": {
        "label": "Open field (no obstacles)",
        "description": "Empty arena. Isolates the navigation and timing behaviour.",
        "extra_params": [],
    },
    "SINGLE_OBSTACLE": {
        "label": "Single obstacle",
        "description": "One 0.15 m diameter cylinder at a position you choose. "
                       "Place it on the straight line from start to goal to "
                       "force avoidance.",
        "extra_params": ["obstacle_x", "obstacle_y"],
    },
    "CORRIDOR": {
        "label": "Corridor / narrow gap",
        "description": "A barrier across the arena with a gap of the width you "
                       "choose. The robot must pass through the gap.",
        "extra_params": ["corridor_width"],
    },
    "DOGLEG": {
        "label": "Dogleg",
        "description": "Two offset barriers that force an S-shaped path.",
        "extra_params": [],
    },
    "CLUTTER": {
        "label": "Clutter (6 obstacles)",
        "description": "Six fixed obstacles scattered across the arena.",
        "extra_params": [],
    },
}

# ---------------------------------------------------------------------------
# Input parameters.  kind is "enum", "float" or "int".
# ---------------------------------------------------------------------------

PARAMETERS = [
    {
        "key": "scenario", "kind": "enum", "default": "SINGLE_OBSTACLE",
        "choices": list(SCENARIOS.keys()),
        "label": "Scenario", "unit": "",
        "help": "Which preconfigured arena layout to test against.",
    },
    {
        "key": "speed", "kind": "float", "default": 5.5,
        "min": 0.5, "max": MAX_WHEEL_SPEED, "step": 0.01,
        "label": "Wheel speed", "unit": "rad/s",
        "help": f"Cruise wheel speed. {MAX_WHEEL_SPEED} rad/s is the e-puck motor "
                f"limit and corresponds to {MAX_WHEEL_SPEED * WHEEL_RADIUS:.3f} m/s.",
    },
    {
        "key": "start_x", "kind": "float", "default": -0.80,
        "min": -0.85, "max": 0.85, "step": 0.01,
        "label": "Start X", "unit": "m", "help": "Initial robot position, X axis.",
    },
    {
        "key": "start_y", "kind": "float", "default": -0.80,
        "min": -0.85, "max": 0.85, "step": 0.01,
        "label": "Start Y", "unit": "m", "help": "Initial robot position, Y axis.",
    },
    {
        "key": "start_heading_deg", "kind": "float", "default": 45.0,
        "min": -180.0, "max": 180.0, "step": 1.0,
        "label": "Start heading", "unit": "deg",
        "help": "Initial robot orientation. 0 deg faces +X, 90 deg faces +Y.",
    },
    {
        "key": "goal_x", "kind": "float", "default": 0.80,
        "min": -0.85, "max": 0.85, "step": 0.01,
        "label": "Goal X", "unit": "m", "help": "Target position, X axis.",
    },
    {
        "key": "goal_y", "kind": "float", "default": 0.80,
        "min": -0.85, "max": 0.85, "step": 0.01,
        "label": "Goal Y", "unit": "m", "help": "Target position, Y axis.",
    },
    {
        "key": "obstacle_x", "kind": "float", "default": 0.0,
        "min": -0.85, "max": 0.85, "step": 0.01,
        "label": "Obstacle X", "unit": "m",
        "help": "SINGLE_OBSTACLE only: centre of the 0.15 m cylinder, X axis.",
    },
    {
        "key": "obstacle_y", "kind": "float", "default": 0.0,
        "min": -0.85, "max": 0.85, "step": 0.01,
        "label": "Obstacle Y", "unit": "m",
        "help": "SINGLE_OBSTACLE only: centre of the 0.15 m cylinder, Y axis.",
    },
    {
        "key": "corridor_width", "kind": "float", "default": 0.40,
        "min": 0.15, "max": 0.90, "step": 0.01,
        "label": "Corridor width", "unit": "m",
        "help": "CORRIDOR only: width of the gap in the barrier. Note that the "
                f"robot is {2 * ROBOT_RADIUS:.3f} m wide.",
    },
    {
        "key": "sensor_noise", "kind": "float", "default": 0.0,
        "min": 0.0, "max": 0.50, "step": 0.01,
        "label": "Sensor noise", "unit": "fraction",
        "help": "Relative Gaussian noise added to every time-of-flight reading. "
                "0.10 gives a standard deviation of 10 mm at a 500 mm full "
                "scale. Reproducible for a given seed.",
    },
    {
        "key": "max_time", "kind": "float", "default": 30.0,
        "min": 5.0, "max": 120.0, "step": 1.0,
        "label": "Max execution time", "unit": "s",
        "help": "Simulated seconds allowed before the run is declared a timeout.",
    },
    {
        "key": "seed", "kind": "int", "default": 1,
        "min": 1, "max": 999999, "step": 1,
        "label": "Noise seed", "unit": "",
        "help": "Seed of the sensor-noise generator. The same seed always "
                "reproduces the same run, which is what makes a failing test "
                "reproducible.",
    },
]

PARAM_BY_KEY = {p["key"]: p for p in PARAMETERS}
DEFAULTS = {p["key"]: p["default"] for p in PARAMETERS}


# ---------------------------------------------------------------------------
# REQ-5: input validation.  Returns (clean_params, errors).
# ---------------------------------------------------------------------------

def validate(raw):
    """Validate a raw parameter dict coming from the Robot Window or a batch file.

    Returns (params, errors).  `errors` is a list of human readable strings; when
    it is non-empty no test run must be started.
    """
    errors = []
    params = {}

    if not isinstance(raw, dict):
        return {}, ["Input is not a parameter object."]

    unknown = sorted(set(raw.keys()) - set(PARAM_BY_KEY.keys()))
    for key in unknown:
        errors.append(f"Unknown parameter '{key}'.")

    for spec in PARAMETERS:
        key = spec["key"]
        if key not in raw or raw[key] is None or raw[key] == "":
            params[key] = spec["default"]
            continue
        value = raw[key]

        if spec["kind"] == "enum":
            text = str(value)
            if text not in spec["choices"]:
                errors.append(
                    f"{spec['label']} ('{key}'): '{text}' is not one of "
                    + ", ".join(spec["choices"]) + "."
                )
                params[key] = spec["default"]
            else:
                params[key] = text
            continue

        try:
            number = float(value)
        except (TypeError, ValueError):
            errors.append(
                f"{spec['label']} ('{key}'): '{value}' is not a number."
            )
            params[key] = spec["default"]
            continue

        if number != number or number in (float("inf"), float("-inf")):
            errors.append(f"{spec['label']} ('{key}'): value is not finite.")
            params[key] = spec["default"]
            continue

        if spec["kind"] == "int":
            if abs(number - round(number)) > 1e-9:
                errors.append(
                    f"{spec['label']} ('{key}'): must be a whole number, got {number}."
                )
                params[key] = spec["default"]
                continue
            number = int(round(number))

        if number < spec["min"] or number > spec["max"]:
            errors.append(
                f"{spec['label']} ('{key}'): {number} is outside the documented "
                f"range [{spec['min']}, {spec['max']}] {spec['unit']}".strip() + "."
            )
            params[key] = spec["default"]
            continue

        params[key] = number

    # Cross-field checks.  These are still input-range checks (REQ-5), not
    # pass/fail rules of the robot under test.
    if not errors:
        import math
        d = math.hypot(params["goal_x"] - params["start_x"],
                       params["goal_y"] - params["start_y"])
        if d < GOAL_TOLERANCE:
            errors.append(
                f"Start and goal are {d:.3f} m apart, which is inside the "
                f"{GOAL_TOLERANCE:.2f} m goal tolerance: the test would pass "
                "before the robot moves. Move them at least "
                f"{GOAL_TOLERANCE:.2f} m apart."
            )

    return params, errors


# ---------------------------------------------------------------------------
# Scenario layout: returns the list of axis-aligned boxes to place.
# Each entry is (def_name, x, y, size_x, size_y).  Objects not listed are parked.
# ---------------------------------------------------------------------------

def cylinder(name, x, y, radius=OBSTACLE_RADIUS):
    return {"name": name, "shape": "cylinder", "x": x, "y": y, "radius": radius}


def box(name, x, y, sx, sy):
    return {"name": name, "shape": "box", "x": x, "y": y, "sx": sx, "sy": sy}


def layout(params):
    """Return the obstacle placement for a validated parameter set.

    Each entry is a dict describing one axis-aligned box or one upright
    cylinder.  Cylinders are used for the free-standing obstacles on purpose:
    a single-ray infra-red sensor can slip past the corner of a box on a
    diagonal approach, which would make every obstacle test fail for a reason
    that has nothing to do with the control logic.
    """
    scenario = params["scenario"]
    items = []

    if scenario == "OPEN_FIELD":
        pass

    elif scenario == "SINGLE_OBSTACLE":
        items.append(cylinder("OBS0", params["obstacle_x"], params["obstacle_y"]))

    elif scenario == "CORRIDOR":
        w = params["corridor_width"]
        # Barrier across x = 0, gap of width w centred on y = 0.
        # Each half spans from the arena wall to the edge of the gap.
        half_a_len = (ARENA_HALF - w / 2.0)          # from y=-ARENA_HALF to y=-w/2
        half_b_len = (ARENA_HALF - w / 2.0)
        ya = -(w / 2.0 + half_a_len / 2.0)
        yb = +(w / 2.0 + half_b_len / 2.0)
        items.append(box("WALL_A", 0.0, ya, WALL_THICKNESS, half_a_len))
        items.append(box("WALL_B", 0.0, yb, WALL_THICKNESS, half_b_len))

    elif scenario == "DOGLEG":
        # Two barriers with openings on opposite sides.
        items.append(box("WALL_A", -0.30, 0.30, WALL_THICKNESS, 1.30))
        items.append(box("WALL_B", 0.30, -0.30, WALL_THICKNESS, 1.30))

    elif scenario == "CLUTTER":
        fixed = [(-0.35, -0.20), (-0.10, 0.35), (0.20, -0.05),
                 (0.15, 0.55), (0.55, 0.20), (-0.55, 0.15)]
        for i, (x, y) in enumerate(fixed):
            items.append(cylinder(f"OBS{i}", x, y))

    return items
