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
RB    = S.robots(strcmp({S.robots.key}, params.robot));
if isempty(RB), error('labrun:robot','Unknown robot ''%s''.', params.robot); end
H     = labhalf(params);
items = lablayout(params);
map   = i_buildmap(S, items, H);

lidar = rangeSensor('Range',[0 S.SENSOR_RANGE], ...
        'HorizontalAngle',[S.SENSOR_ANGLES(1) S.SENSOR_ANGLES(end)], ...
        'HorizontalAngleResolution', S.SENSOR_ANGLES(3)-S.SENSOR_ANGLES(2));
if strcmp(RB.kind,'car')
    rob = bicycleKinematics('WheelBase',RB.base, ...
          'MaxSteeringAngle',S.MAX_STEER, ...
          'VehicleInputs','VehicleSpeedSteeringAngle');
else
    rob = differentialDriveKinematics('WheelRadius',RB.wheel, ...
          'TrackWidth',RB.track,'VehicleInputs','VehicleSpeedHeadingRate');
end

rng(params.seed,'twister');
vmax  = params.speed * RB.wheel;
wmax  = 2*vmax / RB.track;
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
    [hTrail,hRob] = i_setupplot(ax, S, items, goal, pose, RB, H);
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
    if strcmp(RB.kind,'diff')
        wlSpin = (v - w*RB.track/2) / RB.wheel;
        wrSpin = (v + w*RB.track/2) / RB.wheel;
        mSpin  = max(abs(wlSpin), abs(wrSpin));
        if mSpin > params.speed
            kSpin = params.speed / mSpin;  v = v * kSpin;  w = w * kSpin;
        end
    end

    prev = pose(1:2);
    if strcmp(RB.kind,'car')
        % A steered front wheel cannot deliver an arbitrary turn rate: convert
        % the desired rate into a steering angle and clip it to the limit.
        if v < 1e-9
            steer = 0;
        else
            steer = atan(w * RB.base / v);
        end
        steer = max(min(steer, S.MAX_STEER), -S.MAX_STEER);
        pose = pose + derivative(rob, pose, [v steer]) * dt;
    else
        pose = pose + derivative(rob, pose, [v w]) * dt;
    end
    t = t + dt; k = k + 1;
    pathLen = pathLen + norm(pose(1:2) - prev);
    trail(end+1,:) = pose(1:2)'; %#ok<AGROW>

    c = i_clearance(H, items, pose(1), pose(2), RB.radius);
    minClear = min(minClear, c);
    if c <= 0, collided = true; end
    if max(abs(pose(1)), abs(pose(2))) + RB.radius > H, leftArena = true; end

    if norm(pose(1:2)' - goal) <= S.GOAL_TOLERANCE, break; end
    if collided || leftArena, break; end

    if opts.Animate && mod(k,every)==0
        set(hTrail,'XData',trail(:,1),'YData',trail(:,2));
        hRob.Position = [pose(1)-RB.radius, pose(2)-RB.radius, ...
                         2*RB.radius, 2*RB.radius];
        title(ax, sprintf('%s   t = %5.2f s   clearance = %.3f m', RB.label, t, c));
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

function map = i_buildmap(S, items, H) %#ok<INUSL>
side = 2*(H + 0.01);
res  = max(40, min(100, round(200/side)));   % keep the grid affordable when big
map  = binaryOccupancyMap(side, side, res);
map.GridLocationInWorld = [-side/2 -side/2];
g = -side/2 : 1/res : side/2;
[X,Y] = meshgrid(g, g);
occ = abs(X) > H | abs(Y) > H;
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

function c = i_clearance(H, items, px, py, rad)
c = H - max(abs(px), abs(py)) - rad;
for i = 1:numel(items)
    it = items(i);
    if strcmp(it.type,'cyl')
        d = hypot(px-it.x, py-it.y) - it.r - rad;
    else
        dx = max(abs(px-it.x) - it.sx/2, 0);
        dy = max(abs(py-it.y) - it.sy/2, 0);
        d  = hypot(dx,dy) - rad;
    end
    c = min(c, d);
end
end

function [hTrail,hRob] = i_setupplot(ax, S, items, goal, pose, RB, H)
cla(ax); hold(ax,'on'); axis(ax,'equal');
lim = H + 0.05; xlim(ax,[-lim lim]); ylim(ax,[-lim lim]); grid(ax,'on');
rectangle(ax,'Position',[-H -H 2*H 2*H], ...
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
r = RB.radius;
hRob = rectangle(ax,'Position',[pose(1)-r pose(2)-r 2*r 2*r],'Curvature',[1 1], ...
    'FaceColor',[.85 .25 .2],'EdgeColor','none');
xlabel(ax,'X [m]'); ylabel(ax,'Y [m]');
end

function s = i_yn(cond, a, b)
if cond, s = a; else, s = b; end
end
