# Instructor guide

## What this lab is for

Students practise test design against a real system with a real specification.
The system is a robot navigation controller; the oracle is a Webots Supervisor
that measures ground truth and applies five fixed requirements. Nothing is
mocked, and no defects are seeded — the failures come from the honest limits of
a small reactive controller.

## How the pieces fit together

`controllers/test_supervisor/lab_spec.py` is the single source of truth for
parameters, ranges, scenarios and requirements. The Supervisor validates against
it and also ships it to the Robot Window, which builds its form from it. Change
a range in one place and the form, the validation messages and the documentation
in the UI all follow. There is no second copy to forget.

`controllers/test_supervisor/test_supervisor.py` does four things per run:
quiesce the robot, configure the arena and the initial pose, hand the parameters
to the controller through the robot's `customData` field, then step the
simulation while measuring. It ends the run on goal, collision, exit from the
arena, or timeout, and judges the five requirements.

`controllers/epuck_navigator/epuck_navigator.py` is the software under test. It
reads its parameters from `customData`; a change of `run_id` means "reset all
internal state". Nothing else crosses the boundary, so the controller has no way
to influence the verdict except by driving.

## Design decisions worth knowing

### Why the oracle is geometric, not contact-based

Clearance is computed analytically each time step: distance from the robot
centre to each obstacle's surface, minus the 0.037 m body radius. Obstacles are
axis-aligned boxes and upright cylinders, so a student can recompute any number
in the report by hand. Contact-point queries would have been easier to write and
impossible to check.

### Why 0.03 m and not 0.10 m

An early draft used a 0.10 m clearance requirement. The e-puck's infra-red ring
saturates at 0.07 m, so under that requirement *every* obstacle test failed for
the same uninteresting reason, and the exercise degenerated into observation.
At 0.03 m the requirement is satisfiable at moderate speed in a wide corridor
and violated in a narrow one, which is what makes it worth testing. This is
itself a good discussion: a requirement that no implementation can meet is a
requirements defect, not an implementation defect.

### Why the robot has a time-of-flight sensor

The stock e-puck infra-red ring only rises above its free-space reading within
about 3 cm of a surface in this world. Reactive avoidance at 0.13 m/s is
impossible with that. The real e-puck2 carries a ToF sensor for exactly this
reason, so the world adds a three-beam ToF array (±25° and straight ahead,
500 mm range) in the robot's turret slot.

The infra-red ring is still on the robot but the controller does not read it.
The Webots infra-red model injects its own unseeded noise; reading it made runs
irreproducible. Every sensor the controller does read is noise-free in the world
file, so the only randomness in a run is the noise injected from the seeded
generator.

### Why obstacles are cylinders

With boxes, a single-ray sensor approaching a corner on the diagonal slips past
the corner entirely and sees nothing until contact. That produced a lab in which
every obstacle scenario failed identically. Cylinders always present a surface to
the beam. The corridor barriers are still boxes, because they are approached
across a face.

### Where the speed sensitivity comes from

The steering command passes through a first-order lag with a fixed 0.22 s time
constant, modelling finite actuator and estimator bandwidth. Everything else in
the avoidance loop is distance-based, so the lag is the only term that converts
speed into lost clearance: at 0.02 m/s it costs 5 mm of travel, at 0.13 m/s it
costs 28 mm. That is a real property of real controllers, not a seeded bug.

### Objects are never spawned

Every object any scenario needs exists at world load and is parked at z = −5
when unused. The Supervisor only moves and resizes them. This is the pattern
webots.cloud recommends, and it also makes runs cheap: 49 cases complete in
about 90 seconds headless.

## Verifying before class

```bash
export WEBOTS_HOME=/path/to/webots
python3 tools/run_matrix.py --out results/matrix
python3 tools/make_boundary_report.py
```

`run_matrix.py` exits non-zero unless the matrix produces at least three passing
cases, three failing cases and one rejected input, and unless repeated runs agree
within tolerance (verdicts exactly; completion time within 0.05 s, clearance
within 2 mm, path length within 10 mm). Run it after any change to the
controller, the world or `lab_spec.py`, and regenerate the boundary report so the
documented numbers stay true.

`docs/VALIDATION_CHECKLIST.md` lists what has been verified and what you must
verify yourself before the link goes to a class.

## Suggested assignments

**Assignment 1 — partitions and boundaries (one axis).** Give each student one
input axis: wheel speed in the open field, corridor width, or sensor noise. They
propose equivalence classes before running anything, then bracket each boundary
to a stated precision and report the interval they measured. Marking is on the
justification of the partitions and the discipline of the bracketing, not on
finding a particular number.

**Assignment 2 — requirement-based suite.** Design a suite with at least two
cases per requirement, one expected-pass and one expected-fail, with the expected
result recorded before execution. Report prediction accuracy and explain every
miss. REQ-5 is the interesting one: it is the only requirement about the system's
handling of its own inputs rather than the robot's behaviour.

**Assignment 3 — robustness.** Ten malformed or extreme inputs, ten legal but
hostile ones. Ask for a severity judgement on each result: is a timeout in the
dogleg at 2 rad/s a defect, a documented limitation, or a requirements problem?
There is no single right answer and the argument is the assessment.

**Assignment 4 — reproducibility and reporting.** Students swap failing cases
and try to reproduce each other's results from the written record alone. Anything
that cannot be reproduced is a defect in the *report*, which is usually a more
memorable lesson than any defect in the robot.

## Extending the lab

**A new scenario.** Add an entry to `SCENARIOS` in `lab_spec.py` and a branch in
`layout()` returning `cylinder(...)` and `box(...)` entries. The world already
provides six cylinders (`OBS0`–`OBS5`) and two resizable barriers
(`WALL_A`, `WALL_B`). Nothing else needs to change: the Supervisor places
whatever `layout()` returns and measures against it, and the Robot Window picks
up the new scenario automatically.

**A new parameter.** Add it to `PARAMETERS`. Validation, the form field, the
range hint and the help text all follow. If the controller needs it, add it to
the `customData` payload in `execute()`.

**A second robot.** Prefer a separate world with its own controller over a shared
abstraction. Different robots have different device names, dimensions and sensor
placements, and the Supervisor's geometry constants (`ROBOT_RADIUS` in
`lab_spec.py`) are robot-specific. Do not promise students that any Webots robot
can be dropped in.

**Seeded defects.** Not present by design, and worth keeping that way for a first
offering — the natural limits already generate 18 distinct failures. If you do
want them later, the clean place is a variant of `epuck_navigator.py` selected by
`controllerArgs`, so the unmodified controller stays available as a control.

## Known limitations

- Webots.cloud concurrency at class scale is unverified; see the checklist.
- Continuous measurements are reproducible to a fraction of a millimetre rather
  than bit-exactly. Verdicts and discrete outcomes are exact. A long chaotic
  trajectory plus a physics engine that is not bit-exact across a session makes
  the last digits move; the tolerances in `run_matrix.py` are set well inside
  the margin at which any verdict would change.
- The `CORRIDOR` failure region is not a single interval. At 4.0 rad/s the robot
  fails at 0.15 m by never finding the gap, at 0.25–0.30 m by clipping the wall,
  and at 0.35 m by both. This is realistic and pedagogically useful, but tell
  students to expect it rather than letting them assume monotonicity.
