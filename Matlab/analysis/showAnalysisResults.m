function showAnalysisResults(analysisOutput, resultFile, mapState, pathPoints, pathFile, mapAxes)

[tableData, totalMs] = buildAnalysisTableData(analysisOutput, mapState);
if isempty(tableData)
    error("showAnalysisResults:EmptyResults", "No analysis results were returned.");
end

[~, resultName, resultExt] = fileparts(char(resultFile));
[~, pathName, pathExt] = fileparts(char(pathFile));
avgMs = totalMs / size(tableData, 1);
pathLength = getPathLength(pathPoints);
pathPointCount = size(pathPoints, 1);
pathResolution = getPathResolution(pathPoints);
threatResolution = getThreatResolution(mapState.Threats);
mapGuid = getMapGuid(mapState);

columnWidths = [90 300 130 130 120];
tableWidth = sum(columnWidths);
tableHeight = min(14, size(tableData, 1)) * 22 + 28;
figureWidth = max(tableWidth + 40, 980);
figureHeight = max(tableHeight + 150, 500);
tableWidth = figureWidth - 40;
tableHeight = figureHeight - 150;

resultsFigure = uifigure( ...
    "Name", sprintf("Analysis Results - %s%s", resultName, resultExt), ...
    "Position", [180 140 figureWidth figureHeight], ...
    "WindowStyle", "modal");

summaryLabel1 = uilabel(resultsFigure);
summaryLabel1.Position = [20 figureHeight - 46 figureWidth - 40 32];
summaryLabel1.FontWeight = "bold";
summaryLabel1.WordWrap = "on";
summaryLabel1.Text = sprintf("Map: %s | Path: %s%s | Total: %.3f ms | Avg/threat: %.3f ms", ...
    char(mapGuid), pathName, pathExt, totalMs, avgMs);

summaryLabel2 = uilabel(resultsFigure);
summaryLabel2.Position = [20 figureHeight - 82 figureWidth - 40 28];
summaryLabel2.WordWrap = "on";
summaryLabel2.Text = sprintf("Path length: %.3f | Path points: %d | Path resolution: %.3f | Threat resolution: %.3f", ...
    pathLength, pathPointCount, pathResolution, threatResolution);

resultsTable = uitable(resultsFigure);
resultsTable.Position = [20 56 tableWidth tableHeight];
resultsTable.ColumnName = {"Threat #", "Threat Id", "Center X", "Center Y", "Grade"};
resultsTable.ColumnWidth = num2cell(columnWidths);
resultsTable.ColumnFormat = {'char', 'char', 'numeric', 'numeric', 'numeric'};
resultsTable.Data = tableData;

closeButton = uibutton(resultsFigure, "push");
closeButton.Position = [figureWidth - 100 14 80 28];
closeButton.Text = "Close";
closeButton.ButtonPushedFcn = @(~, ~) delete(resultsFigure);

saveScreenshotsButton = uibutton(resultsFigure, "push");
saveScreenshotsButton.Position = [figureWidth - 250 14 130 28];
saveScreenshotsButton.Text = "Save Screenshots";
saveScreenshotsButton.ButtonPushedFcn = @(~, ~) saveScreenshots();

    function saveScreenshots()
        if ~isgraphics(resultsFigure)
            error("showAnalysisResults:InvalidResultsFigure", "Results window is no longer valid.");
        end

        if ~isgraphics(mapAxes)
            error("showAnalysisResults:InvalidMapAxes", "Map axes are no longer valid.");
        end

        currentMapGuid = char(getMapGuid(mapState));
        mapFolder = char(string(mapState.Folder));
        mapsRoot = fileparts(mapFolder);
        repoRoot = fileparts(mapsRoot);
        targetFolder = fullfile(repoRoot, "Results", currentMapGuid, char(string(resultName)));
        if ~isfolder(targetFolder)
            mkdir(targetFolder);
        end

        mapImageFile = fullfile(targetFolder, "map.png");
        resultsImageFile = fullfile(targetFolder, "results.png");

        drawnow;
        exportgraphics(mapAxes, mapImageFile, "Resolution", 200);
        drawnow;
        exportapp(resultsFigure, resultsImageFile);

        uialert(resultsFigure, sprintf("Saved screenshots to:\n%s", targetFolder), "Screenshots saved");
    end

end

function [tableData, totalMs] = buildAnalysisTableData(analysisOutput, mapState)

totalMs = 0;
tableData = cell(0, 5);
if isempty(analysisOutput) || ~isfield(analysisOutput, "Results") || isempty(analysisOutput.Results)
    return
end

totalMs = analysisOutput.TotalElapsedMilliseconds;
results = analysisOutput.Results;
if ~isstruct(results)
    return
end

if isscalar(results)
    results = results(:);
end

rowCount = numel(results);
tableData = cell(rowCount, 5);
gradeValues = NaN(rowCount, 1);

for i = 1:rowCount
    [centerX, centerY, threatNumber] = getThreatCenter(mapState.Threats, results(i).Id);
    if isnan(threatNumber)
        tableData{i, 1} = '';
    else
        tableData{i, 1} = sprintf('T%d', threatNumber);
    end

    tableData{i, 2} = char(string(results(i).Id));
    tableData{i, 3} = double(centerX);
    tableData{i, 4} = double(centerY);
    gradeValues(i) = double(results(i).Grade);
    tableData{i, 5} = gradeValues(i);
end

[~, sortOrder] = sort(gradeValues, "descend");
tableData = tableData(sortOrder, :);

end

function [centerX, centerY, threatNumber] = getThreatCenter(threats, threatId)

centerX = NaN;
centerY = NaN;
threatNumber = NaN;
for i = 1:numel(threats)
    if strcmp(char(string(threats(i).Id)), char(string(threatId)))
        centerX = threats(i).CenterX;
        centerY = threats(i).CenterY;
        threatNumber = i;
        return
    end
end

end

function lengthValue = getPathLength(pathPoints)

lengthValue = 0;
if size(pathPoints, 1) < 2
    return
end

for i = 1:size(pathPoints, 1) - 1
    delta = pathPoints(i + 1, :) - pathPoints(i, :);
    lengthValue = lengthValue + hypot(delta(1), delta(2));
end

end
