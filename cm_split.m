function [cmnew,caxnew] = cm_split(zz,splitV,varargin)
% Josh Humberston (2017)
% Create a colormap where land is shades of green to white and sumberged
% areas are shades of blue and their is an aburpt change between the two at
% a designated water level (splitV) such that it is more easily visually
% distinguishable.
%
% input:
%         zz: matrix of values to wich the colormap will be made.
%               Alternatively, a singe vector can be put in with min and max
%               value (i.e. [-5 20])
%         splitV: A single value denoting the elevation to correspond to 
%               transition from land to water
%         optional 3rd input: if input here is 'update', it will update the
%               colormap and axes on the current plot, otherwise it will only
%               returns arguments (colormap and axes)
% output:
%         cmnew: new colormap that can be applied. (e.g. colormap(cnew))
%         caxnew: new color axis that should be applied for the new
%               colormap to work. (e.g. caxis(caxnew))

% NOTE: new axes are not always perfectly exact to those put in. Matching the
% transition point (splitV) is given priority and the min/max are made to be
% as close as possible to the inputs such that they fit within the 64 shade colormap.
%%
caxnew = [0 0];
Nc = 64; %number off colors (rows) in color map; default is 64.
zmax=nanmax(zz(:));zmin=nanmin(zz(:));
zrange  = nanmax(zz(:))-nanmin(zz(:));
zprange = nanmax(zmax(:)) - splitV;
znrange = splitV-nanmin(zmin(:));

cint = zrange/Nc;
zpfrac = zprange/zrange;zpN = round(zpfrac * Nc);
caxnew(2) = splitV + zpN*cint;
znfrac = znrange/zrange;znN = round(znfrac * Nc);
caxnew(1) = splitV - znN*cint;
%%
b=bluewater(znN);
g=greenland(zpN);
cmnew=[b;g];

if nargin>2 % update automatically if flagged to do so
    if strcmp('update',varargin(1))
        colormap(cmnew);caxis(caxnew)
    end
end

function [c] = bluewater(n)
% Blue (submerged) part of colormap
x=(0:n-1)'/(n-1);
c=((.7-.7*x)*[1 1 0]+max(0,(1-.65*x))*[0 0 1]);
c=c(end:-1:1,:);

function [c] = greenland(n)
% Green (land) part of colormap
x=(0:n-1)'/(n-1);
r=max(0,(-.25+1.8*x));
g=.4*(1+2.5*x);
b=0.5*max(0,(-.25+2.0*x));
i=find(r>1);
r(i)=max( 1.7-1*x(i), b(i));
i=find(g>1);
g(i)=max( 1.5-1*x(i), b(i));
c=r*[1 0 0]+g*[0 1 0]+b*[0 0 1];
c=min(max(0,c),1);



