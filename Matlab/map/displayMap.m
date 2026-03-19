function displayMap(ax,map,xmin,xmax,ymin,ymax,threats)

if nargin < 7
    threats = [];
end

axes(ax)

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
for i = 1:numel(threats)
    if ~isfield(threats(i),"CenterX") || ~isfield(threats(i),"CenterY")
        continue
    end

    % Draw the nominal threat footprint so overlaps remain visible even
    % when the heatmap saturates.
    if isfield(threats(i), "Radius") && isfinite(threats(i).Radius) && threats(i).Radius > 0
        theta = linspace(0, 2 * pi, 100);
        circleX = threats(i).CenterX + threats(i).Radius * cos(theta);
        circleY = threats(i).CenterY + threats(i).Radius * sin(theta);
        plot(ax, circleX, circleY, ...
            "Color", [0 0.2 0.8], ...
            "LineWidth", 0.75, ...
            "Clipping", "on");
    end

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
hold(ax,"off")

end
