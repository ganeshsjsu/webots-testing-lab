# Setting up the lab

Follow this once, before the assignment. You will install two things, download
the lab, and run three test cases that prove your setup works. Budget **30
minutes**, most of it download time.

You do **not** need to set up a server, use Docker, install Ubuntu, or create a
GitHub account. You do **not** need to install any Python packages — the lab
uses only the Python standard library.

| You need | |
|---|---|
| A laptop | Windows 10/11, macOS, or Linux |
| Free disk space | About 2 GB |
| Permission to install an application | On a locked-down machine, see [If you cannot install software](#if-you-cannot-install-software) |

Do the steps in order. Step 1 comes before step 2 on purpose: Webots looks for
Python when it starts a controller, and installing Python first avoids the most
common failure in this whole document.

---

## Step 1 — Make sure you have Python 3

Open a terminal (**Command Prompt** on Windows, **Terminal** on macOS/Linux) and
run:

```
python3 --version
```

On Windows, try `python --version` instead. Anything **3.7 or newer** is fine.

If that printed a version, skip to step 2. If it said the command was not found:

- **Windows** — install from <https://www.python.org/downloads/>. On the very
  first installer screen, **tick "Add python.exe to PATH"** before clicking
  Install. This one checkbox is the difference between the lab working and a
  confusing error later. Close and reopen Command Prompt, then check again.
- **macOS** — install from <https://www.python.org/downloads/>. Afterwards, note
  the path it reports, which looks like
  `/Library/Frameworks/Python.framework/Versions/3.13/bin/python3`. You may need
  it in step 3.
- **Linux** — `sudo apt install python3` (Debian/Ubuntu) or your distribution's
  equivalent.

---

## Step 2 — Install Webots R2025a

Download it from the official release page:

**<https://github.com/cyberbotics/webots/releases/tag/R2025a>**

Scroll to **Assets** and take the file for your system:

| System | File |
|---|---|
| Windows | `webots-R2025a_setup.exe` |
| macOS | `webots-R2025a.dmg` |
| Ubuntu / Debian | `webots_2025a_amd64.deb` — install with `sudo apt install ./webots_2025a_amd64.deb` |
| Other Linux | `webots-R2025a-x86-64.tar.bz2` |

It must be **R2025a**. The lab's world file declares that version in its first
line, and a different Webots will either refuse to open it or convert it and
warn you. Do not take a build from the "nightly" releases.

Launch Webots once to confirm it starts, then close it.

---

## Step 3 — Tell Webots which Python to use

**macOS and Linux users must do this.** Webots runs whatever command `python`
refers to, and on most Macs and Linux systems there is no bare `python` — only
`python3`. When Webots cannot find it, the simulation opens normally but the
robot never moves and the Webots console complains about `python`.

1. Open the preferences dialog:
   - **macOS**: *Webots → Preferences*
   - **Windows / Linux**: *Tools → Preferences*
2. On the **General** tab, find **Python command**. It says `python` by default.
3. Change it to `python3` and click OK.
4. On macOS, if that is still not enough, put the full path there instead — the
   one from step 1, such as
   `/Library/Frameworks/Python.framework/Versions/3.13/bin/python3`.

**Windows users**: leave it as `python`, provided you ticked the PATH box in
step 1.

---

## Step 4 — Download the lab

1. Go to **<https://github.com/ganeshsjsu/webots-testing-lab>**
2. Click the green **Code** button, then **Download ZIP**. No account needed.
3. Unzip it. You will get a folder named `webots-testing-lab-main`.
4. Move that folder somewhere plain — your Documents folder is ideal.

Two things to avoid:

- **Do not rearrange what is inside.** Webots finds the controllers and the
  robot window by their position relative to the world file. Moving or renaming
  the inner folders breaks the lab.
- **Do not run it from inside the ZIP.** On Windows, double-clicking a ZIP shows
  you the contents as if it were a folder; Webots cannot use that. Extract it
  properly first ("Extract All").

---

## Step 5 — Open the world

Start Webots, then *File → Open World…* and choose:

```
webots-testing-lab-main/worlds/sw_testing_lab.wbt
```

You should see a square arena with a small round robot in one corner. The first
open takes longer than later ones while Webots caches its assets.

---

## Step 6 — Open the test window

The controls for the lab are in a **robot window**, not in the 3D view.

1. In the scene tree on the left, find **`test_supervisor`**.
2. Right-click it and choose **Show Robot Window** (double-clicking it also
   works).
3. A panel opens with *Test inputs*, *Requirements under test*, *Result* and
   *Test log*. The badge at the top right should stop saying "Connecting…".

If the panel stays on "Connecting…", see the troubleshooting table below.

---

## Step 7 — Prove your setup works

Run these three cases before you start the assignment. They are chosen so that
each one exercises a different part of the lab, and the expected results are
measured, not guessed — they come from
[MEASURED_BOUNDARIES.md](MEASURED_BOUNDARIES.md).

Click **Restore defaults** before each one.

| # | What to change | Press | Expect |
|---|---|---|---|
| 1 | Scenario → `OPEN_FIELD` | Run test | **PASS**, "goal reached", completion time ≈ 19.7 s |
| 2 | Scenario → `OPEN_FIELD`, Wheel speed → `3.5` | Run test | **FAIL**, "timed out" at 30.00 s |
| 3 | Wheel speed → `99` | Run test | **Rejected** before anything runs: *Wheel speed ('speed'): 99.0 is outside the documented range [0.5, 6.28] rad/s.* |

What each one tells you:

- **Case 1 passing** means Webots, Python, the controller, the supervisor and
  the robot window are all talking to each other. This is the real check.
- **Case 2 failing** is the correct answer, not a broken setup. The robot cannot
  cross the arena in 30 seconds at that speed. If case 2 *passes*, something is
  wrong — check that you changed only the speed.
- **Case 3** shows input validation rejecting bad input without running a
  simulation. That behaviour is itself under test in the assignment (REQ-5).

If all three match, you are set up. Read
[STUDENT_GUIDE.md](STUDENT_GUIDE.md) next.

---

## Troubleshooting

| What you see | What it means | What to do |
|---|---|---|
| Robot window stuck on "Connecting…" | The window opened before the simulation was ready | Press the reload/reset button in the Webots toolbar, then reopen the robot window |
| Simulation opens, robot never moves, console mentions `python` | Webots cannot find Python | Redo step 3. On Windows, redo step 1 with the PATH checkbox ticked |
| Console says a module named `controller` was not found | Webots is starting a Python that is not the one it bundles support for | Set **Python command** to a plain `python3` (step 3) rather than one from a conda or virtual environment |
| A warning about the world file version | You installed the wrong Webots | Install **R2025a** (step 2). Do not save the world if Webots offers to convert it |
| "Show Robot Window" is missing | You right-clicked the robot instead of the supervisor | Right-click **`test_supervisor`**, not `e-puck` |
| Nothing happens when you press Run test | The simulation is paused | Press the play button in the Webots toolbar |
| Every run reports the same result no matter what you change | You edited a field but did not leave it | Click outside the field, or press Tab, before pressing Run test |

### If you cannot install software

On a locked-down machine, ask about a lab computer with Webots already
installed. Steps 4 through 7 need no installation — you only download the ZIP
and open the world.

### If you are still stuck

Do not lose an evening to this. Bring, or send:

- your operating system and version,
- your Webots version (*Help → About*),
- **the text in the Webots console** — the black panel at the bottom of the
  window, which is where the actual error appears,
- what you had already tried.

---

## A note on running it in a browser

You may see a link to <https://webots.cloud> that opens a Webots simulation with
no install at all. That service depends on shared simulation servers that are
not always available, and when none is free it refuses every simulation,
including its own examples. Treat it as a convenience if it happens to work.
**The installed version described above is the supported path for this
assignment.**
