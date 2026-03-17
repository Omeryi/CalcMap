function displayMap(ax,map,xmin,xmax,ymin,ymax,threats)

if nargin < 7
    threats = [];
end

axes(ax)

cla(ax)  % clear previous plots

imagesc(ax,[xmin xmax],[ymin ymax],map)

axis(ax,"xy")
axis(ax,"equal")

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
