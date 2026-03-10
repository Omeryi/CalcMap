function displayMap(ax,map,xmin,xmax,ymin,ymax)

axes(ax)

cla(ax)  % clear previous plots

imagesc(ax,[xmin xmax],[ymin ymax],map)

axis(ax,"xy")
axis(ax,"equal")

colormap(ax,"hot")  % good for threat heatmaps

cb = colorbar(ax);
cb.Label.String = "Threat Intensity";

title(ax,"Map")

end