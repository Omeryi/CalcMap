function [map,xmin,xmax,ymin,ymax] = readMap(file)

txt = fileread(file);
data = jsondecode(txt);

params = data.Parameters;

xmin = params.XMin;
xmax = params.XMax;
ymin = params.YMin;
ymax = params.YMax;

threats = data.Threats;

res = threats(1).Resolution;

nx = round((xmax-xmin)/res)+1;
ny = round((ymax-ymin)/res)+1;

map = zeros(ny,nx);

for t = 1:length(threats)

    img = threats(t).Image;

    cx = threats(t).CenterX;
    cy = threats(t).CenterY;
    r = threats(t).Radius;

    imgSize = size(img,1);

    xs = cx - r;
    ys = cy - r;

    ix = round((xs-xmin)/res)+1;
    iy = round((ys-ymin)/res)+1;

    for i=1:imgSize
        for j=1:imgSize

            gx = ix+j-1;
            gy = iy+i-1;

            if gx>=1 && gx<=nx && gy>=1 && gy<=ny
                map(gy,gx) = max(map(gy,gx),img(i,j));
            end

        end
    end

end

end