# Robot Simulation Testing Lab

A browser-accessible Webots lab for an SJSU software-testing class. Students
do not write robot code. They pick a preconfigured scenario, set a small number
of documented test inputs, run a real physics simulation, and read a Pass/Fail
verdict with the measurements behind it.

The robot under test is an e-puck running a small reactive navigation
controller. A Webots Supervisor acts as the test oracle: it configures the
arena, observes ground truth from the scene tree, and decides the verdict
against five fixed requirements. The controller cannot influence the verdict
except by driving the robot.

```
 Robot Window (HTML/JS in the browser)
        │  parameters                       ▲  measurements + verdict
        ▼                                   │
 test_supervisor.py  ── configures arena ──▶ Webots physics
   (Supervisor,          resets robot        │
    test oracle)         measures truth  ◀───┘
        │  customData (run parameters)
        ▼
 epuck_navigator.py  (the software under test)
```

## What a student sees

1. Open a link. No install, no login, no GitHub, no security prompts.
2. Choose one of five arena scenarios.
3. Set inputs: speed, start pose, goal, obstacle position or corridor width,
   sensor noise, time limit, noise seed.
4. Press **Run test**. The 3D simulation runs live in the browser.
5. Read the verdict, the per-requirement checks, and the measurements; the run
   is appended to a test log they can download as CSV.

Out-of-range input is rejected before any simulation starts, with a message
naming the parameter and the legal range. That rejection is itself testable
behaviour, and it is what REQ-5 is about.

## Requirements under test

| ID | Requirement |
|---|---|
| REQ-1 | Reach the target (centre within 0.10 m) before the time limit. |
| REQ-2 | Do not collide with any obstacle or arena wall. |
| REQ-3 | Keep at least 0.03 m clearance from every obstacle and wall. |
| REQ-4 | Stay inside the arena. |
| REQ-5 | Accept only documented input ranges; reject anything else without running a test. |

The clearance figure is deliberate rather than arbitrary — see
[docs/INSTRUCTOR_GUIDE.md](docs/INSTRUCTOR_GUIDE.md#why-003-m-and-not-010-m).

## Does the parameter space contain real failures?

Yes, and they are measured rather than assumed. `tools/run_matrix.py` runs a
49-case matrix headlessly and currently produces **25 passing, 18 failing and
10 rejected-input cases**, with boundaries on four independent axes:

| Axis | Boundary |
|---|---|
| Wheel speed (open field, 30 s limit) | fails at ≤ 3.6 rad/s, passes at ≥ 3.8 rad/s |
| Corridor width (4.0 rad/s) | fails at ≤ 0.35 m, passes at ≥ 0.40 m |
| Sensor noise (single obstacle) | passes at ≤ 0.20, fails at ≥ 0.30 |
| Scenario difficulty | dogleg and clutter fail at low speed, pass at high speed |

Full tables, including the failure *reason* for every case, are in
[docs/MEASURED_BOUNDARIES.md](docs/MEASURED_BOUNDARIES.md).

No defects were seeded. Every failure above is the natural operating limit of a
small reactive controller with short-range sensing and a finite steering
bandwidth.

## Repository layout

```
worlds/sw_testing_lab.wbt              arena, robot, obstacles, supervisor
controllers/epuck_navigator/           the software under test
controllers/test_supervisor/           the test oracle
  lab_spec.py                          parameters, ranges, scenarios, requirements
  test_supervisor.py                   configure / measure / judge, plus batch mode
plugins/robot_windows/test_lab/        the browser UI
tools/run_matrix.py                    headless batch runner and pre-class check
tools/validation_matrix.json           the 49-case validation matrix
tools/make_boundary_report.py          regenerates docs/MEASURED_BOUNDARIES.md
docs/                                  student guide, instructor guide, checklist
webots.yaml                            webots.cloud publication descriptor
```

`lab_spec.py` is the single source of truth. The Robot Window builds its form
from the specification the Supervisor sends it, so the ranges a student sees can
never disagree with the ranges the Supervisor enforces.

## Running it

**In the Webots GUI**

```bash
webots worlds/sw_testing_lab.wbt
```

Then open the Supervisor's robot window (right-click the `test_supervisor`
robot in the scene tree → *Show Robot Window*, or double-click it).

**Headless, for verification or CI**

```bash
export WEBOTS_HOME=/path/to/webots
python3 tools/run_matrix.py --out results/matrix
python3 tools/make_boundary_report.py
```

The runner exits non-zero unless the matrix contains at least three passing
cases, three failing cases and one rejected input, and unless repeated runs
agree within tolerance. It takes about 90 seconds for all 49 cases.

**Publishing to webots.cloud**

Push this repository to GitHub, register it at <https://webots.cloud>, and share

```
https://webots.cloud/run?url=https://github.com/<user>/<repo>/blob/main/worlds/sw_testing_lab.wbt
```

Do not treat that link as classroom-ready until you have worked through
[docs/VALIDATION_CHECKLIST.md](docs/VALIDATION_CHECKLIST.md). A working local
run is not evidence that a public cloud simulation server will hold up for a
class-sized group; that is the one thing this repository cannot verify for you.

## Version pinning

Authored and verified against **Webots R2025a**. The world header
(`#VRML_SIM R2025a utf8`) and the `RobotWindow.js` import in the Robot Window
both name that version; change them together. There is intentionally no
`Dockerfile` — see [docs/DOCKER_IMAGE.md](docs/DOCKER_IMAGE.md).

## Reproducibility

The controller reads only noise-free sensors, and the sensor noise a student
dials in comes from a generator seeded by the `seed` input, so a failing test
can be handed to someone else and reproduced. `WorldInfo.randomSeed` is pinned.
Verdicts and every discrete outcome reproduce exactly; continuous measurements
reproduce to a fraction of a millimetre. The evidence is in the repeatability
table of [docs/MEASURED_BOUNDARIES.md](docs/MEASURED_BOUNDARIES.md).

## Documentation

- [docs/STUDENT_GUIDE.md](docs/STUDENT_GUIDE.md) — hand this to students.
- [docs/INSTRUCTOR_GUIDE.md](docs/INSTRUCTOR_GUIDE.md) — design decisions, how to
  extend the lab, suggested assignments.
- [docs/VALIDATION_CHECKLIST.md](docs/VALIDATION_CHECKLIST.md) — what must be
  verified before the link goes to a class, and what has already been verified.
- [docs/MEASURED_BOUNDARIES.md](docs/MEASURED_BOUNDARIES.md) — generated results.
