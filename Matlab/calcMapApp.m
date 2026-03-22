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
        ResetButton matlab.ui.control.Button
        ThreatLabelsCheckBox matlab.ui.control.CheckBox
        StatusLabel matlab.ui.control.Label
    end

    properties (Access = private)
        Map = []
        Path = []
        CurrentPathFile = ""
        GenerationParams = []
        RenderedMapFile = ""
        RenderedShowThreatLabels = false
        PathLineHandle = []
    end

    methods (Access = private)

        function updateStatus(app, message)
            app.StatusLabel.Text = "Status: " + string(message);
        end

        function renderScene(app, forceFullRedraw)
            if nargin < 2
                forceFullRedraw = false;
            end

            if isempty(app.Map)
                cla(app.UIAxes);
                colorbar(app.UIAxes, "off");
                title(app.UIAxes, "Map");
                xlabel(app.UIAxes, "X");
                ylabel(app.UIAxes, "Y");
                app.clearRenderCache();
                return
            end

            mapFile = string(app.Map.JsonFile);
            showThreatLabels = logical(app.ThreatLabelsCheckBox.Value);
            needsFullRedraw = forceFullRedraw ...
                || strlength(app.RenderedMapFile) == 0 ...
                || mapFile ~= app.RenderedMapFile ...
                || showThreatLabels ~= app.RenderedShowThreatLabels;

            if needsFullRedraw
                % Rebuild the static map layers only when the source map or overlay mode changes.
                app.PathLineHandle = drawMap(app.UIAxes, app.Map, app.Path, app.buildRenderOptions());
                app.RenderedMapFile = mapFile;
                app.RenderedShowThreatLabels = showThreatLabels;
                return
            end

            app.refreshPathOverlay();
        end

        function renderOptions = buildRenderOptions(app)
            renderOptions = struct( ...
                "ShowThreatLabels", logical(app.ThreatLabelsCheckBox.Value));
        end

        function refreshPathOverlay(app)
            if ~isempty(app.PathLineHandle) && isgraphics(app.PathLineHandle)
                delete(app.PathLineHandle);
            end

            app.PathLineHandle = drawPath(app.UIAxes, app.Path);
            title(app.UIAxes, "Map: " + formatMapDisplayName(app.Map));
        end

        function clearRenderCache(app)
            if ~isempty(app.PathLineHandle) && isgraphics(app.PathLineHandle)
                delete(app.PathLineHandle);
            end

            app.RenderedMapFile = "";
            app.RenderedShowThreatLabels = false;
            app.PathLineHandle = [];
        end

        function resetScene(app)
            app.Map = [];
            app.Path = [];
            app.CurrentPathFile = "";
            app.ThreatLabelsCheckBox.Value = false;
            app.clearRenderCache();
            app.renderScene(true);
        end

        function LoadMapButtonPushed(app, ~)
            try
                selectedFile = selectMapFile(getRepoRoot());
                if strlength(selectedFile) == 0
                    app.updateStatus("Load map cancelled");
                    return
                end

                app.Map = loadMap(selectedFile);
                app.Path = [];
                app.CurrentPathFile = "";
                app.clearRenderCache();
                app.renderScene(true);
                app.updateStatus("Loaded map: " + app.Map.Name);
            catch ME
                uialert(app.UIFigure, string(ME.message), "Load map failed");
                app.updateStatus("Load map failed");
            end
        end

        function GenerateMapButtonPushed(app, ~)
            try
                [ok, params] = promptMapParameters(app.GenerationParams);
                if ~ok
                    app.updateStatus("Generate map cancelled");
                    return
                end

                app.GenerationParams = params;
                app.Map = generateMap(getRepoRoot(), params);
                app.Path = [];
                app.CurrentPathFile = "";
                app.clearRenderCache();
                app.renderScene(true);
                app.updateStatus("Generated map: " + app.Map.Name);
            catch ME
                uialert(app.UIFigure, string(ME.message), "Generate map failed");
                app.updateStatus("Generate map failed");
            end
        end

        function DrawPathButtonPushed(app, ~)
            if isempty(app.Map)
                uialert(app.UIFigure, "Load or generate a map before drawing a path.", "No map");
                return
            end

            try
                app.updateStatus("Drawing path...");
                points = collectPathPoints(app.UIFigure, app.UIAxes, app.Map.Name, app.Map, app.Path, app.buildRenderOptions());
                if isempty(points)
                    app.renderScene();
                    app.updateStatus("Draw path cancelled");
                    return
                end

                app.Path = points;
                app.CurrentPathFile = "";
                app.renderScene();
                app.updateStatus("Path updated");
            catch ME
                uialert(app.UIFigure, string(ME.message), "Draw path failed");
                app.renderScene(true);
                app.updateStatus("Draw path failed");
            end
        end

        function SavePathButtonPushed(app, ~)
            if isempty(app.Map)
                uialert(app.UIFigure, "Load or generate a map before saving a path.", "No map");
                return
            end

            if isempty(app.Path)
                uialert(app.UIFigure, "Draw or load a path before saving.", "No path");
                return
            end

            try
                currentResolution = getPathResolution(app.Path);
                threatResolution = getThreatResolution(app.Map.Threats);
                % Use a coarser saved path by default so exported paths do not
                % oversample relative to the threat grid.
                defaultSpacing = 2 * threatResolution;
                if ~isfinite(defaultSpacing) || defaultSpacing <= 0
                    defaultSpacing = currentResolution;
                end

                [ok, spacing] = promptPathResolution(defaultSpacing, currentResolution);
                if ~ok
                    app.updateStatus("Save path cancelled");
                    return
                end

                [savedFile, savedPath] = savePath(app.Map.Folder, app.Path, spacing);
                app.Path = savedPath;
                app.CurrentPathFile = string(savedFile);
                app.renderScene();
                app.updateStatus(sprintf("Saved path (spacing %.3f): %s", spacing, char(app.CurrentPathFile)));
            catch ME
                uialert(app.UIFigure, string(ME.message), "Save path failed");
                app.updateStatus("Save path failed");
            end
        end

        function LoadPathButtonPushed(app, ~)
            if isempty(app.Map)
                uialert(app.UIFigure, "Load or generate a map before loading a path.", "No map");
                return
            end

            try
                selectedFile = selectPathFile(app.Map.Folder);
                if strlength(selectedFile) == 0
                    app.updateStatus("Load path cancelled");
                    return
                end

                app.Path = loadPath(selectedFile);
                app.CurrentPathFile = selectedFile;
                app.renderScene();
                app.updateStatus("Loaded path: " + selectedFile);
            catch ME
                uialert(app.UIFigure, string(ME.message), "Load path failed");
                app.updateStatus("Load path failed");
            end
        end

        function ResetButtonPushed(app, ~)
            app.resetScene();
            app.updateStatus("Reset map and path state");
        end

        function ThreatLabelsCheckBoxValueChanged(app, ~)
            if isempty(app.Map)
                return
            end

            app.renderScene(true);
            if app.ThreatLabelsCheckBox.Value
                app.updateStatus("Threat labels shown");
            else
                app.updateStatus("Threat labels hidden");
            end
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

            try
                app.updateStatus("Running analysis...");
                result = runAnalysis(getRepoRoot(), app.Map, app.Path, app.CurrentPathFile);
                showAnalysisResults(result.Output, result.ResultFile, app.Map, app.Path, result.PathFile);
                [~, name, ext] = fileparts(char(result.ResultFile));
                app.updateStatus("Saved " + name + ext + " and displayed results");
            catch ME
                uialert(app.UIFigure, string(ME.message), "Analysis failed");
                app.updateStatus("Analysis failed");
            end
        end

        function createComponents(app)
            app.UIFigure = uifigure("Visible", "off");
            app.UIFigure.AutoResizeChildren = "off";
            app.UIFigure.Position = [100 100 1200 760];
            app.UIFigure.Name = "Map Tool";

            app.UIAxes = uiaxes(app.UIFigure);
            title(app.UIAxes, "Map");
            xlabel(app.UIAxes, "X");
            ylabel(app.UIAxes, "Y");
            colormap(app.UIAxes, "hot");
            app.UIAxes.Position = [250 30 920 700];

            app.LoadMapButton = uibutton(app.UIFigure, "push");
            app.LoadMapButton.Position = [30 640 180 40];
            app.LoadMapButton.Text = "Load Map";
            app.LoadMapButton.ButtonPushedFcn = createCallbackFcn(app, @LoadMapButtonPushed, true);

            app.GenerateMapButton = uibutton(app.UIFigure, "push");
            app.GenerateMapButton.Position = [30 585 180 40];
            app.GenerateMapButton.Text = "Generate Map";
            app.GenerateMapButton.ButtonPushedFcn = createCallbackFcn(app, @GenerateMapButtonPushed, true);

            app.DrawPathButton = uibutton(app.UIFigure, "push");
            app.DrawPathButton.Position = [30 530 180 40];
            app.DrawPathButton.Text = "Draw Path";
            app.DrawPathButton.ButtonPushedFcn = createCallbackFcn(app, @DrawPathButtonPushed, true);

            app.SavePathButton = uibutton(app.UIFigure, "push");
            app.SavePathButton.Position = [30 475 180 40];
            app.SavePathButton.Text = "Save Path";
            app.SavePathButton.ButtonPushedFcn = createCallbackFcn(app, @SavePathButtonPushed, true);

            app.LoadPathButton = uibutton(app.UIFigure, "push");
            app.LoadPathButton.Position = [30 420 180 40];
            app.LoadPathButton.Text = "Load Path";
            app.LoadPathButton.ButtonPushedFcn = createCallbackFcn(app, @LoadPathButtonPushed, true);

            app.AnalyzeButton = uibutton(app.UIFigure, "push");
            app.AnalyzeButton.Position = [30 365 180 40];
            app.AnalyzeButton.Text = "Analyze";
            app.AnalyzeButton.ButtonPushedFcn = createCallbackFcn(app, @AnalyzeButtonPushed, true);

            app.ResetButton = uibutton(app.UIFigure, "push");
            app.ResetButton.Position = [30 310 180 40];
            app.ResetButton.Text = "Reset";
            app.ResetButton.ButtonPushedFcn = createCallbackFcn(app, @ResetButtonPushed, true);

            app.ThreatLabelsCheckBox = uicheckbox(app.UIFigure);
            app.ThreatLabelsCheckBox.Position = [30 270 180 22];
            app.ThreatLabelsCheckBox.Text = "Show Threat Labels";
            app.ThreatLabelsCheckBox.Value = false;
            app.ThreatLabelsCheckBox.ValueChangedFcn = createCallbackFcn(app, @ThreatLabelsCheckBoxValueChanged, true);

            app.StatusLabel = uilabel(app.UIFigure);
            app.StatusLabel.Position = [30 30 180 220];
            app.StatusLabel.WordWrap = "on";
            app.StatusLabel.VerticalAlignment = "top";
            app.StatusLabel.Text = "Status: Ready";

            app.UIFigure.Visible = "on";
        end
    end

    methods (Access = public)

        function app = calcMapApp
            app.configureLogicPaths();
            app.GenerationParams = defaultGenerationParams();
            createComponents(app);
            registerApp(app, app.UIFigure);

            if nargout == 0
                clear app
            end
        end

        function delete(app)
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
        end
    end

    methods (Access = private)
        function configureLogicPaths(app) %#ok<MANU>
            matlabRoot = fileparts(mfilename("fullpath"));
            logicFolders = { ...
                fullfile(matlabRoot, "map")
                fullfile(matlabRoot, "path")
                fullfile(matlabRoot, "analysis")
                fullfile(matlabRoot, "common")
                };

            for i = 1:numel(logicFolders)
                if isfolder(logicFolders{i})
                    addpath(logicFolders{i});
                end
            end
        end
    end
end
