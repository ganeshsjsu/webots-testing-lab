function s = labspec()
%LABSPEC  Single source of truth for the test lab.
%   Constants, the five requirements, the five scenarios and every input
%   parameter with its documented range.  Ported from lab_spec.py; the ranges
%   here and the ranges LABVALIDATE enforces cannot drift apart because they
%   are the same table.

% --- geometry facts, not tunables ---------------------------------------
s.ROBOT_RADIUS   = 0.037;    % default (e-puck) body radius [m]; per-robot below
s.WHEEL_RADIUS   = 0.0205;   % default (e-puck) wheel radius [m]
s.TRACK_WIDTH    = 0.052;    % default (e-puck) axle length [m]
s.MAX_WHEEL_SPEED= 6.28;     % motor limit [rad/s]
s.ARENA_HALF     = 0.99;     % inner face of the arena wall [m]
s.OBSTACLE_RADIUS= 0.075;    % free-standing cylinders [m]
s.WALL_THICKNESS = 0.05;     % corridor barrier thickness [m]
s.GOAL_TOLERANCE = 0.10;     % centre within this = goal reached [m]
s.SENSOR_RANGE   = 0.50;     % time-of-flight full scale [m]
s.SENSOR_ANGLES  = [-25 0 25]*pi/180;   % three beams, forward and +/-25 deg
s.WHEELBASE      = 0.12;     % CAR_LIKE front-to-rear axle [m]
s.MAX_STEER      = pi/6;     % CAR_LIKE steering limit -> 0.21 m turning radius

% Deliberate: the sensors saturate at short range, so a clearance requirement
% much larger could not be met by reactive avoidance at all and every obstacle
% test would fail for the same uninteresting reason.
s.MIN_CLEARANCE_REQUIRED = 0.03;

% --- requirements --------------------------------------------------------
s.requirements = { ...
 'REQ-1', sprintf('The robot shall reach the target position (centre within %.2f m) before the maximum execution time elapses.', s.GOAL_TOLERANCE); ...
 'REQ-2', 'The robot shall not collide with any obstacle or arena wall.'; ...
 'REQ-3', sprintf('The robot shall maintain a clearance of at least %.2f m from every obstacle and arena wall for the whole run.', s.MIN_CLEARANCE_REQUIRED); ...
 'REQ-4', 'The robot shall remain inside the arena at all times.'; ...
 'REQ-5', 'The system shall accept only documented input ranges and shall reject any out-of-range or malformed input without running a test.'};

% --- scenarios -----------------------------------------------------------
% Built with plain field assignment.  struct() unwraps cell values in ways
% that are easy to get wrong; this has no such behaviour to get wrong.
s.scenarios = i_scen('OPEN_FIELD','Open field (no obstacles)', ...
    'Empty arena. Isolates the navigation and timing behaviour.', {});
s.scenarios(2) = i_scen('SINGLE_OBSTACLE','Single obstacle', ...
    'One 0.15 m diameter cylinder at a position you choose.', {'obstacle_x','obstacle_y'});
s.scenarios(3) = i_scen('CORRIDOR','Corridor / narrow gap', ...
    'A barrier across the arena with a gap of the width you choose.', {'corridor_width'});
s.scenarios(4) = i_scen('DOGLEG','Dogleg', ...
    'Two offset barriers that force an S-shaped path.', {});
s.scenarios(5) = i_scen('CLUTTER','Clutter (6 obstacles)', ...
    'Six fixed obstacles scattered across the arena.', {});

% --- robots --------------------------------------------------------------
% Real platforms with their published dimensions. The navigation logic, the
% sensor and the requirements are identical for all of them -- only the
% chassis changes -- so any difference in the verdicts is caused by the
% geometry and nothing else.
s.robots = i_robot('E_PUCK','e-puck', 'diff', 0.037, 0.052, 0.0205, ...
    'Tiny 7.4 cm educational robot. Turns on the spot.');
s.robots(2) = i_robot('TURTLEBOT3_BURGER','TurtleBot3 Burger','diff', 0.105, 0.160, 0.033, ...
    'ROS teaching platform, about 21 cm across. Turns on the spot.');
s.robots(3) = i_robot('PIONEER_3DX','Pioneer 3-DX','diff', 0.22, 0.330, 0.0975, ...
    'Research robot about 44 cm across. Turns on the spot, but it is wide.');
s.robots(4) = i_robot('CAR_LIKE','Car-like (steered front wheel)','car', 0.037, 0.052, 0.0205, ...
    'e-puck sized but steered like a car: 30 degree steering limit, so a minimum turning radius near 0.21 m and no turning on the spot.');

% --- input parameters ----------------------------------------------------
keys = {s.scenarios.key};
s.parameters = i_param('robot','enum','E_PUCK',0,0,0,'Robot','', ...
    'Which robot is under test. The requirements do not change; what the robot can do does.', ...
    {s.robots.key});
s.parameters(2) = i_param('scenario','enum','SINGLE_OBSTACLE',0,0,0,'Scenario','', ...
    'Which preconfigured arena layout to test against.', keys);
s.parameters(3) = i_param('speed','float',5.5,0.5,s.MAX_WHEEL_SPEED,0.01,'Wheel speed','rad/s', ...
    sprintf('Cruise wheel speed. %.2f rad/s is the motor limit (%.3f m/s).', ...
    s.MAX_WHEEL_SPEED, s.MAX_WHEEL_SPEED*s.WHEEL_RADIUS), {});
s.parameters(4) = i_param('start_x','float',-0.70,-0.85,0.85,0.01,'Start X','m', ...
    'Initial robot position, X axis.', {});
s.parameters(5) = i_param('start_y','float',-0.70,-0.85,0.85,0.01,'Start Y','m', ...
    'Initial robot position, Y axis.', {});
s.parameters(6) = i_param('start_heading_deg','float',45,-180,180,1,'Start heading','deg', ...
    'Initial orientation. 0 deg faces +X, 90 deg faces +Y.', {});
s.parameters(7) = i_param('goal_x','float',0.70,-0.85,0.85,0.01,'Goal X','m', ...
    'Target position, X axis.', {});
s.parameters(8) = i_param('goal_y','float',0.70,-0.85,0.85,0.01,'Goal Y','m', ...
    'Target position, Y axis.', {});
s.parameters(9) = i_param('obstacle_x','float',0,-0.85,0.85,0.01,'Obstacle X','m', ...
    'SINGLE_OBSTACLE only: centre of the cylinder, X axis.', {});
s.parameters(10) = i_param('obstacle_y','float',0,-0.85,0.85,0.01,'Obstacle Y','m', ...
    'SINGLE_OBSTACLE only: centre of the cylinder, Y axis.', {});
s.parameters(11) = i_param('corridor_width','float',0.40,0.15,0.90,0.01,'Corridor width','m', ...
    sprintf('CORRIDOR only: width of the gap. The robot is %.3f m wide.',2*s.ROBOT_RADIUS), {});
s.parameters(12) = i_param('sensor_noise','float',0,0,0.50,0.01,'Sensor noise','fraction', ...
    'Relative Gaussian noise on every range reading. Reproducible for a given seed.', {});
s.parameters(13) = i_param('max_time','float',30,5,120,1,'Max execution time','s', ...
    'Simulated seconds allowed before the run is declared a timeout.', {});
s.parameters(14) = i_param('seed','int',1,1,999999,1,'Noise seed','', ...
    'Seed of the noise generator. The same seed always reproduces the same run.', {});

s.defaults = struct();
for i = 1:numel(s.parameters)
    s.defaults.(s.parameters(i).key) = s.parameters(i).default;
end
end

function o = i_robot(key, label, kind, radius, track, wheel, description)
o.key = key; o.label = label; o.kind = kind; o.radius = radius;
o.track = track; o.wheel = wheel; o.description = description;
end

function o = i_scen(key, label, description, extra)
o.key = key; o.label = label; o.description = description; o.extra = extra;
end

function o = i_param(key, kind, def, mn, mx, step, label, unit, helptext, choices)
o.key = key; o.kind = kind; o.default = def; o.min = mn; o.max = mx;
o.step = step; o.label = label; o.unit = unit; o.help = helptext;
o.choices = choices;
end
