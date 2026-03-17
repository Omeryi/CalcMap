function resolution = getPathResolution(pathPoints)

resolution = NaN;
if size(pathPoints, 1) < 2
    return
end

segmentLengths = zeros(size(pathPoints, 1) - 1, 1);
for i = 1:size(pathPoints, 1) - 1
    delta = pathPoints(i + 1, :) - pathPoints(i, :);
    segmentLengths(i) = hypot(delta(1), delta(2));
end

resolution = mean(segmentLengths);

end
