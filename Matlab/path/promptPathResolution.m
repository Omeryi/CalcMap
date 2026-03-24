function [ok, spacing] = promptPathResolution(defaultResolution, currentResolution, threatResolution)

if nargin < 1 || ~isfinite(defaultResolution) || defaultResolution <= 0
    error("promptPathResolution:InvalidDefaultResolution", ...
        "Default path resolution must be a positive finite number.");
end

if nargin < 2
    currentResolution = NaN;
end

if nargin < 3 || ~isfinite(threatResolution) || threatResolution <= 0
    error("promptPathResolution:InvalidThreatResolution", ...
        "Threat resolution must be a positive finite number.");
end

currentResolutionText = "n/a";
if isfinite(currentResolution) && currentResolution > 0
    currentResolutionText = sprintf("%.3f", currentResolution);
end

prompt = {sprintf([ ...
    'Path resolution / spacing between saved points ' ...
    '(threat resolution %.3f, default path resolution %.3f, current average %s)'], ...
    threatResolution, defaultResolution, currentResolutionText)};
defaultAnswer = {num2str(defaultResolution)};

while true
    answer = inputdlg(prompt, "Save Path Resolution", [1 60], defaultAnswer);
    if isempty(answer)
        ok = false;
        spacing = NaN;
        return
    end

    spacing = str2double(answer{1});
    if isfinite(spacing) && spacing > 0
        ok = true;
        return
    end

    defaultAnswer = answer;
    uiwait(errordlg("Resolution must be a positive number.", "Invalid resolution", "modal"));
end

end
