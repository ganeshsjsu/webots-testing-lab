function getlab()
%GETLAB  Pull the latest lab files from GitHub.
%
%   Deliberately does NOT run the self-test.  Calling a freshly downloaded
%   function from inside the same invocation that cleared it hands back the
%   copy MATLAB already had in memory, which silently runs stale code and
%   reports errors against line numbers that no longer exist.  Returning to
%   the prompt first makes the reload real.
%
%   Run  getlab  then  labselftest  (or  testlab ).

base  = 'https://raw.githubusercontent.com/ganeshsjsu/webots-testing-lab/main/matlab/';
files = {'labspec.m','labvalidate.m','lablayout.m','labrun.m', ...
         'labselftest.m','labdemo.m','testlab.m','getlab.m'};
stamp = num2str(round(posixtime(datetime('now'))));
for i = 1:numel(files)
    websave(files{i}, [base files{i} '?v=' stamp]);
end
clear functions      %#ok<CLFUNC>
rehash
fprintf('Updated %d files from GitHub.\n', numel(files));
fprintf('Now run:   labselftest      (checks it works)\n');
fprintf('     or:   testlab          (opens the lab)\n');
end
