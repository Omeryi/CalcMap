function selectedFile = selectPathFile(mapFolder)

startFolder = char(string(mapFolder));
[file, folder] = uigetfile(fullfile(startFolder, "*.json"), "Select path");
if isequal(file, 0)
    selectedFile = "";
    return
end

selectedFile = string(fullfile(folder, file));

end
