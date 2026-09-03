# CMPE/SE 187 Lab — Testing a Robot Navigation Controller

You are testing a robot. You will not write any code, and you will not read the
robot's code. You choose test inputs, run a real simulation, and report what you
found — the same job you would do against any black box with a written
specification.

Everything runs in your browser. There is nothing to install.

---

## 1. What you are testing

A robot must drive from a start position to a target position inside a square
arena without hitting anything. It carries:

- a three-beam range sensor looking forward and ±25°. **Its range depends on the
  robot** — a bigger, faster platform carries a longer-range sensor, as real ones
  do. The smallest robots see 0.5 m; the largest see about 1.9 m.
- position and heading sensors.

It has **no map**. It steers toward the goal and turns away from whatever the
three beams happen to see. That is the entire design, and it is all you need in
order to predict where it will struggle.

You choose the robot and the arena. The navigation logic, the sensor design and
the requirements are identical for every robot — what changes is the machine:

| Robot | Width | Turns on the spot? |
|---|---|---|
| e-puck | 7 cm | yes |
| TurtleBot3 Burger | 21 cm | yes |
| TurtleBot3 Waffle | 31 cm | yes |
| Pioneer 3-DX | 44 cm | yes |
| Clearpath Jackal | 66 cm | yes |
| Clearpath Husky | 80 cm | yes |
| Car-like, small | 7 cm | **no** — steered front wheel |
| Car-like, large | 44 cm | **no** — steered front wheel |

The two car-like robots exist so you can separate *size* from *steering type*. If
only one existed you could never tell which of the two caused a failure.

The arena is square and you set its side length, from 1 m to 6 m. Every scenario
scales with it, so a bigger arena is the same course with more room — except the
corridor gap, which is an absolute width you set yourself.

## 2. The requirements

| ID | The robot shall… |
|---|---|
| REQ-1 | reach the target (centre within 0.10 m) before the time limit elapses |
| REQ-2 | not collide with any obstacle or arena wall |
| REQ-3 | keep at least 0.03 m clearance from every obstacle and wall, for the whole run |
| REQ-4 | remain inside the arena at all times |
| REQ-5 | accept only documented input ranges, and reject anything else *without running a test* |

You do not get to change these. A test that "fails" because you disagree with a
requirement is not a finding. A test that fails because the robot cannot meet a
requirement using legal inputs **is**.

## 3. The inputs you control

| Input | Range |
|---|---|
| Robot | eight platforms, see above |
| Arena size | 1.0 … 6.0 m |
| Scenario | OPEN_FIELD, SINGLE_OBSTACLE, CORRIDOR, DOGLEG, CLUTTER |
| Wheel speed | 0.5 … 6.28 rad/s |
| Start X, Start Y | −3.0 … 3.0 m, **but must fit inside your arena with your robot** |
| Start heading | −180 … 180° |
| Goal X, Goal Y | −3.0 … 3.0 m, same restriction |
| Obstacle X, Y | −0.85 … 0.85 m (SINGLE_OBSTACLE only) |
| Corridor width | 0.10 … 5.0 m (CORRIDOR only) |
| Sensor noise | 0 … 0.5 |
| Max execution time | 5 … 120 s |
| Noise seed | 1 … 999999 |

---

## 4. Setup (about five minutes, once)

1. Go to **https://www.mathworks.com/academia/tah-portal/san-jose-state-university-31511582.html**
   and click *Sign in to get started*. Use your SJSU login. This links you to the
   campus MATLAB licence — it is free for you.
2. Open **https://matlab.mathworks.com** — this is MATLAB in your browser.
3. Click into the **Command Window** and paste this one line, then press Enter:

   ```
   websave('getlab.m','https://raw.githubusercontent.com/ganeshsjsu/webots-testing-lab/main/matlab/getlab.m'); getlab
   ```

   It downloads the lab and runs a self-check. You should see three lines
   reporting a PASS, a FAIL and a REJECTED case.
4. Now start the lab:

   ```
   testlab
   ```

A window opens with the test inputs on the left and the arena on the right.
That is the only thing you need for the rest of the lab.

**If step 3 fails**, check you are signed in with your SJSU account and try
again. Do not install anything.

## 5. Running a test

1. Set the inputs on the left.
2. Press **Run test**.
3. Watch the robot. The title shows the elapsed time and current clearance.
4. Read the **Result** panel: the verdict, then each requirement with its own
   pass or fail and the measurement behind it.
5. Every run is added to the **Test log**. **Download log as CSV** exports it.

Press **Restore defaults** to get back to a known state between experiments.

---

## 6. What to test

Work through all five tasks. Record every run — the log does most of this for
you, but the log cannot record *what you expected*, and that is the part that
matters.

**Task 1 — Equivalence partitioning, and what an input actually means.**
In OPEN_FIELD, a 2 m arena and a 30 s limit, find the wheel speed at which the
e-puck flips from FAIL to PASS. Then find the same boundary for the
**Pioneer 3-DX**. The two numbers are very different. Explain why, given that
both robots were sent the same input.

**Task 2 — Boundary value analysis across robots.**
Set the arena to 3.5 m so every robot fits, use CORRIDOR at 4.0 rad/s and a 60 s
limit, and find the narrowest gap that passes **every** requirement for three
robots of your choice — including at least one car-like one. Tabulate the
results against the robots' widths. One robot gets through a gap narrower than
its wider sibling needs; find it and explain it.

**Task 3 — Input validation (REQ-5).**
Find **four** inputs the system rejects, and record the exact message. At least
one must be rejected because of a *combination* that is individually legal —
each value inside its own documented range, but illegal together.

**Task 4 — Reproducibility.**
Set **Sensor noise to 0.2** first; with noise at 0 the seed does nothing. Run the
same case twice with the same seed, then again changing only the seed. Report
what stayed identical and what did not, and why a tester should care.

**Task 5 — Find the smallest arena that works.**
Pick a large robot and SINGLE_OBSTACLE. Find the smallest arena in which it can
satisfy every requirement. Report how you searched, not just the answer — a
linear scan and a binary search cost very different numbers of runs.

**Task 6 — Find a test that can never pass.**
Find a robot and scenario that fail at **every** legal wheel speed, in any arena
you are willing to try. Show enough runs to make the claim credible. Then answer:
is that a defect in the robot, or a requirement that is not achievable on that
hardware? Justify it. There is a defensible case either way and the reasoning is
what is marked.

---

## 7. What to submit

1. **A screen recording** (3–5 minutes) showing at least one PASS and one FAIL,
   with you saying what you expected before each run and what happened.
   - macOS: Shift-Cmd-5. Windows: Win-Alt-R. Or any tool you like.
2. **Your test log CSV**, exported from the lab.
3. **A short report** (2–3 pages) with a table of your test cases — ID, the
   requirement it targets, the technique it comes from, every input value, your
   expected result, the actual result, and the verdict — plus your answers to
   the five tasks.

A failing test is only a finding if someone else can reproduce it. Always record
the seed.

---

## 8. Things worth knowing before you start

- The failures are **not** planted bugs. They are the real limits of a robot
  with 0.5 m of forward vision, no map, and no memory of where it has been. Your
  job is to find and describe those limits, not to hunt for sabotage.
- A run can fail more than one requirement at once, and the reason line lists
  all of them.
- Speed and success are **not** related in the way you expect. See Task 5.
