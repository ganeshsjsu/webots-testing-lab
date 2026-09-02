"""epuck_navigator - the software under test.

This is the robot controller that students exercise.  Students never edit this
file; they change the inputs the Supervisor feeds it and observe whether the
resulting behaviour satisfies the fixed requirements.

Sensing
-------
Obstacle sensing is a three-element time-of-flight array (tof_left /
tof_centre / tof_right at +25 deg / 0 deg / -25 deg) reporting distance in
millimetres out to 500 mm.  Position comes from a GPS and heading from an
inertial unit.

The robot also carries the stock e-puck infra-red ring, but this controller
does not use it, for two reasons.  Its useful range in this world is about
3 cm, which is far too short to steer around anything; and the Webots e-puck
infra-red model adds its own unseeded noise, which would make runs impossible
to reproduce exactly.  Every sensor this controller does read is noise-free in
the world file, so the only randomness in a run is the noise injected below
from a seeded generator - which is what makes a failing test reproducible.

Behaviour and its natural limits
--------------------------------
  * Navigation is reactive, not planned.  There is no map and no memory, so a
    symmetric trap can hold the robot until the time limit expires.
  * The steering command passes through a first-order lag with a fixed time
    constant.  This models finite actuator and estimator bandwidth, and it is
    the main reason obstacle avoidance degrades as speed rises: the lag costs a
    fixed amount of *time*, which at high speed is a large amount of *distance*.
  * Sensor noise is injected in the sensing layer from a seeded generator.  The
    same seed always produces the same noise sequence, so a failing test is
    reproducible.  Noise models a degraded sensor; it is not a defect in the
    control logic.

None of these are seeded defects.  They are the ordinary limits of a small
reactive controller, and finding where those limits fall is the point of the
exercise.

Parameters arrive through the robot's `customData` field as a JSON object
written by the Supervisor.  A new `run_id` means "reset all internal state and
start a fresh test run".
"""

import json
import math
import random

from controller import Robot

# --- e-puck facts ----------------------------------------------------------
MAX_WHEEL_SPEED = 6.28        # rad/s, the motor limit
TOF_MAX_MM = 500.0

# --- control tuning (fixed; not exposed to students) ------------------------
HEADING_GAIN = 2.2            # how hard to steer towards the goal bearing
DIFFERENTIAL_FRACTION = 0.55  # share of cruise speed usable for steering
STEER_LAG_SECONDS = 0.22      # first-order lag on the steering command

AVOID_TRIGGER_MM = 300.0      # centre ToF range at which deflection starts
AVOID_HARD_MM = 110.0         # ToF range at which deflection is fully committed
PIVOT_MM = 70.0               # below this, stop cruising and pivot on the spot
AVOID_RELEASE_METRES = 0.16   # how far the robot must travel with a clear path
                              # before the committed turn direction is released.
                              # Distance, not time, so that the steering lag is
                              # the only speed-dependent term in the loop.
LATCH_FLOOR = 0.6             # authority retained while a turn is committed
SIDE_WEIGHT = 0.55            # how much a side beam contributes to urgency
AVOID_AUTHORITY = 1.4         # steering command used when fully committed

BACKOFF_MM = 45.0             # closer than this, reverse out before turning

GOAL_TOLERANCE = 0.10         # must match lab_spec.GOAL_TOLERANCE

TOF_NAMES = ["tof_left", "tof_centre", "tof_right"]


def wrap_angle(a):
    """Wrap an angle to (-pi, pi]."""
    while a > math.pi:
        a -= 2.0 * math.pi
    while a <= -math.pi:
        a += 2.0 * math.pi
    return a


def clamp(value, low, high):
    return low if value < low else (high if value > high else value)


class Navigator:
    def __init__(self):
        self.robot = Robot()
        self.timestep = int(self.robot.getBasicTimeStep())
        self.dt = self.timestep / 1000.0

        self.left_motor = self.robot.getDevice("left wheel motor")
        self.right_motor = self.robot.getDevice("right wheel motor")
        for motor in (self.left_motor, self.right_motor):
            motor.setPosition(float("inf"))
            motor.setVelocity(0.0)

        self.tof = []
        for name in TOF_NAMES:
            device = self.robot.getDevice(name)
            device.enable(self.timestep)
            self.tof.append(device)

        self.gps = self.robot.getDevice("gps")
        self.gps.enable(self.timestep)
        self.imu = self.robot.getDevice("imu")
        self.imu.enable(self.timestep)

        self.run_id = None
        self.config = None
        self.rng = random.Random(0)
        self.steer_state = 0.0
        self.avoid_direction = 0.0
        self.clear_distance = 0.0

    # -- configuration ------------------------------------------------------

    def poll_config(self):
        """Read customData; return True while a run is active."""
        raw = self.robot.getCustomData()
        if not raw:
            return False
        try:
            data = json.loads(raw)
        except ValueError:
            return False
        if not data.get("active"):
            self.config = None
            return False
        if self.config is None or data.get("run_id") != self.run_id:
            # New run: reset every piece of internal state.
            self.run_id = data.get("run_id")
            self.config = data
            self.rng = random.Random(int(data.get("seed", 1)))
            self.steer_state = 0.0
            self.avoid_direction = 0.0
            self.clear_distance = 0.0
        return True

    # -- sensing ------------------------------------------------------------

    def read_sensors(self):
        """Return the three ToF distances in mm with the configured noise applied."""
        noise = float(self.config.get("sensor_noise", 0.0))
        tof = []
        for sensor in self.tof:
            value = sensor.getValue()
            if noise > 0.0:
                value += self.rng.gauss(0.0, noise * TOF_MAX_MM * 0.20)
            tof.append(clamp(value, 0.0, TOF_MAX_MM))
        return tof

    # -- control ------------------------------------------------------------

    def step_control(self):
        cruise = float(self.config["speed"])
        goal_x = float(self.config["goal_x"])
        goal_y = float(self.config["goal_y"])

        position = self.gps.getValues()
        yaw = self.imu.getRollPitchYaw()[2]

        dx = goal_x - position[0]
        dy = goal_y - position[1]
        if math.hypot(dx, dy) <= GOAL_TOLERANCE:
            self.left_motor.setVelocity(0.0)
            self.right_motor.setVelocity(0.0)
            return

        bearing_error = wrap_angle(math.atan2(dy, dx) - yaw)
        steer_goal = clamp(HEADING_GAIN * bearing_error, -1.0, 1.0)

        left_mm, centre_mm, right_mm = self.read_sensors()

        # Only the centre beam decides whether the path ahead is blocked.  The
        # side beams choose which way to go.  Deciding on the minimum of all
        # three would make the robot shy away from a corridor it could safely
        # drive straight through.
        span = AVOID_TRIGGER_MM - AVOID_HARD_MM

        def beam_urgency(distance_mm):
            return clamp((AVOID_TRIGGER_MM - distance_mm) / span, 0.0, 1.0)

        # The centre beam decides whether the path ahead is blocked; the side
        # beams contribute less, so the robot still drives straight through a
        # corridor whose walls it can see but is not heading into.
        urgency = max(beam_urgency(centre_mm),
                      SIDE_WEIGHT * beam_urgency(left_mm),
                      SIDE_WEIGHT * beam_urgency(right_mm))
        # Commit to a turn direction and hold it until the path has been clear
        # for a while.  Without this the robot re-decides every time step and
        # oscillates in front of an obstacle instead of going round it.
        if urgency > 0.0:
            self.clear_distance = 0.0
            if self.avoid_direction == 0.0:
                if left_mm - right_mm > 10.0:
                    self.avoid_direction = 1.0        # more room on the left
                elif right_mm - left_mm > 10.0:
                    self.avoid_direction = -1.0
                else:
                    # Head-on and symmetric.  Commit deterministically so the
                    # run stays reproducible: turn the way the goal lies.
                    self.avoid_direction = 1.0 if bearing_error >= 0.0 else -1.0
        else:
            self.clear_distance += cruise * 0.0205 * self.dt
            if self.clear_distance >= AVOID_RELEASE_METRES:
                self.avoid_direction = 0.0

        # While a turn is committed the robot keeps a floor of avoidance
        # authority even after the beam clears, otherwise it immediately steers
        # back into the obstacle it was going round.
        authority = urgency
        if self.avoid_direction != 0.0:
            authority = max(urgency, LATCH_FLOOR)

        steer_target = clamp(
            (1.0 - authority) * steer_goal
            + authority * AVOID_AUTHORITY * self.avoid_direction, -1.6, 1.6)

        # First-order lag: the command the wheels receive trails the command
        # the logic computed.  This is the dominant speed sensitivity.
        alpha = self.dt / (STEER_LAG_SECONDS + self.dt)
        self.steer_state += alpha * (steer_target - self.steer_state)
        steer = self.steer_state

        # Keep making forward progress while deflecting; a robot that stops
        # dead in front of an obstacle never gets round it.
        forward = cruise * (1.0 - 0.45 * urgency)
        if centre_mm < PIVOT_MM:
            # Too close to keep going forward: pivot on the spot.
            forward = 0.0
            direction = self.avoid_direction if self.avoid_direction != 0.0 else 1.0
            steer = 1.2 * direction

        differential = steer * cruise * DIFFERENTIAL_FRACTION
        left = forward - differential
        right = forward + differential

        if centre_mm < BACKOFF_MM:
            # Nose to nose with something: reverse out before turning again.
            direction = self.avoid_direction if self.avoid_direction != 0.0 else 1.0
            left = -cruise * (0.6 + 0.2 * direction)
            right = -cruise * (0.6 - 0.2 * direction)

        limit = min(cruise * 1.6, MAX_WHEEL_SPEED)
        self.left_motor.setVelocity(clamp(left, -limit, limit))
        self.right_motor.setVelocity(clamp(right, -limit, limit))

    # -- main loop ----------------------------------------------------------

    def run(self):
        while self.robot.step(self.timestep) != -1:
            if self.poll_config():
                self.step_control()
            else:
                self.left_motor.setVelocity(0.0)
                self.right_motor.setVelocity(0.0)


if __name__ == "__main__":
    Navigator().run()
