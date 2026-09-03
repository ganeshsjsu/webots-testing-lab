function items = lablayout(params)
%LABLAYOUT  Obstacle placement for a validated parameter set.
%   Each item is a struct: type 'cyl' (x,y,r) or 'box' (x,y,sx,sy).
%   Layouts are defined for the default 2 m arena and scaled from there, so
%   a bigger arena gives the same course with more room in it.
S = labspec();
H = labhalf(params);
k = H / 0.99;                      % 0.99 is the half-width of the default arena
r = S.OBSTACLE_RADIUS * max(1, k); % obstacles grow with the arena, walls do not
cyl = @(x,y) struct('type','cyl','x',x,'y',y,'r',r,'sx',0,'sy',0);
box = @(x,y,sx,sy) struct('type','box','x',x,'y',y,'r',0,'sx',sx,'sy',sy);
items = struct('type',{},'x',{},'y',{},'r',{},'sx',{},'sy',{});

switch params.scenario
    case 'OPEN_FIELD'
        % nothing

    case 'SINGLE_OBSTACLE'
        items(end+1) = cyl(params.obstacle_x, params.obstacle_y);

    case 'CORRIDOR'
        w    = params.corridor_width;      % an absolute gap, not scaled
        half = H - w/2;
        items(end+1) = box(0, -(w/2 + half/2), S.WALL_THICKNESS, half);
        items(end+1) = box(0, +(w/2 + half/2), S.WALL_THICKNESS, half);

    case 'DOGLEG'
        items(end+1) = box(-0.30*k,  0.30*k, S.WALL_THICKNESS, 1.30*k);
        items(end+1) = box( 0.30*k, -0.30*k, S.WALL_THICKNESS, 1.30*k);

    case 'CLUTTER'
        fixed = [-0.35 -0.20; -0.10 0.35; 0.20 -0.05; 0.15 0.55; 0.55 0.20; -0.55 0.15];
        for i = 1:size(fixed,1)
            items(end+1) = cyl(fixed(i,1)*k, fixed(i,2)*k); %#ok<AGROW>
        end
end
end
