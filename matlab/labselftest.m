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
fprintf('Run  labdemo  to watch one animate.\n\n');
end
