function mapState = loadMap(filename)

filename = char(string(filename));
[folder, name, ~] = fileparts(filename);
[~, folderName] = fileparts(folder);
cacheFile = fullfile(folder, "map_cache_fast.mat");
displayMaxRows = 900;
displayMaxCols = 1200;
cacheVersion = 2;
sourceInfo = dir(filename);
cacheInfo = dir(cacheFile);
useCache = false;
if ~isempty(cacheInfo) && ~isempty(sourceInfo) && cacheInfo.datenum >= sourceInfo.datenum
    cacheData = load(cacheFile);
    useCache = isfield(cacheData, "CacheVersion") ...
        && cacheData.CacheVersion == cacheVersion ...
        && isfield(cacheData, "DisplayMaxRows") ...
        && cacheData.DisplayMaxRows == displayMaxRows ...
        && isfield(cacheData, "DisplayMaxCols") ...
        && cacheData.DisplayMaxCols == displayMaxCols;
end

loadTimer = tic;
if useCache
    fprintf("loadMap: using cache %s\n", cacheFile);
    mapImage = cacheData.MapImage;
    xmin = cacheData.XMin;
    xmax = cacheData.XMax;
    ymin = cacheData.YMin;
    ymax = cacheData.YMax;
    threats = cacheData.Threats;
    if isfield(cacheData, "ThreatResolution")
        threatResolution = cacheData.ThreatResolution;
    else
        threatResolution = getThreatResolution(threats);
    end
    fprintf("loadMap: cache load %.3f s\n", toc(loadTimer));
else
    fprintf("loadMap: preprocessing %s\n", filename);
    preprocessTimer = tic;
    [mapImage, xmin, xmax, ymin, ymax, mapJson] = readMap(filename, displayMaxRows, displayMaxCols);

    if isfield(mapJson, "Threats")
        threats = extractThreatDisplayData(mapJson.Threats);
    else
        threats = struct([]);
    end

    threatResolution = getThreatResolution(threats);
    preprocessElapsed = toc(preprocessTimer);
    fprintf("loadMap: preprocess %.3f s\n", preprocessElapsed);

    MapImage = mapImage;
    XMin = xmin;
    XMax = xmax;
    YMin = ymin;
    YMax = ymax;
    Threats = threats;
    ThreatResolution = threatResolution;
    CacheVersion = cacheVersion;
    DisplayMaxRows = displayMaxRows;
    DisplayMaxCols = displayMaxCols;
    save(cacheFile, "MapImage", "XMin", "XMax", "YMin", "YMax", "Threats", ...
        "ThreatResolution", "CacheVersion", "DisplayMaxRows", "DisplayMaxCols", "-v7");
    fprintf("loadMap: saved cache %s\n", cacheFile);
    fprintf("loadMap: total load %.3f s\n", toc(loadTimer));
end

mapState = struct( ...
    "BaseImage", mapImage, ...
    "DisplayImage", mapImage, ...
    "XMin", xmin, ...
    "XMax", xmax, ...
    "YMin", ymin, ...
    "YMax", ymax, ...
    "Threats", threats, ...
    "ThreatResolution", threatResolution, ...
    "Folder", string(folder), ...
    "Guid", string(folderName), ...
    "CacheFile", string(cacheFile), ...
    "JsonFile", string(filename), ...
    "Name", string(name));

end

function threats = extractThreatDisplayData(rawThreats)

if isempty(rawThreats)
    threats = struct([]);
    return
end

template = struct( ...
    "Id", '', ...
    "CenterX", NaN, ...
    "CenterY", NaN, ...
    "Radius", NaN, ...
    "Resolution", NaN);

threats = repmat(template, numel(rawThreats), 1);
for i = 1:numel(rawThreats)
    if ~isfield(rawThreats, "Id")
        error("loadMap:MissingThreatId", "Threat %d is missing required field Id.", i);
    end
    threats(i).Id = char(string(rawThreats(i).Id));

    if ~isfield(rawThreats, "CenterX")
        error("loadMap:MissingThreatCenterX", "Threat %d is missing required field CenterX.", i);
    end
    threats(i).CenterX = double(rawThreats(i).CenterX);

    if ~isfield(rawThreats, "CenterY")
        error("loadMap:MissingThreatCenterY", "Threat %d is missing required field CenterY.", i);
    end
    threats(i).CenterY = double(rawThreats(i).CenterY);

    if ~isfield(rawThreats, "Radius")
        error("loadMap:MissingThreatRadius", "Threat %d is missing required field Radius.", i);
    end
    threats(i).Radius = double(rawThreats(i).Radius);

    if ~isfield(rawThreats, "Resolution")
        error("loadMap:MissingThreatResolution", "Threat %d is missing required field Resolution.", i);
    end
    threats(i).Resolution = double(rawThreats(i).Resolution);

    if ~isfinite(threats(i).CenterX) || ~isfinite(threats(i).CenterY)
        error("loadMap:InvalidThreatCenter", "Threat %d must have finite CenterX and CenterY values.", i);
    end

    if ~isfinite(threats(i).Radius) || threats(i).Radius <= 0
        error("loadMap:InvalidThreatRadius", "Threat %d must have a positive finite radius.", i);
    end

    if ~isfinite(threats(i).Resolution) || threats(i).Resolution <= 0
        error("loadMap:InvalidThreatResolution", "Threat %d must have a positive finite resolution.", i);
    end
end

end
