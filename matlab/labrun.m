function R = labrun(params, opts)
%LABRUN  Configure the arena, run one test, measure ground truth, judge it.
%   R = LABRUN(PARAMS) runs headlessly and returns a result struct.
%   R = LABRUN(PARAMS,'Animate',true) draws the run.
%
%   PARAMS must already have been through LABVALIDATE.  The oracle measures
%   clearance analytically from the placed geometry, never from the noisy
%   sensor, so the controller cannot influence the verdict except by driving.
arguments
    params struct
    opts.Animate (1,1) logical = false
    opts.Axes = []
    opts.Dt (1,1) double = 0.02
end

S     = labspec();
items = lablayout(params);
map   = i_buildmap(S, items);

lidar = rangeSensor('Range',[0 S.SENSOR_RANGE], ...
        'HorizontalAngle',[S.SENSOR_ANGLES(1) S.SENSOR_ANGLES(end)], ...
        'HorizontalAngleResolution', S.SENSOR_ANGLES(3)-S.SENSOR_ANGLES(2));
switch params.robot
    case 'CAR_LIKE'
        rob = bicycleKinematics('WheelBase',S.WHEELBASE, ...
              'MaxSteeringAngle',S.MAX_STEER, ...
              'VehicleInputs','VehicleSpeedSteeringAngle');
    case 'UNICYCLE'
        rob = unicycleKinematics('WheelRadius',S.WHEEL_RADIUS, ...
              'TrackWidth',S.TRACK_WIDTH,'VehicleInputs','VehicleSpeedHeadingRate');
    otherwise
        rob = differentialDriveKinematics('WheelRadius',S.WHEEL_RADIUS, ...
              'TrackWidth',S.TRACK_WIDTH,'VehicleInputs','VehicleSpeedHeadingRate');
end

rng(params.seed,'twister');
vmax  = params.speed * S.WHEEL_RADIUS;
wmax  = 2*vmax / S.TRACK_WIDTH;
goal  = [params.goal_x params.goal_y];
pose  = [params.start_x; params.start_y; deg2rad(params.start_heading_deg)];

dt = opts.Dt; t = 0; k = 0;
minClear  = inf; collided = false; leftArena = false; pathLen = 0;
state = 'SEEK'; avoidDir = 0; passLeft = 0;   % SEEK -> AVOID -> PASSBY
ENTER = 0.20; CLEAR_NEED = 0.35; PASS_T = 2.0; TURN = 1.0; SLOW = 0.6;
trail = pose(1:2)';

every = max(1, round(0.05/dt));     % redraw about every 50 ms of sim time
if opts.Animate
    ax = opts.Axes; if isempty(ax), figure; ax = axes; end
    [hTrail,hRob] = i_setupplot(ax, S, items, goal, pose);
end

while t < params.max_time
    r = lidar(pose', map);
    r(isnan(r)) = S.SENSOR_RANGE;
    if params.sensor_noise > 0
        r = r + params.sensor_noise * S.SENSOR_RANGE * randn(size(r));
        r = min(max(r,0), S.SENSOR_RANGE);
    end
    right = r(1); front = r(2); left = r(end);

    bearing = atan2(goal(2)-pose(2), goal(1)-pose(1)) - pose(3);
    bearing = atan2(sin(bearing), cos(bearing));

    % Reactive avoidance as a three-state machine.
    %
    % The sensor is three rays at 0 and +/-25 degrees, so an obstacle the
    % robot is sliding past leaves the cone while still being close enough
    % to hit the body.  Reacting only to what is currently visible makes the
    % robot clip obstacles with all three beams reading clear, so once it
    % commits to going round it keeps going until it has driven past.
    nearest = min([front left right]);
    if strcmp(state,'SEEK') && nearest < ENTER
        state = 'AVOID';
        avoidDir = sign(left - right);
        if avoidDir == 0, avoidDir = 1; end
    end
    if strcmp(state,'AVOID') && nearest > CLEAR_NEED
        state = 'PASSBY'; passLeft = round(PASS_T/dt);
    end
    if strcmp(state,'PASSBY')
        if nearest < ENTER
            state = 'AVOID';
        elseif passLeft <= 0
            state = 'SEEK'; avoidDir = 0;
        end
    end

    switch state
        case 'AVOID'
            w = avoidDir * wmax * TURN;  v = vmax * SLOW;
        case 'PASSBY'
            w = 0;                       v = vmax;  passLeft = passLeft - 1;
        otherwise
            w = max(min(3.0*bearing, wmax), -wmax);  v = vmax;
    end

    % Respect the input under test: neither wheel may exceed `speed`.
    % Commanding a fast turn and a fast cruise at once would otherwise drive
    % the wheels past the limit the student set.  Only the differential drive
    % has per-wheel speeds to clamp.
    if strcmp(params.robot,'DIFFERENTIAL_DRIVE')
        wlSpin = (v - w*S.TRACK_WIDTH/2) / S.WHEEL_RADIUS;
        wrSpin = (v + w*S.TRACK_WIDTH/2) / S.WHEEL_RADIUS;
        mSpin  = max(abs(wlSpin), abs(wrSpin));
        if mSpin > params.speed
            kSpin = params.speed / mSpin;  v = v * kSpin;  w = w * kSpin;
        end
    end

    prev = pose(1:2);
    if strcmp(params.robot,'CAR_LIKE')
        % A steered front wheel cannot deliver an arbitrary turn rate: convert
        % the desired rate into a steering angle and clip it to the limit.
        if v < 1e-9
            steer = 0;
        else
            steer = atan(w * S.WHEELBASE / v);
        end
        steer = max(min(steer, S.MAX_STEER), -S.MAX_STEER);
        pose = pose + derivative(rob, pose, [v steer]) * dt;
    else
        pose = pose + derivative(rob, pose, [v w]) * dt;
    end
    t = t + dt; k = k + 1;
    pathLen = pathLen + norm(pose(1:2) - prev);
    trail(end+1,:) = pose(1:2)'; %#ok<AGROW>

    c = i_clearance(S, items, pose(1), pose(2));
    minClear = min(minClear, c);
    if c <= 0, collided = true; end
    if max(abs(pose(1)), abs(pose(2))) > S.ARENA_HALF, leftArena = true; end

    if norm(pose(1:2)' - goal) <= S.GOAL_TOLERANCE, break; end
    if collided || leftArena, break; end

    if opts.Animate && mod(k,every)==0
        set(hTrail,'XData',trail(:,1),'YData',trail(:,2));
        hRob.Position = [pose(1)-S.ROBOT_RADIUS, pose(2)-S.ROBOT_RADIUS, ...
                         2*S.ROBOT_RADIUS, 2*S.ROBOT_RADIUS];
        title(ax, sprintf('t = %5.2f s   clearance = %.3f m', t, c));
        drawnow                      % NOT limitrate: it drops the frames
        pause(0.01)                  % pace it so a screen recording reads
    end
end

reached = norm(pose(1:2)' - goal) <= S.GOAL_TOLERANCE;

checks = { ...
 'REQ-1', reached,                              sprintf('Goal %s after %.2f s.', i_yn(reached,'reached','not reached'), t); ...
 'REQ-2', ~collided,                            i_yn(~collided,'No contact with any obstacle or wall.','Collision.'); ...
 'REQ-3', minClear >= S.MIN_CLEARANCE_REQUIRED, sprintf('Minimum clearance %.4f m (required %.2f m).', minClear, S.MIN_CLEARANCE_REQUIRED); ...
 'REQ-4', ~leftArena,                           i_yn(~leftArena,'Stayed inside the arena.','Left the arena.')};

passed  = all([checks{:,2}]);
reasons = {};
if ~reached, reasons{end+1} = i_yn(t >= params.max_time,'timed out','stopped early'); end
if collided, reasons{end+1} = 'collision'; end
if minClear < S.MIN_CLEARANCE_REQUIRED, reasons{end+1} = 'clearance too small'; end
if leftArena, reasons{end+1} = 'left the arena'; end
if isempty(reasons), reasons = {'goal reached'}; end

R = struct('verdict', i_yn(passed,'PASS','FAIL'), 'reason', strjoin(reasons,', '), ...
    'reached', reached, 'collision', collided, 'left_arena', leftArena, ...
    'time', t, 'min_clearance', minClear, 'path_length', pathLen, ...
    'final_distance', norm(pose(1:2)'-goal), 'checks', {checks}, ...
    'trail', trail, 'params', params);
end

function map = i_buildmap(S, items)
res = 100;
map = binaryOccupancyMap(2, 2, res);
map.GridLocationInWorld = [-1 -1];
g = -1 : 1/res : 1;
[X,Y] = meshgrid(g, g);
occ = abs(X) > S.ARENA_HALF | abs(Y) > S.ARENA_HALF;
for i = 1:numel(items)
    it = items(i);
    if strcmp(it.type,'cyl')
        occ = occ | ((X-it.x).^2 + (Y-it.y).^2 <= it.r^2);
    else
        occ = occ | (abs(X-it.x) <= it.sx/2 & abs(Y-it.y) <= it.sy/2);
    end
end
setOccupancy(map, [X(occ) Y(occ)], 1);
end

function c = i_clearance(S, items, px, py)
c = S.ARENA_HALF - max(abs(px), abs(py)) - S.ROBOT_RADIUS;
for i = 1:numel(items)
    it = items(i);
    if strcmp(it.type,'cyl')
        d = hypot(px-it.x, py-it.y) - it.r - S.ROBOT_RADIUS;
    else
        dx = max(abs(px-it.x) - it.sx/2, 0);
        dy = max(abs(py-it.y) - it.sy/2, 0);
        d  = hypot(dx,dy) - S.ROBOT_RADIUS;
    end
    c = min(c, d);
end
end

function [hTrail,hRob] = i_setupplot(ax, S, items, goal, pose)
cla(ax); hold(ax,'on'); axis(ax,'equal');
xlim(ax,[-1 1]); ylim(ax,[-1 1]); grid(ax,'on');
rectangle(ax,'Position',[-S.ARENA_HALF -S.ARENA_HALF 2*S.ARENA_HALF 2*S.ARENA_HALF], ...
    'EdgeColor',[.4 .4 .4],'LineWidth',2);
for i = 1:numel(items)
    it = items(i);
    if strcmp(it.type,'cyl')
        rectangle(ax,'Position',[it.x-it.r it.y-it.r 2*it.r 2*it.r], ...
            'Curvature',[1 1],'FaceColor',[.55 .55 .6],'EdgeColor','none');
    else
        rectangle(ax,'Position',[it.x-it.sx/2 it.y-it.sy/2 it.sx it.sy], ...
            'FaceColor',[.55 .55 .6],'EdgeColor','none');
    end
end
plot(ax, goal(1), goal(2), 'p', 'MarkerSize',16, 'MarkerFaceColor',[.95 .75 .15], ...
    'MarkerEdgeColor','none');
hTrail = plot(ax, pose(1), pose(2), '-', 'Color',[.15 .55 .85], 'LineWidth',1.5);
r = S.ROBOT_RADIUS;
hRob = rectangle(ax,'Position',[pose(1)-r pose(2)-r 2*r 2*r],'Curvature',[1 1], ...
    'FaceColor',[.85 .25 .2],'EdgeColor','none');
xlabel(ax,'X [m]'); ylabel(ax,'Y [m]');
end

function s = i_yn(cond, a, b)
if cond, s = a; else, s = b; end
end
