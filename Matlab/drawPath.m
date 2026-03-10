function [x,y] = drawPath(ax)

title(ax,"Click points. Press ENTER when finished")

[x,y] = ginput;

hold(ax,"on")
plot(ax,x,y,'r-o','LineWidth',2)

end