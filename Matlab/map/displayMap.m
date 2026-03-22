function displayMap(ax,map,xmin,xmax,ymin,ymax,threats,renderOptions)

if nargin < 7
    threats = [];
end
if nargin < 8
    renderOptions = struct();
end

showThreatLabels = true;
if isstruct(renderOptions) && isfield(renderOptions, "ShowThreatLabels")
    showThreatLabels = logical(renderOptions.ShowThreatLabels);
end

circleSampleCount = 64;
if numel(threats) >= 200
    circleSampleCount = 40;
elseif numel(threats) >= 100
    circleSampleCount = 48;
end

% Redraw from scratch so labels, outlines, and paths stay in sync.
cla(ax)

imagesc(ax,[xmin xmax],[ymin ymax],map)

axis(ax,"xy")
axis(ax,"equal")
xlim(ax, [xmin xmax])
ylim(ax, [ymin ymax])
ax.XLimMode = "manual";
ax.YLimMode = "manual";

colormap(ax,"hot")  % good for threat heatmaps

cb = colorbar(ax);
cb.Label.String = "Threat Intensity";

title(ax,"Map")

if isempty(threats)
    return
end

hold(ax,"on")
theta = linspace(0, 2 * pi, circleSampleCount);
circleSegmentsX = cell(0, 1);
circleSegmentsY = cell(0, 1);
for i = 1:numel(threats)
    if ~isfield(threats(i),"CenterX") || ~isfield(threats(i),"CenterY")
        continue
    end

    % Draw the nominal threat footprint so overlaps remain visible even
    % when the heatmap saturates.
    if isfield(threats(i), "Radius") && isfinite(threats(i).Radius) && threats(i).Radius > 0
        circleX = threats(i).CenterX + threats(i).Radius * cos(theta);
        circleY = threats(i).CenterY + threats(i).Radius * sin(theta);
        circleSegmentsX{end + 1, 1} = [circleX, NaN]; %#ok<AGROW>
        circleSegmentsY{end + 1, 1} = [circleY, NaN]; %#ok<AGROW>
    end

    if showThreatLabels
        label = sprintf("T%d", i);

        text(ax, threats(i).CenterX, threats(i).CenterY, label, ...
            "Color", [0 0 0], ...
            "BackgroundColor", [1 1 0], ...
            "FontSize", 8, ...
            "FontWeight", "bold", ...
            "Interpreter", "none", ...
            "VerticalAlignment", "bottom", ...
            "HorizontalAlignment", "left", ...
            "Clipping", "on");
    end
end

if ~isempty(circleSegmentsX)
    outlineX = [circleSegmentsX{:}];
    outlineY = [circleSegmentsY{:}];
    plot(ax, outlineX, outlineY, ...
        "Color", [0 0.2 0.8], ...
        "LineWidth", 0.75, ...
        "Clipping", "on");
end
hold(ax,"off")

end
