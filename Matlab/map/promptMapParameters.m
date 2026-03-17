function [ok, params] = promptMapParameters(defaultParams)

params = defaultParams;
prompt = { ...
    "X Min"
    "X Max"
    "Y Min"
    "Y Max"
    "Region Count"
    "Radius Min"
    "Radius Max"
    };
defaults = { ...
    num2str(params.XMin)
    num2str(params.XMax)
    num2str(params.YMin)
    num2str(params.YMax)
    num2str(params.RegionCount)
    num2str(params.RadiusMin)
    num2str(params.RadiusMax)
    };

answer = inputdlg(prompt, "Generate Map Parameters", [1 50], defaults);
if isempty(answer)
    ok = false;
    return
end

values = str2double(answer);
if any(isnan(values)) || any(~isfinite(values))
    errordlg("All values must be valid numbers.", "Invalid parameters", "modal");
    ok = false;
    return
end

params.XMin = values(1);
params.XMax = values(2);
params.YMin = values(3);
params.YMax = values(4);
params.RegionCount = round(values(5));
params.RadiusMin = values(6);
params.RadiusMax = values(7);

if params.XMax <= params.XMin || params.YMax <= params.YMin
    errordlg("Max bounds must be greater than min bounds.", "Invalid bounds", "modal");
    ok = false;
    return
end

if params.RegionCount < 1 || abs(values(5) - round(values(5))) > 0
    errordlg("Region Count must be a positive integer.", "Invalid region count", "modal");
    ok = false;
    return
end

if params.RadiusMin <= 0 || params.RadiusMax < params.RadiusMin
    errordlg("Radii must be positive and Radius Max must be >= Radius Min.", "Invalid radii", "modal");
    ok = false;
    return
end

ok = true;

end
