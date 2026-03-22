function displayRaster = buildDisplayRaster(mapMatrix, maxRows, maxCols)

if nargin < 2 || isempty(maxRows) || maxRows < 1
    maxRows = 900;
end
if nargin < 3 || isempty(maxCols) || maxCols < 1
    maxCols = 1200;
end

displayRaster = single(mapMatrix);
if isempty(displayRaster)
    return
end

[rowCount, colCount] = size(displayRaster);
stride = max(1, ceil(max(rowCount / maxRows, colCount / maxCols)));
if stride == 1
    return
end

rowIndex = 1:stride:rowCount;
colIndex = 1:stride:colCount;
if rowIndex(end) ~= rowCount
    rowIndex(end + 1) = rowCount;
end
if colIndex(end) ~= colCount
    colIndex(end + 1) = colCount;
end

displayRaster = displayRaster(rowIndex, colIndex);

end
