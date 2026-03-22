function renderCache = updatePathOverlay(ax, renderCache, mapState, pathPoints)

if nargin < 2 || ~isstruct(renderCache)
    renderCache = struct("ImageHandle", [], "PathHaloHandle", [], "PathHandle", []);
end
if nargin < 3
    mapState = struct();
end
if nargin < 4
    pathPoints = [];
end

if ~isfield(renderCache, "ImageHandle") || isempty(renderCache.ImageHandle) || ~isgraphics(renderCache.ImageHandle)
    return
end
if ~isfield(renderCache, "PathHaloHandle")
    renderCache.PathHaloHandle = [];
end
if ~isfield(renderCache, "PathHandle")
    renderCache.PathHandle = [];
end

composeTimer = tic;
renderCache.ImageHandle.CData = mapState.BaseImage;
if isempty(pathPoints)
    renderCache = deletePathHandles(renderCache);
    fprintf("updatePathOverlay: display path %.3f s\n", toc(composeTimer));
    return
end

renderCache = upsertPathHandles(ax, renderCache, pathPoints);
fprintf("updatePathOverlay: display path %.3f s\n", toc(composeTimer));

end

function renderCache = upsertPathHandles(ax, renderCache, pathPoints)

pathHaloStyle = { ...
    "Color", [0 0 0], ...
    "LineWidth", 4.5, ...
    "Clipping", "on", ...
    "HitTest", "off", ...
    "PickableParts", "none"};
pathStyle = { ...
    "Color", [0.1 1 0.1], ...
    "LineWidth", 2.5, ...
    "Clipping", "on", ...
    "HitTest", "off", ...
    "PickableParts", "none"};

markerSymbol = "none";
markerIndices = [];
if size(pathPoints, 1) == 1
    markerSymbol = "o";
    markerIndices = 1;
end

needsCreate = ~isGraphicsHandle(renderCache.PathHaloHandle) ...
    || ~isGraphicsHandle(renderCache.PathHandle);
if needsCreate
    renderCache = deletePathHandles(renderCache);
    holdState = ishold(ax);
    hold(ax, "on");
    renderCache.PathHaloHandle = plot(ax, pathPoints(:, 1), pathPoints(:, 2), "-", pathHaloStyle{:});
    renderCache.PathHandle = plot(ax, pathPoints(:, 1), pathPoints(:, 2), "-", pathStyle{:}, ...
        "Marker", markerSymbol, ...
        "MarkerIndices", markerIndices, ...
        "MarkerSize", 7, ...
        "MarkerFaceColor", [0.1 1 0.1], ...
        "MarkerEdgeColor", [0 0 0]);
    if ~holdState
        hold(ax, "off");
    end
    return
end

renderCache.PathHaloHandle.XData = pathPoints(:, 1);
renderCache.PathHaloHandle.YData = pathPoints(:, 2);
renderCache.PathHandle.XData = pathPoints(:, 1);
renderCache.PathHandle.YData = pathPoints(:, 2);
renderCache.PathHandle.Marker = markerSymbol;
if isempty(markerIndices)
    renderCache.PathHandle.MarkerIndices = [];
else
    renderCache.PathHandle.MarkerIndices = markerIndices;
end

end

function renderCache = deletePathHandles(renderCache)

if isfield(renderCache, "PathHaloHandle") ...
        && isGraphicsHandle(renderCache.PathHaloHandle)
    delete(renderCache.PathHaloHandle);
end
if isfield(renderCache, "PathHandle") ...
        && isGraphicsHandle(renderCache.PathHandle)
    delete(renderCache.PathHandle);
end

renderCache.PathHaloHandle = [];
renderCache.PathHandle = [];

end

function tf = isGraphicsHandle(handleValue)

tf = ~isempty(handleValue) && isgraphics(handleValue) && isscalar(handleValue);

end
