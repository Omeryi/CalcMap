function [ok, spacing] = promptPathResolution(currentResolution)

if nargin < 1 || ~isfinite(currentResolution) || currentResolution <= 0
    currentResolution = 1;
end

prompt = {sprintf("Path resolution / spacing between saved points (current average %.3f)", currentResolution)};
answer = inputdlg(prompt, "Save Path Resolution", [1 60], {num2str(currentResolution)});
if isempty(answer)
    ok = false;
    spacing = NaN;
    return
end

spacing = str2double(answer{1});
if isnan(spacing) || ~isfinite(spacing) || spacing <= 0
    errordlg("Resolution must be a positive number.", "Invalid resolution", "modal");
    ok = false;
    spacing = NaN;
    return
end

ok = true;

end
