# Instructor answer key — CMPE 187 robot navigation lab

Not for students. Measured by sweeping the parameter space. Verify a sample in
`testlab` before grading, and re-measure if the controller changes.

## Reference table

Speed boundary: OPEN_FIELD, 2 m arena, 30 s limit.
Corridor: narrowest gap passing every requirement, 4.0 rad/s, 3.5 m arena, 60 s.
Min arena: smallest arena completing SINGLE_OBSTACLE at 5.5 rad/s, 120 s.

| Robot | Width | Speed boundary | Corridor | Min arena |
|---|---|---|---|---|
| e-puck | 0.07 m | 3.0 → **3.1** | 0.24 m | 1.4 m |
| TurtleBot3 Burger | 0.21 m | 1.8 → **1.9** | 0.48 m | 1.1 m |
| TurtleBot3 Waffle | 0.31 m | 1.8 → **1.9** | 0.57 m | 2.8 m |
| Pioneer 3-DX | 0.44 m | 0.6 → **0.7** | 0.74 m | 3.4 m |
| Clearpath Jackal | 0.66 m | does not fit a 2 m arena | 1.05 m | 5.3 m |
| Clearpath Husky | 0.80 m | does not fit a 2 m arena | 1.24 m | 5.6 m |
| Car-like, small | 0.07 m | 3.0 → **3.1** | **0.17 m** | 1.0 m |
| Car-like, large | 0.44 m | 0.6 → **0.7** | 0.88 m | 4.9 m |

## Task 1 — why the speed boundary moves

The boundary **falls** as robots get bigger: 3.1 rad/s for an e-puck, 0.7 for a
Pioneer. Wheel speed is angular, so the ground speed is speed × wheel radius. The
e-puck's wheels are 20.5 mm; the Pioneer's are 97.5 mm, nearly five times larger,
so the same commanded number moves it nearly five times faster.

What to mark: whether they realise the *input* means something different on each
robot, rather than concluding the Pioneer is "better". This is the point of the
task — a test case is not portable just because the numbers transfer.

## Task 2 — corridor width across robots

Roughly proportional to width, with one deliberate exception: the **small
car-like robot passes a 0.17 m gap where the e-puck needs 0.24 m**, despite
being the same size. A differential robot approaching a narrow gap oscillates as
avoidance and goal-seeking alternate, and that weaving costs clearance. The
steered robot cannot weave, so it holds a straighter line through the gap.

Being unable to turn sharply is usually a disadvantage and here it is an
advantage. A student who finds this and explains it has understood something
real. Accept any correct identification; the explanation is what earns the mark.

## Task 3 — input validation (REQ-5)

Single-value rejections: speed outside [0.5, 6.28]; arena outside [1, 6];
positions outside ±3.0; time outside [5, 120]; a fractional noise seed.

Combination rejections — each value legal on its own, illegal together, which is
what the task requires:

- A start or goal that fits the range but puts *that robot* through the wall of
  *that arena* — e.g. Husky, 2 m arena, start (−0.7, −0.7)
- A robot that cannot fit the arena at all — e.g. Husky in a 1 m arena
- A corridor wider than the arena, leaving no barrier
- Start and goal within 0.10 m of each other

## Task 4 — reproducibility

With noise above 0: same seed reproduces the verdict and the measurements;
changing the seed changes the trajectory and can flip a verdict near a boundary.
With noise at 0 the seed does nothing.

**Unverified:** I have not measured how far a seed change moves a verdict near a
boundary. Check two or three cases before relying on it for marking.

## Task 5 — smallest workable arena

See the table. Mark the *method*: a linear scan from 1.0 m in 0.1 m steps is
about 50 runs, a binary search is about 6. Both find the answer; only one shows
they thought about cost, which is a real testing skill.

**One anomaly, unexplained.** The TurtleBot3 Burger manages a 1.1 m arena while
the smaller e-puck needs 1.4 m. I have not worked out why, and I am recording it
rather than hiding it. Do not mark students down for reporting it, and treat any
plausible investigation of it as a good answer.

## Task 6 — a test that can never pass

Reliable answers: **car-like large** fails SINGLE_OBSTACLE and DOGLEG at every
speed in small arenas, and every robot except the e-puck and the small car fails
DOGLEG in a 2 m arena. Any pair backed by runs is acceptable.

Both readings are defensible and either earns full marks:

- **A defect** — the controller is purely reactive with no memory, so in a
  dogleg it grinds along a barrier instead of backing out. A planner would solve
  it, so the robot could meet the requirement.
- **An infeasible requirement** — REQ-3's clearance cannot be held by a chassis
  of that width with that turning circle in an arena that size, so the
  requirement should be stated per robot rather than absolutely.

What earns marks is distinguishing *the robot cannot do this* from *this
controller does not do this*, and citing runs rather than asserting.
