function selectedFile = selectMapFile(repoRoot)

startFolder = fullfile(repoRoot, "Maps");
[file, folder] = uigetfile(fullfile(startFolder, "*.json"), "Select map");
if isequal(file, 0)
    selectedFile = "";
    return
end

selectedFile = string(fullfile(folder, file));

end
