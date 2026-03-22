function mapState = loadMap(filename)

filename = char(string(filename));
[mapMatrix, xmin, xmax, ymin, ymax] = readMap(filename);
mapMatrix = optimizeDisplayMatrix(single(mapMatrix));
mapJson = jsondecode(fileread(filename));
[folder, name, ~] = fileparts(filename);
[~, folderName] = fileparts(folder);

if isfield(mapJson, "Threats")
    threats = extractThreatDisplayData(mapJson.Threats);
else
    threats = struct([]);
end

mapState = struct( ...
    "Matrix", mapMatrix, ...
    "XMin", xmin, ...
    "XMax", xmax, ...
    "YMin", ymin, ...
    "YMax", ymax, ...
    "Threats", threats, ...
    "Folder", string(folder), ...
    "Guid", string(folderName), ...
    "JsonFile", string(filename), ...
    "Name", string(name));

end

function mapMatrix = optimizeDisplayMatrix(mapMatrix)

if isempty(mapMatrix)
    return
end

maxRows = 900;
maxCols = 1200;
[rowCount, colCount] = size(mapMatrix);
stride = max(1, ceil(max(rowCount / maxRows, colCount / maxCols)));
if stride == 1
    return
end

rowIndex = 1:stride:rowCount;
colIndex = 1:stride:colCount;
if rowIndex(end) ~= rowCount
    rowIndex(end + 1) = rowCount;
end
if colIndex(end) ~= colCount
    colIndex(end + 1) = colCount;
end

mapMatrix = mapMatrix(rowIndex, colIndex);

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
