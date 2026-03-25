function renderCache = renderCachedMap(ax, mapState, renderCache, renderOptions)

requiredFields = {"ImageHandle", "OutlineHandle", "LabelHandles", "PathHaloHandle", "PathHandle", "ShowThreatLabels", "MapKey"};
if nargin < 3 || ~isstruct(renderCache) || ~all(isfield(renderCache, requiredFields))
    renderCache = emptyRenderCache();
end
if nargin < 4 || ~isstruct(renderOptions)
    renderOptions = struct();
end

mapKey = char(string(mapState.JsonFile));
showThreatLabels = false;
if isfield(renderOptions, "ShowThreatLabels")
    showThreatLabels = logical(renderOptions.ShowThreatLabels);
end

displayTimer = tic;
if ~isgraphicsHandle(renderCache.ImageHandle)
    cla(ax);
    colorbar(ax, "off");
    renderCache.ImageHandle = imagesc(ax, ...
        [mapState.XMin, mapState.XMax], ...
        [mapState.YMin, mapState.YMax], ...
        mapState.DisplayImage);
    axis(ax, "xy");
    axis(ax, "equal");
    xlim(ax, [mapState.XMin, mapState.XMax]);
    ylim(ax, [mapState.YMin, mapState.YMax]);
    ax.XLimMode = "manual";
    ax.YLimMode = "manual";
    xlabel(ax, "X");
    ylabel(ax, "Y");
    colormap(ax, "hot");
else
    renderCache.ImageHandle.XData = [mapState.XMin, mapState.XMax];
    renderCache.ImageHandle.YData = [mapState.YMin, mapState.YMax];
    renderCache.ImageHandle.CData = mapState.DisplayImage;
end

hasThreatOutlines = threatSetHasOutlines(mapState.Threats);
hasThreatLabels = threatSetHasLabels(mapState.Threats);
overlayNeedsRefresh = ~strcmp(renderCache.MapKey, mapKey) ...
    || ~isfield(renderCache, "ShowThreatLabels") ...
    || renderCache.ShowThreatLabels ~= showThreatLabels ...
    || (hasThreatOutlines && ~isgraphicsHandle(renderCache.OutlineHandle)) ...
    || (showThreatLabels && hasThreatLabels && ~areGraphicsHandlesValid(renderCache.LabelHandles));
if overlayNeedsRefresh
    renderCache = rebuildThreatOverlay(ax, renderCache, mapState.Threats, showThreatLabels);
end

renderCache.MapKey = mapKey;
renderCache.ShowThreatLabels = showThreatLabels;
title(ax, "Map: " + formatMapDisplayName(mapState));
fprintf("renderCachedMap: display %.3f s\n", toc(displayTimer));
fprintf("renderCachedMap: axes children %d\n", numel(ax.Children));

end

function tf = isgraphicsHandle(handleValue)

tf = ~isempty(handleValue) && isgraphics(handleValue);

end

function renderCache = emptyRenderCache()

renderCache = struct( ...
    "MapKey", "", ...
    "ImageHandle", [], ...
    "OutlineHandle", [], ...
    "LabelHandles", [], ...
    "PathHaloHandle", [], ...
    "PathHandle", [], ...
    "ShowThreatLabels", false);

end

function renderCache = rebuildThreatOverlay(ax, renderCache, threats, showThreatLabels)

deleteGraphicsHandle(renderCache.OutlineHandle);
deleteGraphicsHandles(renderCache.LabelHandles);

renderCache.OutlineHandle = [];
renderCache.LabelHandles = [];

overlay = buildThreatOverlayData(threats);
if isempty(overlay.OutlineX) && (~showThreatLabels || isempty(overlay.LabelText))
    return
end

wasHolding = ishold(ax);
hold(ax, "on");

if ~isempty(overlay.OutlineX)
    renderCache.OutlineHandle = plot(ax, overlay.OutlineX, overlay.OutlineY, ...
        "Color", [0 0.2 0.8], ...
        "LineWidth", 0.75, ...
        "Clipping", "on", ...
        "HitTest", "off", ...
        "PickableParts", "none");
end

if showThreatLabels && ~isempty(overlay.LabelText)
    labelCount = numel(overlay.LabelText);
    labelHandles = gobjects(labelCount, 1);
    for i = 1:labelCount
        labelHandles(i) = text(ax, overlay.LabelX(i), overlay.LabelY(i), overlay.LabelText{i}, ...
            "Color", [0 0 0], ...
            "BackgroundColor", [1 1 0], ...
            "FontSize", 8, ...
            "FontWeight", "bold", ...
            "Interpreter", "none", ...
            "VerticalAlignment", "bottom", ...
            "HorizontalAlignment", "left", ...
            "Clipping", "on", ...
            "HitTest", "off", ...
            "PickableParts", "none");
    end
    renderCache.LabelHandles = labelHandles;
end

if ~wasHolding
    hold(ax, "off");
end

end

function tf = areGraphicsHandlesValid(handles)

if isempty(handles)
    tf = true;
    return
end

tf = all(isgraphics(handles));

end

function deleteGraphicsHandle(handleValue)

if isgraphicsHandle(handleValue)
    delete(handleValue);
end

end

function deleteGraphicsHandles(handles)

if isempty(handles)
    return
end

validHandles = handles(isgraphics(handles));
if ~isempty(validHandles)
    delete(validHandles);
end

end

function tf = threatSetHasOutlines(threats)

if isempty(threats)
    tf = false;
    return
end

tf = false;
for i = 1:numel(threats)
    if isfield(threats(i), "Radius") && isfinite(threats(i).Radius) && threats(i).Radius > 0
        tf = true;
        return
    end
end

end

function tf = threatSetHasLabels(threats)

if isempty(threats)
    tf = false;
    return
end

tf = false;
for i = 1:numel(threats)
    if isfield(threats(i), "CenterX") && isfield(threats(i), "CenterY") ...
            && isfinite(threats(i).CenterX) && isfinite(threats(i).CenterY)
        tf = true;
        return
    end
end

end
