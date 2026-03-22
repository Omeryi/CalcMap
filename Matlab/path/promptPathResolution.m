function [ok, spacing] = promptPathResolution(defaultResolution, currentResolution)

if nargin < 1 || ~isfinite(defaultResolution) || defaultResolution <= 0
    defaultResolution = 1;
end

if nargin < 2 || ~isfinite(currentResolution) || currentResolution <= 0
    currentResolution = 1;
end

prompt = {sprintf("Path resolution / spacing between saved points (default %.3f, current average %.3f)", defaultResolution, currentResolution)};
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
