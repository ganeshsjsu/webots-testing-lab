function h = labhalf(params)
%LABHALF  Distance from the arena centre to the inner face of the wall.
%   Every piece of geometry -- the scenarios, the clearance oracle, the
%   position checks and the plot limits -- derives from this one number, so
%   the arena can be resized without any of them disagreeing.
h = params.arena_size/2 - 0.01;
end
