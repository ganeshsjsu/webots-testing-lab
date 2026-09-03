# Instructor answer key — CMPE 187 robot navigation lab

Not for students. Measured by sweeping the parameter space. Verify a sample in
`testlab` before grading, and re-measure if the controller changes.

## Task 1 — wheel speed boundary (OPEN_FIELD, 30 s)

| Robot | Boundary |
|---|---|
| Differential drive | between **3.5** (FAIL) and **3.6** (PASS) |
| Unicycle | between 3.5 and 3.6 — identical |
| Car-like | between 3.5 and 3.6 — identical |

The boundary is the same for all three, and that is the point of the second half
of the task. In an empty arena nothing ever needs to turn sharply, so the
chassis is irrelevant and the only limit is REQ-1 timing: below 3.6 rad/s the
robot cannot cover the 2.26 m diagonal in 30 s. Mark whether they explain *why*
it doesn't move, not just that it doesn't.

## Task 2 — corridor width (4.0 rad/s, 60 s)

| Robot | Narrowest gap passing every requirement |
|---|---|
| Differential drive | **0.19 m** (clearance 0.033 m) |
| Unicycle | 0.19 m (clearance 0.037 m) |
| Car-like | **0.23 m** (clearance 0.035 m) |

The car-like robot needs roughly 4 cm more gap because it cannot line itself up
on the spot — it has to approach the opening on an arc. Below each threshold the
robot often still reaches the goal, so REQ-1 passes while REQ-3 fails; a student
reporting only "it failed" has missed the distinction the task asks for.

## Task 3 — input validation (REQ-5)

Available rejections:

- Wheel speed 99, or 0 — outside [0.5, 6.28]
- Any position outside ±0.85; corridor width outside [0.15, 0.90]
- Max execution time outside [5, 120]
- **Noise seed 2.5** — must be a whole number (not a range violation)
- **Start and goal within 0.10 m** — the run would pass before the robot moved
  (not a range violation)

The task requires one non-range rejection, so the answer must include the
fractional seed or the start/goal proximity check.

## Task 4 — reproducibility

With sensor noise above 0: the same seed reproduces the verdict and the
measurements; changing the seed changes the trajectory and can flip the verdict
near a boundary. With noise at 0 the seed does nothing, which is why the handout
tells them to set it to 0.2.

**Unverified:** I have not measured how far a seed change moves a verdict near a
boundary. Run two or three cases before relying on this for marking.

## Task 5 — faster passes where slower fails

Verdicts at 2.0 / 3.0 / 4.0 / 4.5 / 5.5 / 6.28 rad/s, 90 s limit:

| Robot | SINGLE_OBSTACLE | DOGLEG | CLUTTER |
|---|---|---|---|
| Differential | F F F F **P P** | F F F **P P P** | P P P P P P |
| Unicycle | F F F **P P P** | F F **P P P P** | P P P P P P |
| Car-like | F F F F F F | F F F F F F | F **P P P P P** |

Any row containing a FAIL followed by a PASS answers the task. The cause is
real: after avoiding, the controller drives straight for a fixed **2 seconds**
before resuming goal-seeking, so a slow robot covers less ground in that window
and clips the obstacle it was avoiding. A time-based rule where a distance-based
one was needed — a genuine design defect, and good material for discussion.

CLUTTER on the differential and unicycle robots passes at every speed, so it
cannot answer this task. Redirect anyone who picks it.

## Task 6 — a test that can never pass

**Car-like + SINGLE_OBSTACLE** and **car-like + DOGLEG** fail at every legal
wheel speed. Both are correct answers.

Cause: with a 0.21 m minimum turning radius the robot cannot get around a
0.15 m cylinder while keeping 0.03 m clearance, given only 0.5 m of forward
vision to react with. It is not a timing problem, so raising the limit does not
help — worth checking whether the student tried that.

Both conclusions are defensible and either can earn full marks:

- **A defect** — the controller was designed around a chassis that can pivot,
  and was never adapted for one that cannot. The requirement is achievable with
  better control (a planner, or reacting earlier).
- **An infeasible requirement** — REQ-3 asks for clearance this chassis cannot
  hold with this sensor range at this obstacle size, so the requirement should
  be qualified per robot rather than stated absolutely.

What earns the marks is whether they distinguish *the robot cannot do this* from
*this controller does not do this*, and whether they cite runs rather than
assert. A student who says "the requirement should say which robots it applies
to" has understood something worth understanding.
