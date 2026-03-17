classdef calcMapApp < matlab.apps.AppBase

    properties (Access = public)
        UIFigure matlab.ui.Figure
        UIAxes matlab.ui.control.UIAxes
        LoadMapButton matlab.ui.control.Button
        GenerateMapButton matlab.ui.control.Button
        DrawPathButton matlab.ui.control.Button
        SavePathButton matlab.ui.control.Button
        LoadPathButton matlab.ui.control.Button
        AnalyzeButton matlab.ui.control.Button
        StatusLabel matlab.ui.control.Label
    end

    properties (Access = private)
        Map = []
        MapFolder = ""
        MapJsonFile = ""
        MapThreats = struct([])
        Path = []
        CurrentPathFile = ""
        PathPlot = []
        GenerationParams = struct( ...
            "XMin",-100, ...
            "XMax",100, ...
            "YMin",-100, ...
            "YMax",100, ...
            "RegionCount",10, ...
            "RadiusMin",10, ...
            "RadiusMax",30)
        CurrentMapName = "Map"
    end

    methods (Access = private)

        function updateStatus(app, message)
            app.StatusLabel.Text = "Status: " + string(message);
        end

        function repoRoot = getRepoRoot(app)
            appFile = which(class(app));
            repoRoot = fileparts(fileparts(appFile));
        end

        function mapGeneratorExe = getMapGeneratorExe(app)
            repoRoot = app.getRepoRoot();
            mapGeneratorExe = fullfile(repoRoot, "MapGenerator", "bin", "x64", "Release", "MapGenerator.exe");
        end

        function runAnalyzerExe = getRunAnalyzerExe(app)
            repoRoot = app.getRepoRoot();
            runAnalyzerExe = fullfile(repoRoot, "RunAnalyzer", "bin", "x64", "Release", "RunAnalyzer.exe");
        end

        function clearPathPlot(app)
            if ~isempty(app.PathPlot) && isgraphics(app.PathPlot)
                delete(app.PathPlot);
            end
            app.PathPlot = [];
        end

        function showPath(app, pathPoints)
            app.clearPathPlot();
            if isempty(pathPoints)
                return
            end

            hold(app.UIAxes, "on")
            app.PathPlot = plot(app.UIAxes, pathPoints(:,1), pathPoints(:,2), "r-", "LineWidth", 2);
            hold(app.UIAxes, "off")
        end

        function loadMapIntoApp(app, jsonFile, mapFolder, mapName)
            [map, xmin, xmax, ymin, ymax] = readMap(jsonFile);
            mapData = jsondecode(fileread(jsonFile));
            displayMap(app.UIAxes, map, xmin, xmax, ymin, ymax, mapData.Threats)
            if nargin < 4 || strlength(string(mapName)) == 0 || strcmpi(string(mapName), "map")
                [~, mapName] = fileparts(char(mapFolder));
            end
            if strlength(string(mapName)) == 0 || strcmpi(string(mapName), "map")
                [parentFolder, ~, ~] = fileparts(char(jsonFile));
                [~, mapName] = fileparts(parentFolder);
            end
            app.CurrentMapName = string(mapName);
            title(app.UIAxes, "Map: " + app.CurrentMapName)
            app.Map = map;
            app.MapFolder = string(mapFolder);
            app.MapJsonFile = string(jsonFile);
            app.MapThreats = mapData.Threats;
            app.Path = [];
            app.CurrentPathFile = "";
            app.clearPathPlot();
            app.updateStatus("Loaded map: " + app.CurrentMapName);
        end

        function LoadMapButtonPushed(app, ~)
            startFolder = fullfile(app.getRepoRoot(), "Maps");
            [file, path] = uigetfile(fullfile(startFolder, "*.json"), "Select map");
            if isequal(file, 0)
                app.updateStatus("Load map cancelled");
                return
            end

            selectedFile = fullfile(path, file);
            mapFolder = fileparts(selectedFile);
            [~, mapName] = fileparts(mapFolder);
            app.loadMapIntoApp(selectedFile, mapFolder, mapName);
        end

        function [ok, params] = promptMapParameters(app)
            params = app.GenerationParams;
            prompt = {
                "X Min"
                "X Max"
                "Y Min"
                "Y Max"
                "Region Count"
                "Radius Min"
                "Radius Max"
                };
            defaults = {
                num2str(params.XMin)
                num2str(params.XMax)
                num2str(params.YMin)
                num2str(params.YMax)
                num2str(params.RegionCount)
                num2str(params.RadiusMin)
                num2str(params.RadiusMax)
                };

            answer = inputdlg(prompt, "Generate Map Parameters", [1 50], defaults);
            if isempty(answer)
                ok = false;
                return
            end

            values = str2double(answer);
            if any(isnan(values)) || any(~isfinite(values))
                uialert(app.UIFigure, "All values must be valid numbers.", "Invalid parameters");
                ok = false;
                return
            end

            params.XMin = values(1);
            params.XMax = values(2);
            params.YMin = values(3);
            params.YMax = values(4);
            params.RegionCount = values(5);
            params.RadiusMin = values(6);
            params.RadiusMax = values(7);

            if params.XMax <= params.XMin || params.YMax <= params.YMin
                uialert(app.UIFigure, "Max bounds must be greater than min bounds.", "Invalid bounds");
                ok = false;
                return
            end

            if params.RegionCount < 1 || abs(params.RegionCount - round(params.RegionCount)) > 0
                uialert(app.UIFigure, "Region Count must be a positive integer.", "Invalid region count");
                ok = false;
                return
            end

            if params.RadiusMin <= 0 || params.RadiusMax < params.RadiusMin
                uialert(app.UIFigure, "Radii must be positive and Radius Max must be >= Radius Min.", "Invalid radii");
                ok = false;
                return
            end

            params.RegionCount = round(params.RegionCount);
            ok = true;
        end

        function GenerateMapButtonPushed(app, ~)
            exe = app.getMapGeneratorExe();
            if ~isfile(exe)
                uialert(app.UIFigure, "MapGenerator.exe was not found.", "Missing executable");
                app.updateStatus("Map generator not found");
                return
            end

            [ok, params] = app.promptMapParameters();
            if ~ok
                app.updateStatus("Generate map cancelled");
                return
            end
            app.GenerationParams = params;

            argText = sprintf("%.15g %.15g %.15g %.15g %d %.15g %.15g", ...
                params.XMin, params.XMax, params.YMin, params.YMax, ...
                params.RegionCount, params.RadiusMin, params.RadiusMax);

            cmd = sprintf('"%s" %s', char(exe), char(argText));
            app.updateStatus("Generating map...");
            [status, output] = system(char(cmd));
            if status ~= 0
                uialert(app.UIFigure, string(strtrim(output)), "Map generation failed");
                app.updateStatus("Map generation failed");
                return
            end

            mapsRoot = fullfile(app.getRepoRoot(), "Maps");
            maps = dir(mapsRoot);
            maps = maps([maps.isdir]);
            maps = maps(~ismember({maps.name}, {'.', '..'}));
            if isempty(maps)
                uialert(app.UIFigure, "No generated maps were found in the Maps folder.", "No maps");
                app.updateStatus("No generated maps found");
                return
            end

            [~, idx] = max([maps.datenum]);
            folder = fullfile(mapsRoot, maps(idx).name);
            jsonFile = fullfile(folder, "map.json");
            if ~isfile(jsonFile)
                uialert(app.UIFigure, "Generated map.json was not found.", "Missing map");
                app.updateStatus("Generated map file missing");
                return
            end

            [~, mapName] = fileparts(folder);
            app.loadMapIntoApp(jsonFile, folder, mapName);
        end

        function [points, cancelled] = collectPathPoints(app)
            fig = app.UIFigure;
            ax = app.UIAxes;

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
            hold(ax, "on")
            ax.XLimMode = "manual";
            ax.YLimMode = "manual";
            xlim(ax, xLimits)
            ylim(ax, yLimits)
            tempPlot = plot(ax, NaN, NaN, "r-o", "LineWidth", 2);
            cleanupObj = onCleanup(@restoreInteractionState);

            fig.Pointer = "crosshair";
            fig.WindowButtonDownFcn = @handleMouseClick;
            fig.WindowKeyPressFcn = @handleKeyPress;

            try
                uiwait(fig);
            catch
                cancelled = true;
            end

            if isgraphics(tempPlot)
                delete(tempPlot);
            end

            function handleMouseClick(~, ~)
                clickedObject = hittest(fig);
                if isempty(clickedObject) || (~isequal(clickedObject, ax) && ~isa(clickedObject, "matlab.graphics.primitive.Image"))
                    return
                end

                currentPoint = ax.CurrentPoint;
                point = currentPoint(1, 1:2);
                if ~app.isPointWithinAxes(point)
                    return
                end

                points(end+1, :) = point; %#ok<AGROW>
                if isgraphics(tempPlot)
                    tempPlot.XData = points(:,1);
                    tempPlot.YData = points(:,2);
                end
            end

            function handleKeyPress(~, event)
                switch event.Key
                    case {"return", "enter"}
                        if strcmp(fig.WaitStatus, "waiting")
                            uiresume(fig);
                        end
                    case "escape"
                        cancelled = true;
                        points = zeros(0, 2);
                        if strcmp(fig.WaitStatus, "waiting")
                            uiresume(fig);
                        end
                end
            end

            function restoreInteractionState
                if isgraphics(fig)
                    fig.WindowButtonDownFcn = originalButtonDownFcn;
                    fig.WindowKeyPressFcn = originalKeyPressFcn;
                    fig.Pointer = originalPointer;
                    ax.XLimMode = originalXLimMode;
                    ax.YLimMode = originalYLimMode;
                    ax.NextPlot = originalNextPlot;
                    if strcmp(fig.WaitStatus, "waiting")
                        uiresume(fig);
                    end
                end
            end
        end

        function tf = isPointWithinAxes(app, point)
            xLimits = xlim(app.UIAxes);
            yLimits = ylim(app.UIAxes);
            tf = point(1) >= min(xLimits) && point(1) <= max(xLimits) && ...
                point(2) >= min(yLimits) && point(2) <= max(yLimits);
        end

        function json = encodePathJson(app, pathPoints)
            out = struct();
            out.Points = struct("X", num2cell(pathPoints(:,1)), "Y", num2cell(pathPoints(:,2)));
            json = jsonencode(out, "PrettyPrint", true);
        end

        function outputFile = writePathFile(app, pathPoints)
            outputFile = app.getNextPathFile();
            json = app.encodePathJson(pathPoints);

            fid = fopen(outputFile, "w");
            if fid < 0
                error("calcMapApp:SavePathFailed", "Failed to open output file for writing.");
            end

            cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
            fprintf(fid, "%s", json);
        end

        function pathFile = ensureCurrentPathFile(app)
            if strlength(app.CurrentPathFile) > 0 && isfile(char(app.CurrentPathFile))
                pathFile = char(app.CurrentPathFile);
                return
            end

            if isempty(app.Path)
                pathFile = "";
                return
            end

            pathFile = app.writePathFile(app.Path);
            app.CurrentPathFile = string(pathFile);
        end

        function resultFile = runAnalyzer(app)
            resultFile = "";

            exe = app.getRunAnalyzerExe();
            if ~isfile(exe)
                uialert(app.UIFigure, "RunAnalyzer.exe was not found.", "Missing executable");
                app.updateStatus("Run analyzer not found");
                return
            end

            if strlength(app.MapJsonFile) == 0 || ~isfile(char(app.MapJsonFile))
                uialert(app.UIFigure, "No map file is available for analysis.", "Missing map file");
                return
            end

            pathFile = app.ensureCurrentPathFile();
            if strlength(string(pathFile)) == 0 || ~isfile(char(pathFile))
                uialert(app.UIFigure, "Draw, load, or save a path before analysis.", "Missing path file");
                return
            end

            cmd = sprintf('"%s" "%s" "%s"', char(exe), char(app.MapJsonFile), char(pathFile));
            app.updateStatus("Running analysis...");
            [status, output] = system(char(cmd));
            if status ~= 0
                uialert(app.UIFigure, string(strtrim(output)), "Analysis failed");
                app.updateStatus("Analysis failed");
                return
            end

            token = regexp(output, 'RESULT_FILE=(.+)', "tokens", "once");
            if isempty(token)
                uialert(app.UIFigure, "RunAnalyzer did not report an output file.", "Analysis failed");
                app.updateStatus("Analysis output missing");
                return
            end

            resultFile = string(strtrim(token{1}));
        end

        function [centerX, centerY] = getThreatCenter(app, threatId)
            centerX = NaN;
            centerY = NaN;
            for i = 1:numel(app.MapThreats)
                if strcmpi(string(app.MapThreats(i).Id), string(threatId))
                    centerX = app.MapThreats(i).CenterX;
                    centerY = app.MapThreats(i).CenterY;
                    return
                end
            end
        end

        function pathLength = getPathLength(app)
            pathLength = 0;
            if size(app.Path, 1) < 2
                return
            end

            deltas = diff(app.Path, 1, 1);
            pathLength = sum(sqrt(sum(deltas.^2, 2)));
        end

        function pathResolution = getPathResolution(app)
            pathResolution = NaN;
            if size(app.Path, 1) < 2
                return
            end

            deltas = diff(app.Path, 1, 1);
            distances = sqrt(sum(deltas.^2, 2));
            distances = distances(distances > 0);
            if isempty(distances)
                return
            end

            pathResolution = mean(distances);
        end

        function threatResolution = getThreatResolution(app)
            threatResolution = NaN;
            if isempty(app.MapThreats)
                return
            end

            if isfield(app.MapThreats, "Resolution")
                threatResolution = app.MapThreats(1).Resolution;
            end
        end

        function [tableData, totalMs] = buildAnalysisTableData(app, analysisOutput)
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
                [centerX, centerY] = app.getThreatCenter(results(i).Id);
                tableData{i,1} = char(string(results(i).Id));
                tableData{i,2} = centerX;
                tableData{i,3} = centerY;
                tableData{i,4} = results(i).Grade;
            end
        end

        function showAnalysisResults(app, analysisOutput, resultFile)
            [tableData, totalMs] = app.buildAnalysisTableData(analysisOutput);
            if isempty(tableData)
                uialert(app.UIFigure, "No analysis results were returned.", "Analysis Results");
                return
            end

            [~, resultName, resultExt] = fileparts(char(resultFile));
            [~, pathName, pathExt] = fileparts(char(app.CurrentPathFile));
            avgMs = totalMs / size(tableData, 1);
            pathLength = app.getPathLength();
            pathResolution = app.getPathResolution();
            threatResolution = app.getThreatResolution();

            columnWidths = [300 130 130 120];
            tableWidth = sum(columnWidths);
            tableHeight = min(14, size(tableData,1)) * 22 + 28;
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
                char(app.CurrentMapName), pathName, pathExt, totalMs, avgMs);

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

        function DrawPathButtonPushed(app, ~)
            if isempty(app.Map)
                uialert(app.UIFigure, "Load or generate a map before drawing a path.", "No map");
                return
            end

            if ~isempty(app.Path)
                choice = questdlg("Path already exists. Choose an action.", "Path", ...
                    "Draw New", "Clear Current", "Cancel", "Draw New");
                if strcmp(choice, "Cancel") || isempty(choice)
                    app.updateStatus("Path draw cancelled");
                    return
                end
                if strcmp(choice, "Clear Current")
                    app.Path = [];
                    app.CurrentPathFile = "";
                    app.clearPathPlot();
                    title(app.UIAxes, "Map: " + app.CurrentMapName)
                    app.updateStatus("Path cleared");
                    return
                end
            end

            app.Path = [];
            app.CurrentPathFile = "";
            app.clearPathPlot();
            title(app.UIAxes, "Click points. Press ENTER to finish. ESC cancels")
            [points, cancelled] = app.collectPathPoints();
            if cancelled || isempty(points)
                title(app.UIAxes, "Map: " + app.CurrentMapName)
                app.updateStatus("Path drawing cancelled");
                return
            end

            app.Path = points;
            title(app.UIAxes, "Map: " + app.CurrentMapName)
            app.showPath(app.Path);
            app.updateStatus("Path updated (" + size(app.Path,1) + " points)");
        end

        function SavePathButtonPushed(app, ~)
            if isempty(app.Path)
                uialert(app.UIFigure, "No path to save.", "Missing path");
                return
            end

            if strlength(app.MapFolder) == 0
                uialert(app.UIFigure, "No map folder is available for saving the path.", "Missing map folder");
                return
            end

            answer = inputdlg({'Resolution (distance between points):'}, ...
                'Save Path', [1 60], {'1'});
            if isempty(answer)
                app.updateStatus("Save path cancelled");
                return
            end
            spacing = str2double(answer{1});
            if isnan(spacing) || ~isfinite(spacing) || spacing <= 0
                uialert(app.UIFigure, "Resolution must be a positive number.", "Invalid resolution");
                return
            end

            sampledPath = app.resamplePathBySpacing(app.Path, spacing);
            try
                outputFile = app.writePathFile(sampledPath);
            catch
                uialert(app.UIFigure, "Failed to open output file for writing.", "Save failed");
                return
            end

            app.CurrentPathFile = string(outputFile);
            [~, outputName, ext] = fileparts(outputFile);
            app.updateStatus("Saved " + outputName + ext + " (" + size(sampledPath,1) + " points)");
        end

        function LoadPathButtonPushed(app, ~)
            if isempty(app.Map)
                uialert(app.UIFigure, "Load or generate a map before loading a path.", "No map");
                return
            end

            if strlength(app.MapFolder) == 0
                uialert(app.UIFigure, "Current scene folder is unknown.", "No scene folder");
                return
            end

            sceneFolder = char(app.MapFolder);
            [file, path] = uigetfile(fullfile(sceneFolder, "path*.json"), "Select path from current scene");
            if isequal(file, 0)
                app.updateStatus("Load path cancelled");
                return
            end

            selectedFile = fullfile(sceneFolder, file);
            if ~isfile(selectedFile)
                uialert(app.UIFigure, "You can only load paths from the current scene folder.", "Invalid path folder");
                return
            end

            app.Path = loadPath(selectedFile);
            app.CurrentPathFile = string(selectedFile);
            app.showPath(app.Path);
            [~, n, e] = fileparts(file);
            app.updateStatus("Loaded " + n + e);
        end

        function AnalyzeButtonPushed(app, ~)
            if isempty(app.Map)
                uialert(app.UIFigure, "Load or generate a map before analysis.", "No map");
                return
            end

            if isempty(app.Path)
                uialert(app.UIFigure, "Draw or load a path before analysis.", "No path");
                return
            end

            resultFile = app.runAnalyzer();
            if strlength(resultFile) == 0 || ~isfile(char(resultFile))
                return
            end

            analysisOutput = jsondecode(fileread(char(resultFile)));
            app.showAnalysisResults(analysisOutput, resultFile);

            [~, outputName, ext] = fileparts(char(resultFile));
            app.updateStatus("Saved " + outputName + ext + " and displayed results");
        end

        function sampled = resamplePathBySpacing(app, pathPoints, spacing)
            if nargin < 3 || spacing <= 0 || size(pathPoints,1) < 2
                sampled = pathPoints;
                return
            end

            sampled = pathPoints(1,:);
            for k = 1:(size(pathPoints,1)-1)
                p0 = pathPoints(k,:);
                p1 = pathPoints(k+1,:);
                d = norm(p1 - p0);
                if d == 0
                    continue
                end
                nSeg = max(1, ceil(d / spacing));
                for j = 1:nSeg
                    t = j / nSeg;
                    sampled(end+1,:) = p0 + t * (p1 - p0); %#ok<AGROW>
                end
            end
        end

        function filePath = getNextPathFile(app)
            sceneFolder = char(app.MapFolder);
            timestamp = string(datetime("now", "Format", "yyyyMMdd_HHmm"));
            baseName = "path_" + timestamp;
            filePath = fullfile(sceneFolder, baseName + ".json");
            suffix = 2;
            while isfile(filePath)
                filePath = fullfile(sceneFolder, baseName + "_" + string(suffix) + ".json");
                suffix = suffix + 1;
            end
        end

        function tf = isSameFolder(app, a, b)
            a = app.normalizeFolder(a);
            b = app.normalizeFolder(b);
            tf = strcmpi(a, b);
        end

        function p = normalizeFolder(app, p)
            p = char(string(p)); %#ok<NASGU>
            p = strrep(p, "/", "\");
            while ~isempty(p) && (p(end) == "\" || p(end) == "/")
                p(end) = [];
            end
        end

        function createComponents(app)

            app.UIFigure = uifigure("Visible", "off");
            app.UIFigure.Position = [100 100 1180 720];
            app.UIFigure.Name = "calcMapApp";

            app.UIAxes = uiaxes(app.UIFigure);
            app.UIAxes.Position = [270 45 875 640];
            title(app.UIAxes, "Map")
            xlabel(app.UIAxes, "X")
            ylabel(app.UIAxes, "Y")
            colormap(app.UIAxes, "hot");

            app.LoadMapButton = uibutton(app.UIFigure, "push");
            app.LoadMapButton.ButtonPushedFcn = createCallbackFcn(app, @LoadMapButtonPushed, true);
            app.LoadMapButton.Position = [35 590 190 38];
            app.LoadMapButton.Text = "Load Map";

            app.GenerateMapButton = uibutton(app.UIFigure, "push");
            app.GenerateMapButton.ButtonPushedFcn = createCallbackFcn(app, @GenerateMapButtonPushed, true);
            app.GenerateMapButton.Position = [35 542 190 38];
            app.GenerateMapButton.Text = "Generate Map";

            app.DrawPathButton = uibutton(app.UIFigure, "push");
            app.DrawPathButton.ButtonPushedFcn = createCallbackFcn(app, @DrawPathButtonPushed, true);
            app.DrawPathButton.Position = [35 418 190 38];
            app.DrawPathButton.Text = "Draw Path";

            app.SavePathButton = uibutton(app.UIFigure, "push");
            app.SavePathButton.ButtonPushedFcn = createCallbackFcn(app, @SavePathButtonPushed, true);
            app.SavePathButton.Position = [35 370 190 38];
            app.SavePathButton.Text = "Save Path";

            app.LoadPathButton = uibutton(app.UIFigure, "push");
            app.LoadPathButton.ButtonPushedFcn = createCallbackFcn(app, @LoadPathButtonPushed, true);
            app.LoadPathButton.Position = [35 322 190 38];
            app.LoadPathButton.Text = "Load Path";

            app.AnalyzeButton = uibutton(app.UIFigure, "push");
            app.AnalyzeButton.ButtonPushedFcn = createCallbackFcn(app, @AnalyzeButtonPushed, true);
            app.AnalyzeButton.Position = [35 198 190 38];
            app.AnalyzeButton.Text = "Analyze";

            app.StatusLabel = uilabel(app.UIFigure);
            app.StatusLabel.Position = [35 40 210 120];
            app.StatusLabel.WordWrap = "on";
            app.StatusLabel.Text = "Status: Ready";

            app.UIFigure.Visible = "on";
        end
    end

    methods (Access = public)

        function app = calcMapApp
            createComponents(app)
            registerApp(app, app.UIFigure)

            if nargout == 0
                clear app
            end
        end

        function delete(app)
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                delete(app.UIFigure)
            end
        end
    end
end
