% Josh Humberston 2018
% This script demonstrates the use of the cm_split function for creating a
% colormap designed for topo-bathy data. It also demonstrates some ways to
% create 'nice' looking 3-D plots that are still quantatatively
% informative.
%% Setup:
% Input Parameters (to change)
splitVal = 3;          % where colormap shifts blue to green
elevMax=5;CMmax=8;     % max elevation for example and max you want the colormap to go to 
elevMin=-20;CMmin=-20;  % min elevation for example and min you want the colormap to go to

% Make synthetic island example:
x=1:100;y=x';
somenoise=randi(2,100);
elev = ones(100) .*elevMin + somenoise;
sigma = length(elev)/5;% std (width) of Gauss 
[xx,yy] = meshgrid(1:size(elev,1),1:size(elev,2));
midpt = round(length(elev)/2);
exponent = ((x-midpt).^2 + (y-midpt).^2)./(2*sigma^2);
elev = elev + (elevMax + abs(elevMin)) * exp(-exponent);

%% Pcolor Example

% Plot
figure(1);clf
subplot(1,2,1)
pcolor(xx,yy,elev);shading interp;axis equal;axis tight;hold on
contour(xx,yy,elev,[splitVal splitVal],'k','LineWidth',3)

% Update colormap to cm_split
cm_split([CMmin CMmax],splitVal,'update');

% Labels
set(gca,'fontsize',16)
title({'P-color Plot Example';'using ''cm_split'''}, 'Interpreter', 'none')
xlabel('X-Distance')
ylabel('Y-Distance')
%% FancySurf example

% Plot
f = subplot(1,2,2);
surf(xx,yy,elev,'FaceLighting','gouraud','FaceColor','interp',...
    'AmbientStrength',0.5);shading interp;material dull;hold on
contour(xx,yy,elev,[splitVal splitVal],'k','LineWidth',3)
x1=nanmin(xx(:));x2=nanmax(xx(:));
y1=nanmin(yy(:));y2=nanmax(yy(:));
hwl=surf( [x1 x2], [y1 y2], ones(2,2).*(splitVal-.1),'facealpha',0.4 ,'EdgeColor','none');

% Update colormap to cm_split
cm_split([CMmin CMmax],splitVal,'update');

% Add light positions (just for effect - not neccesary)
light('Position',[midpt midpt elevMax+30],'Style','local')
% light('Position',[midpt+10 midpt+10 elevMax+10],'Style','local')

% Change (x/y/z display ratio (often want z on differnt scale)
pbaspect([1 1 .3]) 

% define view point azimuth and height
viewspec(1)=135;
viewspec(2) = elevMax+30;
view(viewspec(1),viewspec(2))

% Labels
set(gca,'fontsize',16)
title({'Surface Plot Example';'using ''cm_split'''}, 'Interpreter', 'none')
xlabel('X-Distance')
ylabel('Y-Distance')
h=colorbar;
ylabel(h, 'elevation (m)')

%%
% b = uicontrol('Parent',f,'Style','slider','Position',[81,54,419,23],...
%               'value',az, 'min',az-180, 'max',az+180);
% Create slider for contoling max (saturation value)
bgc=[.7 .7 .9];
sld = uicontrol('Style', 'slider','value',viewspec(1), 'min',az-180, 'max',az+180,...
    'Units','normalized','Position', [.6 .02 .2 .025],'Callback', {@ChangeViewAz,viewspec},'BackgroundColor',bgc);
sld1 = uicontrol('Style','text','Units','normalized','Position',[.55 .02 .05 .025],...
    'String','-180','BackgroundColor',bgc);
sld2 = uicontrol('Style','text','Units','normalized','Position',[.8 .02 .05 .025],...
    'String','+180','BackgroundColor',bgc);
sld3 = uicontrol('Style','text','Units','normalized','Position',[.55 .045 .3 .025],...
    'String','View Angle','BackgroundColor',bgc);

function ChangeViewAz(source,event,viewspec)
        val = source.Value;
        view(val,viewspec(2))
end