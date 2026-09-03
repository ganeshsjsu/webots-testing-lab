function labselftest()
%LABSELFTEST  Three cases that prove the lab works: a pass, a fail, a rejection.
fprintf('\n--- CMPE 187 lab self-test -------------------------------\n');
S = labspec();

cases = { ...
  'expect PASS  ', struct('scenario','OPEN_FIELD','speed',5.5,'max_time',30); ...
  'expect FAIL  ', struct('scenario','OPEN_FIELD','speed',0.8,'max_time',30); ...
  'expect REJECT', struct('scenario','OPEN_FIELD','speed',99)};

for i = 1:size(cases,1)
    [p, errs] = labvalidate(cases{i,2});
    if ~isempty(errs)
        fprintf('%s  REJECTED  %s\n', cases{i,1}, errs{1});
        continue
    end
    R = labrun(p);
    fprintf('%s  %-4s  t=%6.2fs  clr=%.4fm  %s\n', ...
        cases{i,1}, R.verdict, R.time, R.min_clearance, R.reason);
end

fprintf('---------------------------------------------------------\n');
fprintf('Requirements loaded: %d.  Scenarios: %s.\n', size(S.requirements,1), ...
    strjoin({S.scenarios.key}, ', '));
fprintf('Robots: %s.\n', strjoin({S.robots.key}, ', '));
for i = 1:numel(S.robots)
    rb = S.robots(i);
    [q, e] = labvalidate(struct('robot',rb.key));
    if ~isempty(e)
        fprintf('  %-20s REJECTED  %s\n', rb.key, e{1});
        continue
    end
    Rr = labrun(q);
    fprintf('  %-20s %-4s  t=%6.2fs  clr=%.4fm\n', rb.key, Rr.verdict, Rr.time, Rr.min_clearance);
end
fprintf('\nArena is now an input (default 2.0 m, range 1.0-6.0). Try:\n');
fprintf('  labdemo(''robot'',''CLEARPATH_HUSKY'',''arena_size'',5,''start_x'',-2,''start_y'',-2,''goal_x'',2,''goal_y'',2)\n');
fprintf('Run  labdemo  to watch one animate.\n\n');
end
