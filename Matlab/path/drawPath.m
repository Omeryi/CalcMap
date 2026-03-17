function lineHandle = drawPath(ax, pathPoints)

lineHandle = [];
if nargin < 2 || isempty(pathPoints)
    return
end

hold(ax, "on")
lineHandle = plot(ax, pathPoints(:,1), pathPoints(:,2), "r-", "LineWidth", 1);
hold(ax, "off")

end
