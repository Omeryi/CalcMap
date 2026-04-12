function points = collectPathPoints(fig, ax, mapName, mapState, existingPath, renderOptions, targetSpacing)

if nargin < 5
    existingPath = [];
end
if nargin < 6
    renderOptions = struct();
end
if nargin < 7 || ~isfinite(targetSpacing) || targetSpacing <= 0
    error("collectPathPoints:InvalidTargetSpacing", ...
        "Target path spacing must be a positive finite number.");
end
mapLabel = string(mapName);
if nargin >= 4 && ~isempty(mapState)
    formattedName = formatMapDisplayName(mapState);
    if strlength(formattedName) > 0
        mapLabel = formattedName;
    end
end

renderCache = renderCachedMap(ax, mapState, struct(), renderOptions);
renderCache = updatePathOverlay(ax, renderCache, mapState, existingPath);

originalButtonDownFcn = fig.WindowButtonDownFcn;
originalKeyPressFcn = fig.WindowKeyPressFcn;
originalPointer = fig.Pointer;
originalXLimMode = ax.XLimMode;
originalYLimMode = ax.YLimMode;
originalNextPlot = ax.NextPlot;
xLimits = xlim(ax);
yLimits = ylim(ax);

points = zeros(0, 2);
cancelled = false;
hold(ax, "on");
ax.XLimMode = "manual";
ax.YLimMode = "manual";
xlim(ax, xLimits);
ylim(ax, yLimits);
updateDrawTitle();

fig.Pointer = "crosshair";
fig.WindowButtonDownFcn = @handleMouseClick;
fig.WindowKeyPressFcn = @handleKeyPress;

try
    uiwait(fig);
catch
    cancelled = true;
end
restoreInteractionState();

if cancelled
    points = [];
elseif ~isempty(points)
    points = resamplePathBySpacing(points, targetSpacing);
end

    function handleMouseClick(~, ~)
        clickedObject = hittest(fig);
        if isempty(clickedObject)
            return
        end

        clickedAxes = ancestor(clickedObject, "axes");
        if ~isequal(clickedObject, ax) && ~isequal(clickedAxes, ax)
            return
        end

        currentPoint = ax.CurrentPoint;
        point = currentPoint(1, 1:2);
        if point(1) < xLimits(1) || point(1) > xLimits(2) || ...
                point(2) < yLimits(1) || point(2) > yLimits(2)
            return
        end

        points(end + 1, :) = point;
        % Preview the raw clicked polyline so the user sees every segment
        % immediately, while the title still reports the sampled path count.
        renderCache = updatePathOverlay(ax, renderCache, mapState, points);
        updateDrawTitle();
    end

    function handleKeyPress(~, event)
        switch event.Key
            case {"return", "enter"}
                if strcmp(fig.WaitStatus, "waiting")
                    uiresume(fig);
                end
            case "escape"
                cancelled = true;
                if strcmp(fig.WaitStatus, "waiting")
                    uiresume(fig);
                end
        end
    end

    function restoreInteractionState()
        if isgraphics(fig)
            fig.WindowButtonDownFcn = originalButtonDownFcn;
            fig.WindowKeyPressFcn = originalKeyPressFcn;
            fig.Pointer = originalPointer;
        end

        if isgraphics(ax)
            ax.XLimMode = originalXLimMode;
            ax.YLimMode = originalYLimMode;
            ax.NextPlot = originalNextPlot;
            title(ax, "Map: " + mapLabel);
        end
    end

    function updateDrawTitle()
        clickedPointCount = size(points, 1);
        approximateSavedPointCount = getApproximateSavedPointCount(points, targetSpacing);
        title(ax, sprintf([ ...
            'Map: %s | Click points, ENTER to finish, ESC to cancel | ' ...
            'Target spacing %.3f | Clicked %d | Saved points %d'], ...
            char(mapLabel), targetSpacing, clickedPointCount, approximateSavedPointCount));
    end

    function approximateSavedPointCount = getApproximateSavedPointCount(pathPoints, spacing)
        if isempty(pathPoints)
            approximateSavedPointCount = 0;
            return
        end

        approximateSavedPointCount = size(resamplePathBySpacing(pathPoints, spacing), 1);
    end

end
