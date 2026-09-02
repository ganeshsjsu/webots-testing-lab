# Student guide

You are testing a robot navigation controller. You will not read or change its
code. Your job is to design test cases, run them, and report what you found —
the same thing you would do against any black box with a written specification.

## The system under test

A small two-wheeled robot (an e-puck, 7.4 cm across) has to drive from a start
position to a target position inside a 2 m × 2 m arena, avoiding whatever is in
the way. It carries:

- a three-beam time-of-flight sensor looking forward and ±25°, range 500 mm;
- a position sensor and a heading sensor.

It has **no map**. It steers toward the goal and deflects around whatever the
beams happen to see. That is the whole design, and it is all you need to know to
predict where it will struggle.

## The requirements

| ID | Requirement |
|---|---|
| REQ-1 | The robot shall reach the target position (centre within 0.10 m) before the maximum execution time elapses. |
| REQ-2 | The robot shall not collide with any obstacle or arena wall. |
| REQ-3 | The robot shall maintain a clearance of at least 0.03 m from every obstacle and arena wall for the whole run. |
| REQ-4 | The robot shall remain inside the arena at all times. |
| REQ-5 | The system shall accept only documented input ranges and shall reject any out-of-range or malformed input without running a test. |

You do not get to change these. A test that "fails" because you disagree with a
requirement is not a finding; a test that fails because the robot cannot meet a
requirement under some legal input is.

## The inputs you control

| Input | Range | Notes |
|---|---|---|
| Scenario | one of five | Arena layout — see below. |
| Wheel speed | 0.5 … 6.28 rad/s | 6.28 is the motor limit, ≈ 0.129 m/s. |
| Start X, Start Y | −0.85 … 0.85 m | Where the robot begins. |
| Start heading | −180 … 180° | 0° faces +X, 90° faces +Y. |
| Goal X, Goal Y | −0.85 … 0.85 m | Where it must get to. |
| Obstacle X, Obstacle Y | −0.85 … 0.85 m | `SINGLE_OBSTACLE` only. |
| Corridor width | 0.15 … 0.90 m | `CORRIDOR` only. |
| Sensor noise | 0 … 0.5 | 0.10 ≈ 10 mm standard deviation on the range readings. |
| Max execution time | 5 … 120 s | Simulated seconds before a timeout. |
| Noise seed | 1 … 999999 | Same seed ⇒ same run, every time. |

Scenarios:

- **OPEN_FIELD** — empty arena. Isolates navigation and timing.
- **SINGLE_OBSTACLE** — one 0.15 m diameter cylinder wherever you put it.
- **CORRIDOR** — a barrier across the arena with a gap of the width you choose.
- **DOGLEG** — two offset barriers forcing an S-shaped path.
- **CLUTTER** — six fixed obstacles.

## What you get back

Every run reports:

- **Goal reached** — yes/no
- **Collision** — yes/no, and with what
- **Completion time** — simulated seconds
- **Minimum clearance** — closest the robot's body ever came to anything
- **Stayed in arena** — yes/no
- **Path length** and **final distance to goal**
- A **Pass/Fail** verdict, plus one line per requirement saying why

Every run is appended to the test log at the bottom of the window. **Download
CSV** gives you the whole log for your report.

## How to work

**Equivalence partitioning.** Split each input into classes you expect to behave
alike, and test one value from each rather than twenty values from one. For
wheel speed, a sensible first guess is "too slow to finish in time", "comfortable"
and "fast enough to cause trouble". Then check whether the robot agrees with your
partitioning — often it does not, and that is the interesting part.

**Boundary-value analysis.** Once you believe a boundary exists between two
classes, bracket it. If 3.0 rad/s fails and 5.0 rad/s passes, try 4.0, then 3.5,
then 3.75. Report the boundary as an interval you actually measured, not as a
single number you assumed.

Some boundaries can be derived before you run anything. The robot is 0.074 m
wide and REQ-3 wants 0.03 m of clearance on each side, so a corridor narrower
than 0.134 m is impossible in principle. Predict that first, then find where the
*real* limit is, and explain the gap between the two.

**Robustness testing.** Feed the system things it should refuse: a speed of 99, a
speed of `fast`, a goal outside the arena, a fractional seed, a corridor width of
0. A correct system tells you exactly what is wrong and runs nothing. Record
what happened, not just whether it "worked".

Then feed it things it should accept but will struggle with: maximum sensor
noise, a start heading pointing away from the goal, an obstacle right on top of
the goal.

**Requirement-based testing.** For each of REQ-1 to REQ-5, write at least one
test you expect to pass and one you expect to fail, and say why beforehand. Then
run them. A test whose result you predicted correctly teaches you something; so
does one you got wrong, usually more.

## Reporting

For each test case record: an ID, which requirement it targets, the technique it
comes from, every input value, what you expected, what happened, and the verdict.
The CSV export gives you most of that; the columns it cannot know are the ones
that matter — your expected result and your reasoning.

A failing test is a finding only if someone else can reproduce it. Always record
the seed. Two runs with identical inputs and the same seed produce the same
verdict, so if your reader cannot reproduce your failure, one of you has written
down an input wrongly.

## Things worth knowing before you start

- Failures here are **not** planted bugs. They are the natural limits of a
  reactive controller with 0.5 m of forward vision and no memory. Your job is to
  find and characterise those limits, not to hunt for sabotage.
- A run can fail more than one requirement at once, and the reason line lists
  all of them.
- The relationship between speed and success is **not** monotonic in the
  cluttered scenarios. Do not assume that if 2 rad/s and 6 rad/s both pass,
  everything in between does.
