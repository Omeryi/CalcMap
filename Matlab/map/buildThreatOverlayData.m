function overlay = buildThreatOverlayData(threats)

overlay = struct( ...
    "OutlineX", zeros(1, 0), ...
    "OutlineY", zeros(1, 0), ...
    "LabelX", zeros(0, 1), ...
    "LabelY", zeros(0, 1), ...
    "LabelText", {cell(0, 1)});

if isempty(threats)
    return
end

circleSampleCount = 64;
if numel(threats) >= 200
    circleSampleCount = 40;
elseif numel(threats) >= 100
    circleSampleCount = 48;
end

theta = linspace(0, 2 * pi, circleSampleCount);
outlineSegmentsX = cell(0, 1);
outlineSegmentsY = cell(0, 1);
labelX = zeros(numel(threats), 1);
labelY = zeros(numel(threats), 1);
labelText = cell(numel(threats), 1);
labelCount = 0;

for i = 1:numel(threats)
    if ~isfield(threats(i), "CenterX") || ~isfield(threats(i), "CenterY")
        continue
    end

    centerX = double(threats(i).CenterX);
    centerY = double(threats(i).CenterY);
    if ~isfinite(centerX) || ~isfinite(centerY)
        continue
    end

    labelCount = labelCount + 1;
    labelX(labelCount) = centerX;
    labelY(labelCount) = centerY;
    labelText{labelCount} = sprintf('T%d', i);

    if isfield(threats(i), "Radius") && isfinite(threats(i).Radius) && threats(i).Radius > 0
        radius = double(threats(i).Radius);
        circleX = centerX + radius * cos(theta);
        circleY = centerY + radius * sin(theta);
        outlineSegmentsX{end + 1, 1} = [circleX, NaN]; %#ok<AGROW>
        outlineSegmentsY{end + 1, 1} = [circleY, NaN]; %#ok<AGROW>
    end
end

if ~isempty(outlineSegmentsX)
    overlay.OutlineX = [outlineSegmentsX{:}];
    overlay.OutlineY = [outlineSegmentsY{:}];
end

overlay.LabelX = labelX(1:labelCount);
overlay.LabelY = labelY(1:labelCount);
overlay.LabelText = labelText(1:labelCount);

end
