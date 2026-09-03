function [params, errors] = labvalidate(raw)
%LABVALIDATE  REQ-5.  Returns cleaned parameters and a list of error strings.
%   When ERRORS is non-empty no test run must be started.
S = labspec();
errors = {};
params = S.defaults;

if ~isstruct(raw)
    errors = {'Input is not a parameter object.'};
    return
end

known = {S.parameters.key};
unknown = sort(setdiff(fieldnames(raw), known));
for i = 1:numel(unknown)
    errors{end+1} = sprintf('Unknown parameter ''%s''.', unknown{i}); %#ok<AGROW>
end

for i = 1:numel(S.parameters)
    spec = S.parameters(i);
    key  = spec.key;
    if ~isfield(raw, key) || isempty(raw.(key))
        continue
    end
    value = raw.(key);

    if strcmp(spec.kind,'enum')
        text = char(string(value));
        if ~any(strcmp(text, spec.choices))
            errors{end+1} = sprintf('%s (''%s''): ''%s'' is not one of %s.', ...
                spec.label, key, text, strjoin(spec.choices, ', ')); %#ok<AGROW>
        else
            params.(key) = text;
        end
        continue
    end

    if ischar(value) || isstring(value)
        number = str2double(value);
        if isnan(number)
            errors{end+1} = sprintf('%s (''%s''): ''%s'' is not a number.', ...
                spec.label, key, char(string(value))); %#ok<AGROW>
            continue
        end
    elseif isnumeric(value) && isscalar(value)
        number = double(value);
    else
        errors{end+1} = sprintf('%s (''%s''): is not a number.', spec.label, key); %#ok<AGROW>
        continue
    end

    if ~isfinite(number)
        errors{end+1} = sprintf('%s (''%s''): value is not finite.', spec.label, key); %#ok<AGROW>
        continue
    end

    if strcmp(spec.kind,'int')
        if abs(number - round(number)) > 1e-9
            errors{end+1} = sprintf('%s (''%s''): must be a whole number, got %g.', ...
                spec.label, key, number); %#ok<AGROW>
            continue
        end
        number = round(number);
    end

    if number < spec.min || number > spec.max
        unit = spec.unit; if ~isempty(unit), unit = [' ' unit]; end
        errors{end+1} = sprintf('%s (''%s''): %g is outside the documented range [%g, %g]%s.', ...
            spec.label, key, number, spec.min, spec.max, unit); %#ok<AGROW>
        continue
    end

    params.(key) = number;
end

if isempty(errors)
    d = hypot(params.goal_x - params.start_x, params.goal_y - params.start_y);
    if d < S.GOAL_TOLERANCE
        errors{end+1} = sprintf(['Start and goal are %.3f m apart, which is inside ' ...
            'the %.2f m goal tolerance: the test would pass before the robot moves. ' ...
            'Move them at least %.2f m apart.'], d, S.GOAL_TOLERANCE, S.GOAL_TOLERANCE);
    end
end
end
