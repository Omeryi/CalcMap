function points = collectPathPoints(fig, ax, mapName, mapState, existingPath, renderOptions)

if nargin < 5
    existingPath = [];
end
if nargin < 6
    renderOptions = struct();
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
title(ax, "Map: " + mapLabel + " | Click points, ENTER to finish, ESC to cancel");

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
        renderCache = updatePathOverlay(ax, renderCache, mapState, points);
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

end
