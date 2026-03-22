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
    if isfield(rawThreats, "Id")
        threats(i).Id = char(string(rawThreats(i).Id));
    end

    if isfield(rawThreats, "CenterX")
        threats(i).CenterX = double(rawThreats(i).CenterX);
    end

    if isfield(rawThreats, "CenterY")
        threats(i).CenterY = double(rawThreats(i).CenterY);
    end

    if isfield(rawThreats, "Radius")
        threats(i).Radius = double(rawThreats(i).Radius);
    end

    if isfield(rawThreats, "Resolution")
        threats(i).Resolution = double(rawThreats(i).Resolution);
    end
end

end
