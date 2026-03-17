function result = runAnalysis(repoRoot, mapState, pathPoints, currentPathFile)

exe = fullfile(repoRoot, "RunAnalyzer", "bin", "x64", "Release", "RunAnalyzer.exe");
if ~isfile(exe)
    error("runAnalysis:MissingExecutable", "RunAnalyzer.exe was not found: %s", exe);
end

pathFile = string(currentPathFile);
if strlength(pathFile) == 0 || ~isfile(char(pathFile))
    pathFile = string(savePath(mapState.Folder, pathPoints));
end

command = sprintf('"%s" "%s" "%s"', exe, char(mapState.JsonFile), char(pathFile));
[status, output] = system(command);
if status ~= 0
    error("runAnalysis:Failed", "%s", strtrim(output));
end

token = regexp(output, 'RESULT_FILE=(.+)', "tokens", "once");
if isempty(token)
    error("runAnalysis:MissingResultFile", "RunAnalyzer did not report an output file.");
end

resultFile = strtrim(token{1});
if ~isfile(resultFile)
    error("runAnalysis:MissingResultJson", "Analysis result file was not found: %s", resultFile);
end

result = struct( ...
    "Output", jsondecode(fileread(resultFile)), ...
    "ResultFile", string(resultFile), ...
    "PathFile", string(pathFile));

end
