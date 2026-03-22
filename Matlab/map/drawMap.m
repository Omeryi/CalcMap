function lineHandle = drawMap(ax, mapState, pathPoints, renderOptions)

if nargin < 3
    pathPoints = [];
end
if nargin < 4
    renderOptions = struct();
end

% Compose the base heatmap first, then overlay the current path.
renderCache = renderCachedMap(ax, mapState, struct(), renderOptions);
renderCache = updatePathOverlay(ax, renderCache, mapState, pathPoints);
lineHandle = renderCache.ImageHandle;
title(ax, "Map: " + formatMapDisplayName(mapState));

end
