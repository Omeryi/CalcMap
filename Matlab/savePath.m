function savePath(mapFolder,path)

points = struct([]);

for i=1:size(path,1)

points(i).X = path(i,1);
points(i).Y = path(i,2);

end

out.Points = points;

json = jsonencode(out,"PrettyPrint",true);

folder = fullfile(mapFolder,"paths");

if ~exist(folder,"dir")
mkdir(folder)
end

file = fullfile(folder,"path.json");

fid = fopen(file,"w");
fprintf(fid,"%s",json);
fclose(fid);

disp("Path saved")

end