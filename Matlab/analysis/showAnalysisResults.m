function showAnalysisResults(analysisOutput, resultFile, mapState, pathPoints, pathFile)

[tableData, totalMs] = buildAnalysisTableData(analysisOutput, mapState);
if isempty(tableData)
    error("showAnalysisResults:EmptyResults", "No analysis results were returned.");
end

[~, resultName, resultExt] = fileparts(char(resultFile));
[~, pathName, pathExt] = fileparts(char(pathFile));
avgMs = totalMs / size(tableData, 1);
pathLength = getPathLength(pathPoints);
pathResolution = getPathResolution(pathPoints);
threatResolution = getThreatResolution(mapState.Threats);

columnWidths = [300 130 130 120];
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
    char(mapState.Name), pathName, pathExt, totalMs, avgMs);

summaryLabel2 = uilabel(resultsFigure);
summaryLabel2.Position = [20 figureHeight - 82 figureWidth - 40 28];
summaryLabel2.WordWrap = "on";
summaryLabel2.Text = sprintf("Path length: %.3f | Path resolution: %.3f | Threat resolution: %.3f", ...
    pathLength, pathResolution, threatResolution);

resultsTable = uitable(resultsFigure);
resultsTable.Position = [20 56 tableWidth tableHeight];
resultsTable.ColumnName = {"Threat Id", "Center X", "Center Y", "Grade"};
resultsTable.ColumnWidth = num2cell(columnWidths);
resultsTable.Data = tableData;

closeButton = uibutton(resultsFigure, "push");
closeButton.Position = [figureWidth - 100 14 80 28];
closeButton.Text = "Close";
closeButton.ButtonPushedFcn = @(~, ~) delete(resultsFigure);

end

function [tableData, totalMs] = buildAnalysisTableData(analysisOutput, mapState)

totalMs = 0;
tableData = cell(0, 4);
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

tableData = cell(numel(results), 4);
for i = 1:numel(results)
    [centerX, centerY] = getThreatCenter(mapState.Threats, results(i).Id);
    tableData{i, 1} = char(string(results(i).Id));
    tableData{i, 2} = centerX;
    tableData{i, 3} = centerY;
    tableData{i, 4} = results(i).Grade;
end

end

function [centerX, centerY] = getThreatCenter(threats, threatId)

centerX = NaN;
centerY = NaN;
for i = 1:numel(threats)
    if strcmp(char(string(threats(i).Id)), char(string(threatId)))
        centerX = threats(i).CenterX;
        centerY = threats(i).CenterY;
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

function resolution = getThreatResolution(threats)

resolution = NaN;
if isempty(threats)
    return
end

if isfield(threats, "Resolution")
    resolution = threats(1).Resolution;
end

end
