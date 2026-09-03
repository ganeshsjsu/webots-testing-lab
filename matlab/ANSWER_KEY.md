# Instructor answer key — CMPE 187 robot navigation lab

Not for students. Measured by sweeping the parameter space; verify a sample in
`testlab` before grading, and re-run this if the controller changes.

## Task 1 — wheel speed boundary (OPEN_FIELD, 30 s limit, defaults otherwise)

| Speed | Verdict |
|---|---|
| ≤ 3.5 rad/s | FAIL — timed out |
| ≥ 3.6 rad/s | PASS |

The boundary is between **3.5 and 3.6 rad/s**. Below it the robot cannot cover
the 2.26 m diagonal inside 30 s. Accept any adjacent pair that brackets it;
what you are marking is whether they identified the *reason* as REQ-1 timing
rather than anything to do with obstacles.

## Task 2 — corridor width (CORRIDOR, 4.0 rad/s, 60 s limit)

| Width | Verdict |
|---|---|
| ≤ 0.18 m | FAIL |
| ≥ 0.19 m | PASS (clearance 0.033 m, only just above the 0.03 m requirement) |

The boundary is between **0.18 and 0.19 m**. The interesting part is the failure
*mode*: in the failing band the robot still reaches the goal, so REQ-1 passes
and REQ-3 fails. A student who reports "it failed" without naming which
requirement has missed the point of the task.

## Task 3 — input validation (REQ-5)

Rejections available:

- Wheel speed 99, or 0 — outside [0.5, 6.28]
- Any position outside ±0.85
- Corridor width below 0.15 or above 0.90
- Max execution time outside [5, 120]
- **Noise seed 2.5** — must be a whole number (not a range violation)
- **Start and goal within 0.10 m of each other** — the run would pass before the
  robot moved (not a range violation)

The task asks for one rejection that is not a range violation, so the answer
must include the fractional seed or the start/goal proximity check.

## Task 4 — reproducibility

With sensor noise > 0: same seed reproduces the verdict and the measurements
exactly; changing the seed changes the trajectory and can change the verdict
near a boundary. With noise at 0 the seed does nothing, which is why the task
now tells them to set it to 0.2.

**Unverified:** I have not confirmed how far a seed change moves the verdict
near a boundary. Run two or three cases before you rely on this for marking.

## Task 5 — faster passes where slower fails

| Scenario | 2.0 | 3.0 | 4.0 | 4.5 | 5.5 | 6.28 |
|---|---|---|---|---|---|---|
| SINGLE_OBSTACLE | FAIL | FAIL | FAIL | FAIL | PASS | PASS |
| DOGLEG | FAIL | FAIL | FAIL | PASS | PASS | PASS |
| CLUTTER | PASS | PASS | PASS | PASS | PASS | PASS |

Either of the first two rows answers the task. The cause is real rather than a
quirk: after avoiding, the controller drives straight for a fixed **2 seconds**
before resuming goal-seeking, so a slow robot covers less ground in that window
and clips the obstacle it was avoiding. A time-based rule where a
distance-based one was needed — a genuine design defect, and a good thing for
students to reason about.

**Note:** CLUTTER passes at every speed, so it is not a useful scenario for this
task. Steer students to SINGLE_OBSTACLE or DOGLEG if they get stuck.
