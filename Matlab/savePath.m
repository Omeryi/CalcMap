function file = savePath(mapFolder, path)

if nargin < 2 || isempty(path)
    error("savePath:MissingPath", "Path must contain at least one point.");
end

if nargin < 1 || strlength(string(mapFolder)) == 0
    error("savePath:MissingFolder", "Map folder is required.");
end

mapFolder = char(string(mapFolder));
if ~isfolder(mapFolder)
    error("savePath:InvalidFolder", "Map folder does not exist: %s", mapFolder);
end

points = struct("X", num2cell(path(:,1)), "Y", num2cell(path(:,2)));
out = struct("Points", points);
json = jsonencode(out, "PrettyPrint", true);

files = dir(fullfile(mapFolder, "path*.json"));
maxIdx = 0;
for i = 1:numel(files)
    token = regexp(files(i).name, "^path(\d+)\.json$", "tokens", "once");
    if isempty(token)
        continue
    end

    idx = str2double(token{1});
    if ~isnan(idx)
        maxIdx = max(maxIdx, idx);
    end
end

file = fullfile(mapFolder, sprintf("path%d.json", maxIdx + 1));

fid = fopen(file, "w");
if fid < 0
    error("savePath:OpenFailed", "Failed to open file for writing: %s", file);
end

cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, "%s", json);

disp("Path saved to " + string(file))

end
