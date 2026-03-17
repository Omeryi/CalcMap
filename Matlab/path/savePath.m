function [file, savedPath] = savePath(mapFolder, path, spacing)

if nargin < 2 || isempty(path)
    error("savePath:MissingPath", "Path must contain at least one point.");
end

if nargin >= 3 && ~isempty(spacing)
    savedPath = resamplePathBySpacing(path, spacing);
else
    savedPath = path;
end

if nargin < 1 || strlength(string(mapFolder)) == 0
    error("savePath:MissingFolder", "Map folder is required.");
end

mapFolder = char(string(mapFolder));
if ~isfolder(mapFolder)
    error("savePath:InvalidFolder", "Map folder does not exist: %s", mapFolder);
end

points = struct("X", num2cell(savedPath(:,1)), "Y", num2cell(savedPath(:,2)));
out = struct("Points", points);
json = jsonencode(out, "PrettyPrint", true);

timestamp = string(datetime("now", "Format", "yyyyMMdd_HHmm"));
baseName = "path_" + timestamp;
file = fullfile(mapFolder, baseName + ".json");
suffix = 2;
while isfile(file)
    file = fullfile(mapFolder, baseName + "_" + string(suffix) + ".json");
    suffix = suffix + 1;
end

fid = fopen(file, "w");
if fid < 0
    error("savePath:OpenFailed", "Failed to open file for writing: %s", file);
end

cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, "%s", json);

disp("Path saved to " + string(file))

end
