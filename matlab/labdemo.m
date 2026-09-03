function R = labdemo(varargin)
%LABDEMO  Run one animated test.  labdemo('scenario','CLUTTER','speed',6.28)
raw = struct(varargin{:});
[p, errs] = labvalidate(raw);
if ~isempty(errs)
    fprintf('\nInput rejected before any simulation ran (REQ-5):\n');
    fprintf('  - %s\n', errs{:}); fprintf('\n');
    R = []; return
end
R = labrun(p, 'Animate', true);
fprintf('\n%s  (%s)\n', R.verdict, R.reason);
marks = {'FAIL','PASS'};
for i = 1:size(R.checks,1)
    fprintf('  %-6s %-4s  %s\n', R.checks{i,1}, marks{R.checks{i,2}+1}, R.checks{i,3});
end
fprintf('  time %.2f s   min clearance %.4f m   path %.3f m\n\n', ...
    R.time, R.min_clearance, R.path_length);
end
