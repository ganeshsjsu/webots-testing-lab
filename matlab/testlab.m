function testlab()
%TESTLAB  The student-facing test lab.  No code required: set the inputs,
%   press Run test, watch the robot, read the verdict.
%
%   The form is built from LABSPEC, so the ranges shown here and the ranges
%   enforced by LABVALIDATE cannot disagree.
%
%   Built as a uifigure rather than a classic figure on purpose: MATLAB
%   Online streams uifigure updates live, but batches classic figure updates
%   made inside a function, which would show only the final frame.

S = labspec();
h = struct();
log = {};

f = uifigure('Name','CMPE 187  |  Robot Navigation Test Lab', ...
             'Position',[80 80 1200 760]);
main = uigridlayout(f,[1 2]);
main.ColumnWidth = {370,'1x'};

% ---- left: inputs -------------------------------------------------------
lp = uipanel(main,'Title','1.  Test inputs','Scrollable','on');
n  = numel(S.parameters);
lg = uigridlayout(lp,[n+3, 2]);
lg.RowHeight   = [repmat({26},1,n) {12} {32} {'1x'}];
lg.ColumnWidth = {150,'1x'};

for i = 1:n
    p = S.parameters(i);
    lab = uilabel(lg,'Text',p.label);
    lab.Tooltip = p.help;
    if strcmp(p.kind,'enum')
        c = uidropdown(lg,'Items',p.choices,'Value',p.default);
    else
        % Deliberately NO 'Limits' here.  REQ-5 is one of the requirements
        % under test, so the form must accept out-of-range input and let
        % LABVALIDATE reject it with a message naming the parameter and the
        % legal range.  A field that clamps silently makes REQ-5 untestable.
        c = uieditfield(lg,'numeric','Value',p.default);
        lab.Text = sprintf('%s [%g..%g]', p.label, p.min, p.max);
    end
    c.Tooltip = p.help;
    h.(p.key) = c;
end

uilabel(lg,'Text',''); uilabel(lg,'Text','');
uibutton(lg,'Text','Run test','BackgroundColor',[.15 .45 .75], ...
    'FontColor','w','FontWeight','bold','ButtonPushedFcn',@onRun);
uibutton(lg,'Text','Restore defaults','ButtonPushedFcn',@onDefaults);

% ---- right: arena, verdict, log ----------------------------------------
rg = uigridlayout(main,[3 1]);
rg.RowHeight = {'1x',150,190};

ax = uiaxes(rg);
title(ax,'Press Run test');

vp = uipanel(rg,'Title','2.  Result');
vg = uigridlayout(vp,[1 2]); vg.ColumnWidth = {150,'1x'};
h.verdict = uilabel(vg,'Text','—','FontSize',34,'FontWeight','bold', ...
    'HorizontalAlignment','center');
h.detail = uitextarea(vg,'Editable','off','Value',{'No test run yet.'});

lpn = uipanel(rg,'Title','3.  Test log');
lgn = uigridlayout(lpn,[2 1]); lgn.RowHeight = {'1x',28};
h.table = uitable(lgn,'ColumnName', ...
    {'#','Scenario','Speed','Noise','Limit','Time','Min clr','Verdict','Reason'});
uibutton(lgn,'Text','Download log as CSV','ButtonPushedFcn',@onExport);

% ---------------------------------------------------------------- callbacks
    function raw = gather()
        raw = struct();
        for j = 1:n
            raw.(S.parameters(j).key) = h.(S.parameters(j).key).Value;
        end
    end

    function onDefaults(~,~)
        for j = 1:n
            h.(S.parameters(j).key).Value = S.parameters(j).default;
        end
    end

    function onRun(~,~)
        [p, errs] = labvalidate(gather());
        if ~isempty(errs)
            % REQ-5: rejected before anything is simulated.
            h.verdict.Text = 'REJECTED';
            h.verdict.FontColor = [.85 .55 .1];
            h.detail.Value = [{'Input rejected. No simulation was run (REQ-5):'}; ...
                              cellfun(@(e) ['  - ' e], errs(:), 'UniformOutput',false)];
            return
        end
        h.verdict.Text = '...';
        h.verdict.FontColor = [.3 .3 .3];
        h.detail.Value = {'Running...'};
        drawnow

        R = labrun(p,'Animate',true,'Axes',ax);

        h.verdict.Text = R.verdict;
        if strcmp(R.verdict,'PASS')
            h.verdict.FontColor = [.1 .55 .2];
        else
            h.verdict.FontColor = [.8 .2 .15];
        end
        lines = {sprintf('%s  -  %s', R.verdict, R.reason)};
        marks = {'FAIL','PASS'};
        for j = 1:size(R.checks,1)
            lines{end+1} = sprintf('%s  %-4s  %s', R.checks{j,1}, ...
                marks{R.checks{j,2}+1}, R.checks{j,3}); %#ok<AGROW>
        end
        lines{end+1} = sprintf('time %.2f s   min clearance %.4f m   path %.3f m', ...
            R.time, R.min_clearance, R.path_length);
        h.detail.Value = lines';

        log(end+1,:) = {size(log,1)+1, p.scenario, p.speed, p.sensor_noise, ...
            p.max_time, round(R.time,2), round(R.min_clearance,4), ...
            R.verdict, R.reason}; %#ok<AGROW>
        h.table.Data = log;
    end

    function onExport(~,~)
        if isempty(log), return, end
        T = cell2table(log,'VariableNames', ...
            {'run','scenario','speed','noise','limit','time','min_clearance','verdict','reason'});
        writetable(T,'test_log.csv');
        uialert(f,'Saved as test_log.csv in your MATLAB Drive. Right-click it in the Files panel to download.', ...
            'Log exported','Icon','success');
    end
end
