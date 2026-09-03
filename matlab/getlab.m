function getlab()
%GETLAB  Pull the latest lab files from GitHub and run the self-test.
base  = 'https://raw.githubusercontent.com/ganeshsjsu/webots-testing-lab/main/matlab/';
files = {'labspec.m','labvalidate.m','lablayout.m','labrun.m', ...
         'labselftest.m','labdemo.m','getlab.m'};
stamp = num2str(round(posixtime(datetime('now'))));
for i = 1:numel(files)
    websave(files{i}, [base files{i} '?v=' stamp]);
end
clear functions      %#ok<CLFUNC>  evict stale copies: rehash alone will not
rehash
fprintf('Updated %d files from GitHub.\n', numel(files));
labselftest
end
