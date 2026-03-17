function p = loadPath(file)

txt = fileread(file);

data = jsondecode(txt);

pts = data.Points;

p = zeros(length(pts),2);

for i=1:length(pts)

p(i,1) = pts(i).X;
p(i,2) = pts(i).Y;

end

end
