function mapGuid = getMapGuid(mapState)

mapGuid = "";
if isempty(mapState) || ~isstruct(mapState)
    return
end

if isfield(mapState, "Guid") && strlength(string(mapState.Guid)) > 0
    mapGuid = string(mapState.Guid);
    return
end

if isfield(mapState, "Folder") && strlength(string(mapState.Folder)) > 0
    [~, folderName] = fileparts(char(string(mapState.Folder)));
    mapGuid = string(folderName);
end

end
