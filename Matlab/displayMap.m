function displayMap(ax,map,xmin,xmax,ymin,ymax,threats)

if nargin < 7
    threats = [];
end

if isempty(threats) && isappdata(0, 'CalcMapThreats')
    threats = getappdata(0, 'CalcMapThreats');
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

    if isfield(threats(i),"Id")
        idText = char(string(threats(i).Id));
        if numel(idText) > 8
            label = idText(1:8);
        else
            label = idText;
        end
    else
        label = sprintf("T%d", i);
    end

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
