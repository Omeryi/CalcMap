function [map,xmin,xmax,ymin,ymax,data] = readMap(file, maxRows, maxCols)

txt = fileread(file);
data = jsondecode(txt);

if ischar(data) || (isstring(data) && isscalar(data))
    error('readMap:InvalidSchema', ...
        'Invalid map JSON in "%s". Expected object with fields "Parameters" and "Threats", got string.', file);
end

% Accept a few common wrappers, but enforce map schema:
% root object with fields Parameters and Threats.
if iscell(data) && numel(data) == 1
    data = data{1};
end

if isstruct(data) && ~isscalar(data)
    if isfield(data(1),'Parameters') && isfield(data(1),'Threats')
        data = data(1);
    else
        error('readMap:InvalidSchema', ...
            'Invalid map JSON in "%s". Expected object with fields "Parameters" and "Threats".', file);
    end
end

if ~isstruct(data) || ~isscalar(data) || ...
        ~isfield(data,'Parameters') || ~isfield(data,'Threats')
    error('readMap:InvalidSchema', ...
        'Invalid map JSON in "%s". Expected object with fields "Parameters" and "Threats".', file);
end

params = data.Parameters;

xmin = params.XMin;
xmax = params.XMax;
ymin = params.YMin;
ymax = params.YMax;

threats = data.Threats;

if isempty(threats)
    error('readMap:NoThreats', ...
        'Map JSON in "%s" has no threats.', file);
end

for t = 1:numel(threats)
    validateThreatSchema(threats(t), t, file);
end

if ~isfield(threats(1),'Resolution')
    error('readMap:MissingResolution', ...
        'Map JSON in "%s" is missing "Resolution" in threats.', file);
end

res = threats(1).Resolution;
if ~isfinite(res) || res <= 0
    error('readMap:InvalidResolution', ...
        'Map JSON in "%s" has a non-positive or non-finite threat resolution.', file);
end

if nargin < 2 || isempty(maxRows) || maxRows < 1
    maxRows = inf;
end

function validateThreatSchema(threat, threatIndex, file)

requiredFields = {'Id', 'CenterX', 'CenterY', 'Radius', 'Resolution', 'Image'};
for i = 1:numel(requiredFields)
    if ~isfield(threat, requiredFields{i})
        error('readMap:MissingThreatField', ...
            'Threat %d in "%s" is missing required field "%s".', ...
            threatIndex, file, requiredFields{i});
    end
end

if ~isfinite(threat.CenterX) || ~isfinite(threat.CenterY)
    error('readMap:InvalidThreatCenter', ...
        'Threat %d in "%s" has a non-finite center.', threatIndex, file);
end

if ~isfinite(threat.Radius) || threat.Radius <= 0
    error('readMap:InvalidThreatRadius', ...
        'Threat %d in "%s" must have a positive finite radius.', threatIndex, file);
end

if ~isfinite(threat.Resolution) || threat.Resolution <= 0
    error('readMap:InvalidThreatResolution', ...
        'Threat %d in "%s" must have a positive finite resolution.', threatIndex, file);
end

if isempty(threat.Image)
    error('readMap:MissingThreatImage', ...
        'Threat %d in "%s" must contain non-empty image data.', threatIndex, file);
end

end
if nargin < 3 || isempty(maxCols) || maxCols < 1
    maxCols = inf;
end

displayRes = max(res, max((xmax - xmin) / max(maxCols - 1, 1), (ymax - ymin) / max(maxRows - 1, 1)));
nx = round((xmax - xmin) / displayRes) + 1;
ny = round((ymax - ymin) / displayRes) + 1;

% Build one global grid for the whole map, then stamp each threat image
% into it at the threat's world-space position.
map = zeros(ny, nx, 'single');

for t = 1:length(threats)

    img = single(threats(t).Image);

    cx = threats(t).CenterX;
    cy = threats(t).CenterY;
    r = threats(t).Radius;

    imgHeight = size(img, 1);
    imgWidth = size(img, 2);
    displayHeight = max(1, round(((imgHeight - 1) * res) / displayRes) + 1);
    displayWidth = max(1, round(((imgWidth - 1) * res) / displayRes) + 1);

    rowIndex = unique(round(linspace(1, imgHeight, displayHeight)));
    colIndex = unique(round(linspace(1, imgWidth, displayWidth)));
    displayImg = img(rowIndex, colIndex);

    xs = cx - r;
    ys = cy - r;

    ix = round((xs - xmin) / displayRes) + 1;
    iy = round((ys - ymin) / displayRes) + 1;

    xRange = ix:(ix + size(displayImg, 2) - 1);
    yRange = iy:(iy + size(displayImg, 1) - 1);
    validX = xRange >= 1 & xRange <= nx;
    validY = yRange >= 1 & yRange <= ny;
    if ~any(validX) || ~any(validY)
        continue
    end

    clippedX = xRange(validX);
    clippedY = yRange(validY);
    clippedImg = displayImg(validY, validX);

    % Overlapping threats add together visually, but the display
    % is capped at 1 so the heatmap stays in a fixed range.
    map(clippedY, clippedX) = min(1, map(clippedY, clippedX) + clippedImg);

end

end
