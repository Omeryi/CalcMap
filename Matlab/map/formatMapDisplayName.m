function mapLabel = formatMapDisplayName(mapState)

mapName = "";
if isstruct(mapState) && isfield(mapState, "Name")
    mapName = string(mapState.Name);
end

mapGuid = getMapGuid(mapState);

if strlength(mapGuid) > 0
    mapLabel = mapGuid;
else
    mapLabel = mapName;
end

end
