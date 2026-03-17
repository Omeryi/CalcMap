function sampled = resamplePathBySpacing(pathPoints, spacing)

if nargin < 2 || spacing <= 0
    error("resamplePathBySpacing:InvalidSpacing", "Spacing must be positive.");
end

if size(pathPoints, 1) < 2
    sampled = pathPoints;
    return
end

segmentLengths = zeros(size(pathPoints, 1) - 1, 1);
for i = 1:size(pathPoints, 1) - 1
    delta = pathPoints(i + 1, :) - pathPoints(i, :);
    segmentLengths(i) = hypot(delta(1), delta(2));
end

keepMask = [true; segmentLengths > 0];
pathPoints = pathPoints(keepMask, :);
segmentLengths = segmentLengths(segmentLengths > 0);

if size(pathPoints, 1) < 2
    sampled = pathPoints;
    return
end

cumulative = [0; cumsum(segmentLengths)];
totalLength = cumulative(end);
query = (0:spacing:totalLength).';
if isempty(query) || abs(query(end) - totalLength) > max(1e-9, spacing * 1e-6)
    query(end + 1, 1) = totalLength; %#ok<AGROW>
end

sampled = zeros(numel(query), 2);
sampled(:, 1) = interp1(cumulative, pathPoints(:, 1), query, "linear");
sampled(:, 2) = interp1(cumulative, pathPoints(:, 2), query, "linear");

end
