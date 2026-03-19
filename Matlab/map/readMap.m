function [map,xmin,xmax,ymin,ymax] = readMap(file)

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

if isfield(threats(1),'Resolution')
    res = threats(1).Resolution;
elseif isfield(params,'Resolution')
    res = params.Resolution;
else
    error('readMap:MissingResolution', ...
        'Map JSON in "%s" is missing "Resolution" in threats or parameters.', file);
end

nx = round((xmax-xmin)/res)+1;
ny = round((ymax-ymin)/res)+1;

% Build one global grid for the whole map, then stamp each threat image
% into it at the threat's world-space position.
map = zeros(ny,nx);

for t = 1:length(threats)

    img = threats(t).Image;

    cx = threats(t).CenterX;
    cy = threats(t).CenterY;
    r = threats(t).Radius;

    imgSize = size(img,1);

    xs = cx - r;
    ys = cy - r;

    ix = round((xs-xmin)/res)+1;
    iy = round((ys-ymin)/res)+1;

    for i=1:imgSize
        for j=1:imgSize

            gx = ix+j-1;
            gy = iy+i-1;

            if gx>=1 && gx<=nx && gy>=1 && gy<=ny
                % Overlapping threats add together visually, but the display
                % is capped at 1 so the heatmap stays in a fixed range.
                map(gy,gx) = min(1, map(gy,gx) + img(i,j));
            end

        end
    end

end

end
