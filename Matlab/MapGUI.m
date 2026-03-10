function MapGUI()

fig = figure('Name','Map Tool','Position',[200 200 900 650]);

ax = axes(fig,'Position',[0.08 0.18 0.85 0.78]);

data.map = [];
data.mapFolder = "";
data.path = [];

guidata(fig,data);

uicontrol(fig,'Style','pushbutton','String','Load Map',...
    'Position',[40 30 120 40],'Callback',@(src,ev)loadMap(fig,ax));

uicontrol(fig,'Style','pushbutton','String','Generate Map',...
    'Position',[180 30 120 40],'Callback',@(src,ev)generateMap(fig,ax));

uicontrol(fig,'Style','pushbutton','String','Draw Path',...
    'Position',[320 30 120 40],'Callback',@(src,ev)drawPathButton(fig,ax));

uicontrol(fig,'Style','pushbutton','String','Save Path',...
    'Position',[460 30 120 40],'Callback',@(src,ev)savePathButton(fig));

uicontrol(fig,'Style','pushbutton','String','Load Path',...
    'Position',[600 30 120 40],'Callback',@(src,ev)loadPathButton(fig,ax));

end


function loadMap(fig,ax)

[file,path] = uigetfile('maps/**/*.json','Select map');

if file == 0
    return
end

jsonFile = fullfile(path,file);

[map,xmin,xmax,ymin,ymax] = readMap(jsonFile);

displayMap(ax,map,xmin,xmax,ymin,ymax)

data = guidata(fig);
data.map = map;
data.mapFolder = path;
guidata(fig,data)

end


function generateMap(fig,ax)

exe = 'C:\Users\Omi\source\repos\CalcMapSolution\MapGenerator\bin\x64\Release\MapGenerator.exe';
cmd = [exe];
system(cmd);

system(cmd)

maps = dir("Maps");
maps = maps([maps.isdir]);

maps = maps(~ismember({maps.name},{'.','..'}));

[~,idx] = max([maps.datenum]);

folder = fullfile("maps",maps(idx).name);

jsonFile = fullfile(folder,"map.json");

[map,xmin,xmax,ymin,ymax] = readMap(jsonFile);

displayMap(ax,map,xmin,xmax,ymin,ymax)

data = guidata(fig);
data.map = map;
data.mapFolder = folder;
guidata(fig,data)

end


function drawPathButton(fig,ax)

[x,y] = drawPath(ax);

data = guidata(fig);
data.path = [x y];
guidata(fig,data)

end


function savePathButton(fig)

data = guidata(fig);

if isempty(data.path)
    disp("No path to save")
    return
end

savePath(data.mapFolder,data.path)

end


function loadPathButton(fig,ax)

data = guidata(fig);

[file,path] = uigetfile('*.json','Select path');

if file == 0
    return
end

p = loadPath(fullfile(path,file));

hold(ax,"on")
plot(ax,p(:,1),p(:,2),'r-o','LineWidth',2)

data.path = p;
guidata(fig,data)

end