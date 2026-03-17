function mapState = generateMap(repoRoot, params)

exe = fullfile(repoRoot, "MapGenerator", "bin", "x64", "Release", "MapGenerator.exe");
if ~isfile(exe)
    error("generateMap:MissingExecutable", "MapGenerator.exe was not found: %s", exe);
end

argText = sprintf("%.15g %.15g %.15g %.15g %d %.15g %.15g", ...
    params.XMin, params.XMax, params.YMin, params.YMax, ...
    params.RegionCount, params.RadiusMin, params.RadiusMax);

command = sprintf('"%s" %s', exe, argText);
[status, output] = system(command);
if status ~= 0
    error("generateMap:Failed", "%s", strtrim(output));
end

mapPath = extractGeneratedMapPath(output, repoRoot);
mapState = loadMap(mapPath);

end

function mapPath = extractGeneratedMapPath(output, repoRoot)

token = regexp(output, 'Map saved to (.+)', "tokens", "once");
if ~isempty(token)
    mapPath = strtrim(token{1});
    if isfile(mapPath)
        return
    end
end

mapsRoot = fullfile(repoRoot, "Maps");
folders = dir(mapsRoot);
folders = folders([folders.isdir]);
folders = folders(~ismember({folders.name}, {".", ".."}));
if isempty(folders)
    error("generateMap:MissingOutput", "No generated maps were found in %s", mapsRoot);
end

[~, index] = max([folders.datenum]);
mapPath = fullfile(mapsRoot, folders(index).name, "map.json");
if ~isfile(mapPath)
    error("generateMap:MissingMapJson", "Generated map.json was not found: %s", mapPath);
end

end
