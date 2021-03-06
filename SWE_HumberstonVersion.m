%% ********** SHALLOW WATER EQUATION (SWE) MODEL ********** %%
             %% Josh Humberston     -     2018 %%

% This is a simple application of the SWE as a numerical model.
% The model uses an Arakawa C grid
% (https://en.wikipedia.org/wiki/Arakawa_grids) and a leap-frog scheme to
% discretize and incrementally solve the SWE for future time steps
% over the domain. The size, resolutions and and depth profile of the
% domain can be altered by the user in the "INPUT" sections. The user can
% also modify the wave component and several other options here.


%% ********** ---------- INPUT ---------- ********** %%
% Domain parameters:
Lm    = 1e3;    % in m, horizontal size in space of simulation. The domain is currently always an equal sided square.
dx    = 1e1; % horizontal resolution. It should be the same in x (dx) and y (dy)
dy    = dx;

% There is the option to have a uniformally varrying bottom depth.
shallowH=5; % Depth on the allow side
deepH=100;   % Depth on the deep side
shallowside='E'; % The side that will be shallow (options should be strings and can be 'N','E','S' or 'W'
                 % For a flat bottom, simply make two depths the same.

% Boundaries:
SpongZoneWidth = 15; % The number of cells over which to apply the sponge zone
Nsp = 0;Ssp=0;Esp=1;Wsp=0;
cycleNS=1;cycleEW=0; % Cycles boundaries, meaning a wave propegating off one will enter the other. 1 will apply, 0 will remove.

% Initial Condition
StartWithBump = 0; % if 1, starts with a bump on the surface. pick 1 of the 3 options below and comment out others.
%     IDtype = 'SingleSide';
    IDtype = 'SingleMiddle';
%     IDtype = 'DoubleSplit';

% Add waves
addwave=1; % if 1, adds waves specified below, otherwise adds no waves.
% designated: amplitude, wavelength, period, random noise to add 
%(to periods for a pseudo broader spectra [but again not really]), and if
% you want an offset across the border (angled wave)
a1=3;WL1=50;T1=10; randnoise1 = .5*rand(1)-.25; waveoffset1=-3*pi;
a2=1;WL2=20;T2=3;  randnoise2 = .5*rand(1)-.25; waveoffset2=2*pi;

% Wind (not really, but implemented as a constant additional acceleration
% over the domain.
addwind = 0; % if 1, adds winds; if 0, it does not.
WindSpeed = .01; % how much wind effect to add (per time step [dt] - ie: 1 would add 1m/dt)
                  % dt is determined based on the resolution and depth to
                  % try to create a stable simulation (NOTE, because this
                  % is not done right, keeping it very small is a best)

% Other Parameters:
GridScheme = 'C'; % The arakawa grid scheme used for solving. 'A','B' and 'C'
%                   are available with 'C' recommended as others have not
%                   been verrified to work properly yet
tmax  = 30;    % in seconds, duration of simulation
sedtransbeta = 0; % Playing with adding sediment transport, but not at all done yet. 
%                   Setting to 1 will include beta, whereever it is, but is likely to crash model

% Constants 
grav  = 9.81;   % m/ s2 The gravitational acceleration
fc    = 1e-4;   % 1/s % Coriolis parameter

%% Permanent parameters
imt = round(Lm/dx);
waveoffset1=linspace(0,waveoffset1,imt);
waveoffset2=linspace(0,waveoffset2,imt);
Hm = depthmatrix(shallowH,deepH,shallowside,imt);
dt    = (dx /sqrt(grav*nanmax(Hm(:)))) * 0.1;  % change in time.
gamma = 0.1; % This is used in the Robert Asselin filter which does a sort of smoothing to reduce
% the chance that bits of noise explode into full blow crashes. It can be
% varried, but 0.1 is a good starting point.

%%

if sqrt(grav*Hm) * dt / dx <= 1/sqrt(8)
    disp('Nice, your parameters should not cause the leapfrog scheme to explode')
else
    disp('Well...I''m sorry. It''s not looking good for your model...')
    endnow = input('Enter ''q'' to quit, or ''c'' to continue anyways','s');
    if strcmp(endnow,'q')
        return
    end
end

%%
% Plot initial condition to make sure it is as desired...
umat0 = zeros(imt,imt);umatp = umat0; umatn = umat0;
vmat0 = zeros(imt,imt);vmatp = vmat0; vmatn = vmat0;
hmat0 = zeros(imt,imt);hmatp = hmat0; hmatn = hmat0;
if StartWithBump == 1
    hmat0 = initial_conditions(umat0,vmat0,hmat0,imt,IDtype);
end

% add some random noise because its no fun to have a perfectly flat surface. should give user a choice not to do this.
hmat0=hmat0+rand(imt,imt)/3;
ag = AllGrid(imt);

if addwind
    vmat0 = addUwind(vmat0,WindSpeed,imt);
end

disp('Index       Volume              PE                KE               Tot E')
returnstats(-2,umat0,vmat0,hmat0,dx,dy,Hm)

[umat0,vmat0,hmat0,umatm,vmatm,hmatm] = euler2D(GridScheme,umat0,vmat0,hmat0,umatp,vmatp,hmatp,imt,dt,grav,dx,dy,fc,Hm);

if addwind
    vmat0 = addUwind(vmat0,WindSpeed,imt);
end

returnstats(-1,umat0,vmat0,hmat0,dx,dy,Hm)

Ndt = 50000;
subN = 50;
subNInd = 1;
Vvec  = zeros(round(ceil(Ndt/subN)));
PEvec = zeros(round(ceil(Ndt/subN)));
KEvec = zeros(round(ceil(Ndt/subN)));
TEvec = zeros(round(ceil(Ndt/subN)));
tvec  = zeros(round(ceil(Ndt/subN)));
firstcheck=1;tid=0;
figure(1);clf
angnot=50;

%% Cycle through time steps
for t = 0:dt:tmax
    tid=tid+1;
    
    if addwave==1
        N1 = a1 *  cos((2*pi/WL1*dx) - (2*pi/(T1+randnoise1))*t + waveoffset1);
        N2 = a2 *  cos((2*pi/WL2*dx) - (2*pi/(T2+randnoise2))*t + waveoffset2);
        hmat0(1:end,1:2) = hmat0(1:end,1:2)+N1'+N2';
    end
    
    % Leapfrog scheme increment time:
    [vmatp,umatp,hmatp] = leapfrog2d(GridScheme,vmatm,umatm,hmatm,vmat0,umat0,hmat0,imt,dt,grav,dx,dy,fc,Hm);
    
    % Apply sponge zone (if desired)
    if sum([Nsp,Esp,Ssp,Wsp])
        [hmatp,umatp,vmatp] =  spongezone(SpongZoneWidth,hmatp,umatp,vmatp,Nsp,Esp,Ssp,Wsp,0);
    end
    
    
    % Apply cyclic boundary (if desired)
    [hmatp,umatp,vmatp] = cyclebound(hmatp,umatp,vmatp,cycleNS,cycleEW);
    [umat0,vmat0,hmat0] = robertasselinfilt(gamma,umatp,umat0,umatm,vmatp,vmat0,vmatm,hmatp,hmat0,hmatm);
    
    velbot =(2.*pi./T1) ./ sin((2.*pi/WL1).*Hm) .* hmatp/10;
    ubot = velbot .* (umatp ./ sqrt(umatp.^2+vmatp.^2));ubot(isnan(ubot))=0;
    vbot = velbot .* (vmatp ./ sqrt(umatp.^2+vmatp.^2));vbot(isnan(vbot))=0;
    toter=(sqrt(ubot.^2+vbot.^2));toter(isnan(toter))=0;
    
    % yeah... a little cheating, but let's just keep things stable when we
    % can.
    ubotp=ubot;ubotp(ubotp<0)=0;
    ubotm=ubot;ubotm(ubotm>0)=0;
    vbotp=vbot;vbotp(vbotp<0)=0;
    vbotm=vbot;vbotm(vbotm>0)=0;
    
    % Sediment Transport
    % In development... currently TOTALLY made up, unrealistic, and likely
    % to crash.
    if sedtransbeta 
    divby=500;
    toadd=toter(ag.i0,ag.j0) .* (abs(ubotp(ag.i0,ag.j0))./toter(ag.i0,ag.j0))./divby;toadd(isnan(toadd))=0; %if nanmax(abs(toadd(:)))>1,pause;end
    Hm(ag.i0,ag.jm) = Hm(ag.i0,ag.jm) + toadd;nanmax(abs(toadd(:)))
    
    toadd=toter(ag.i0,ag.j0)*(abs(vbotp(ag.i0,ag.j0))./toter(ag.i0,ag.j0))./divby;toadd(isnan(toadd))=0;% if nanmax(abs(toadd(:)))>1,pause;end
    Hm(ag.ip,ag.j0) = Hm(ag.ip,ag.j0) + toadd;nanmax(abs(toadd(:)))
    
    toadd=toter(ag.i0,ag.j0)*(abs(ubotm(ag.i0,ag.j0))./toter(ag.i0,ag.j0))./divby;toadd(isnan(toadd))=0;%if nanmax(abs(toadd(:)))>1,pause;end
    Hm(ag.i0,ag.jm) = Hm(ag.i0,ag.jm) + toadd;nanmax(abs(toadd(:)))
    
    toadd=toter(ag.i0,ag.j0)*(abs(vbotm(ag.i0,ag.j0))./toter(ag.i0,ag.j0))./divby;toadd(isnan(toadd))=0; %if nanmax(abs(toadd(:)))>1,pause;end
    Hm(ag.im,ag.j0) = Hm(ag.im,ag.j0) + toadd;nanmax(abs(toadd(:)))
    
    end
    
    % Increment time step in matricies
    umatm = umat0;
    umat0 = umatp;
    vmatm = vmat0;
    vmat0 = vmatp;
    hmatm = hmat0;
    hmat0 = hmatp;
    
    if addwind
        vmat0 = addUwind(vmat0,WindSpeed,imt);
    end
    
    % Can be used to monitor stats of domain, but not using right now
    %     if t % subN == 0:
    %         [Vtest,PEtest,KEtest,TEtest]=returnstats(t,umatp,vmatp,hmatp,dx,dy,Hm);
    %         Vvec(subNInd) = Vtest;
    %         PEvec(subNInd)= PEtest;
    %         KEvec(subNInd)= KEtest;
    %         TEvec(subNInd)= TEtest;
    %         %                 disp('{:4.0f}'.format(t),'    ','{:2.5e}'.format(Vvec[subNInd]),'     ','{:2.5e}'.format(PEvec[subNInd]),\
    %         %                       '     ','{:2.5e}'.format(KEvec[subNInd]),'     ','{:2.5e}'.format(TEvec[subNInd]))
    %         tvec(subNInd) = t*dt;
    %         subNInd=subNInd+1;
    %     end
    %
    if rem(tid,2) == 0 % only plot every other time step
        F = figure(1);
        hs=surf(0:dx:Lm-dx,0:dy:Lm-dy,hmatm,'FaceLighting','gouraud','FaceColor','interp',...
            'AmbientStrength',0.9);material metal;shading interp;
                    clim([-abs(nanmax(hmatm(:))) nanmax(hmatm(:))])

        if firstcheck==1
            hold on
            colorbar;
            xlabel(['X-dim, dx=' num2str(dx) ' (m)'])
            ylabel(['Y-dim, dy=' num2str(dy) ' (m)'])
%             clim([-abs(nanmax(hmatm(:))) nanmax(hmatm(:))])
            %             cmocean('ice') % not everyone neccesarily has
            pbaspect([1 1 .25])
            colormap winter
            light('Position',[Lm/2 Lm/2 100],'Style','infinite')
            light('Position',[.6*Lm .6*Lm 30],'Style','infinite')
            light('Position',[0.8*Lm .8*Lm 30],'Style','infinite')
            light('Position',[0.2*Lm 0.2*Lm 30],'Style','infinite')
            firstcheck=0;
            skipN=10;
            [xx,yy] = meshgrid(0:dx:Lm-dx,0:dy:Lm-dy);
        end
        hm=mesh(0:dx:Lm-dx,0:dy:Lm-dy,-Hm);
        zlim([nanmin(-Hm(:))/1 nanmax(hmatm(:))])
        angnot=angnot+.05;
        view(angnot,30)
        thours = dt*t/60/60;
        tdays = dt*t/60/60/24;
        title(['time: ' num2str(t) 's'])
        xlim([0 Lm-dx]);ylim([0 Lm-dx])
        set(gca,'fontsize',16);
        drawnow
        delete(hs);
        delete(hm)
    end
    
end


% Plot final h matix from simulation with colormap saturated
% imat= hmatm;
% meshc(imat);
% cbar = colorbar;

% Plot Total energy, kinetic energy, potential energy, and total volume
tvecnew = tvec/60/60/24;
%     figure(2)
%     hall = plot(tvecnew,Vvec, 'r--'); %,label='Volume'
%     hall = plot(tvecnew, PEvec, 'bs');
%     hall = plot(tvecnew, KEvec, 'g^');%,label='Potential Energy'
%     hall = plot(tvecnew,TEvec,'k.');%label='Total Energy'
%     xlabel('time (days)')
%     drawnow
% end

%% FUNCTIONS %%%
function [ag] = AllGrid(imt)
%%%Create slices attributes for a C-grid%%%
m = 1:imt-2;
o = 2:imt-1;
p = 3:imt;
ag.i0=o;ag.j0=o;
ag.ip=p;ag.jp=p;
ag.im=m;ag.jm=m;
end

function [] =  hofm(umat, ptit)
%%%Plot the numerical results in space (not using right now)
mesh(umat);clim([-1 1])
colorbar
xlabel('X-dim, dx=%0.0f')
ylabel('Y-dim, dy=%0.0f')
title(ptit)
drawnow
end

function [Hmat] = depthmatrix(shallowH,deepH,shallowside,imt)
%Create a matrix representing depth that can slant from a shallow side to a deep side
Hmat = zeros(imt,imt);
if strcmp(shallowside, 'N')
    for xpos = 1:imt
        Hmat(:,xpos) = linspace (deepH,shallowH,imt);
    end
end
if strcmp(shallowside,'E')
    for ypos = 1:imt
        Hmat(ypos,:) = linspace (deepH,shallowH,imt);
    end
end
if strcmp(shallowside,'S')
    for xpos = 1:imt
        Hmat(:,xpos) = linspace (shallowH,deepH,imt);
    end
end
if strcmp(shallowside, 'W')
    for ypos = 1:imt
        Hmat(ypos,:) = linspace (shallowH,deepH,imt);
    end
end
end

function [result] = makeGaussian(size,imt, varargin)
% Make a square gaussian kernel.
%size is the length of a side of the square
%fwhm is full-width-half-maximum, which
%can be thought of as an effective radius.
if nargin == 3
    fwhm =  varargin{1};center=NaN;
elseif nargin == 4
    fwhm=varargin{1};center=varargin{2};
else
    fwhm = 3;center=NaN;
end

x = 0: size;
y = x';
if isnan(center)
    x0 = size/ 2;y0=x0;
else
    x0 = center(1);
    y0 = center(2);
end
result=  exp(-4*log(2) * ((x-x0).^2 + (y-y0).^2) / fwhm.^2);
% keyboard
end

function [hmat0] = initial_conditions(umat0,vmat0,hmat0,imt,IDtype)
%Sets the initial conditions of the area to be modeled

%% This should be included as a seperate function... but for now comment out to choose type of Initial Disturbance

if strcmp(IDtype,'SingleSide')
    % Set side disturbance
    pos1 = round(imt/2)-round(imt/10);
    pos2 = round(imt/2)+round(imt/10);
    Gsize = (pos2-pos1);
    icmat = 10*makeGaussian(Gsize,round(Gsize/3));
    hmat0(pos1:pos2,imt-round(Gsize/2):imt) = 50*icmat(:,1:round((Gsize+1)/2));
elseif strcmp(IDtype,'SingleMiddle')
    % Set center disturbance
    pos1 = round(imt/2) - round(imt/15);
    pos2 = round(imt/2) + round(imt/15);
    Gsize = pos2-pos1;
    hmat0(pos1:pos2,pos1:pos2) = 1000*makeGaussian(Gsize,Gsize/3)/5;
elseif strcmp(IDtype,'DoubleSplit')
    % Set first disturbance
    pos1 = round(imt/2) - round(imt/15);
    pos2 = round(imt/2) + round(imt/15);
    Gsize = pos2-pos1;
    hmat0(pos1:pos2,pos1:pos2) = 10*makeGaussian(Gsize,Gsize/3);
    % Set a secibd disturbance
    pos1 = round(imt) - round(imt/10);
    pos2 = round(imt) - round(imt/20);
    Gsize = pos2-pos1;
    hmat0(pos1:pos2,pos1:pos2) = 10*makeGaussian(Gsize,Gsize/3);
end
end



function [umatp,vmatp,hmatp,umat0,vmat0,hmat0] = euler2D(GridScheme,umat0,vmat0,hmat0,umatp,vmatp,hmatp,imt,dt,grav,dx,dy,fc,Hm)

%Calculate the spatial diference using a 2-D forward euler scheme
ag = AllGrid(imt);
if GridScheme == 'A'
    disp('Using the A-grid scheme')
    umatp(ag.i0,ag.j0) = umat0(ag.i0,ag.j0) + ( dt * (-grav * (hmat0(ag.ip,ag.j0) - hmat0(ag.im,ag.j0)) / (2*dx) + fc*vmat0(ag.i0,ag.j0)   ));
    vmatp(ag.i0,ag.j0) = vmat0(ag.i0,ag.j0) + ( dt * (-grav * (hmat0(ag.i0,ag.jp) - hmat0(ag.i0,ag.jm)) / (2*dy) - fc*umat0(ag.i0,ag.j0)   ));
    hmatp(ag.i0,ag.j0) = hmat0(ag.i0,ag.j0) + ( dt *  -Hm(ag.i0,ag.j0)   * (( (umat0(ag.ip,ag.j0) - umat0(ag.im,ag.j0))/(2 * dx) ) +...
        ( (umat0(ag.i0,ag.jp) - umat0(ag.i0,ag.jm))/(2 * dy) )));
    
elseif GridScheme == 'B'
    disp('Using the B-grid scheme')
    umatp(ag.i0,ag.j0) = umat0(ag.i0,ag.j0) + ( dt * (   ( -grav * (hmat0(ag.ip,ag.j0) + hmat0(ag.ip,ag.jp) - hmat0(ag.i0,ag.j0) - hmat0(ag.i0,ag.jp))...
        / (2*dx))+ fc*vmat0(ag.i0,ag.j0)));
    vmatp(ag.i0,ag.j0) = vmat0(ag.i0,ag.j0) + ( dt * (   ( -grav * (hmat0(ag.i0,ag.jp) + hmat0(ag.ip,ag.jp) - hmat0(ag.i0,ag.j0) - hmat0(ag.ip,ag.j0))...
        / (2*dy))- fc*umat0(ag.i0,ag.j0)));
    hmatp(ag.i0,ag.j0) = hmat0(ag.i0,ag.j0) + (dt * -Hm(ag.i0,ag.j0) * ( ((umat0(ag.i0,ag.j0) +...
        umat0(ag.i0,ag.jm) - umat0(ag.im,ag.j0) - umat0(ag.im,ag.jm))/(2 * dx))+...
        ((vmat0(ag.i0,ag.j0) + vmat0(ag.im,ag.j0) - vmat0(ag.i0,ag.jm) - vmat0(ag.im,ag.jm))/(2 * dy))));
    
elseif GridScheme == 'C'
    disp('Using the C-grid scheme')
    umatp(ag.i0,ag.j0) = umat0(ag.i0,ag.j0) + ( dt * (   ( -grav * (hmat0(ag.ip,ag.j0) - hmat0(ag.i0,ag.j0)) / dx)...
        + ((fc/4) * (vmat0(ag.i0,ag.j0) + vmat0(ag.ip,ag.j0) + vmat0(ag.ip,ag.jm) + vmat0(ag.i0,ag.jm)))   ));
    vmatp(ag.i0,ag.j0) = vmat0(ag.i0,ag.j0) + ( dt * (   ( -grav * (hmat0(ag.i0,ag.jp) - hmat0(ag.i0,ag.j0)) / dy)...
        - ((fc/4) * (umat0(ag.i0,ag.j0) + umat0(ag.i0,ag.jp) +umat0(ag.im,ag.jp) + umat0(ag.im,ag.j0)))   )) ;
    hmatp(ag.i0,ag.j0) = hmat0(ag.i0,ag.j0) - (dt * Hm(ag.i0,ag.j0) *...
        (((umat0(ag.i0,ag.j0) - umat0(ag.im,ag.j0))/dx) + ((vmat0(ag.i0,ag.j0) - vmat0(ag.i0,ag.jm))/dy)));
end
end

function [umatp,vmatp,hmatp] = leapfrog2d(GridScheme,umatm,vmatm,hmatm,umat0,vmat0,hmat0,imt,dt,grav,dx,dy,fc,Hm)
%Calculate the spatial difference using a 2-D leapfrog scheme
umatp = zeros(imt,imt);
vmatp = zeros(imt,imt);
hmatp = zeros(imt,imt);
ag = AllGrid(imt);
if GridScheme == 'A'
    umatp(ag.i0,ag.j0) = umatm(ag.i0,ag.j0) + (2*dt * (( -grav * (hmat0(ag.ip,ag.j0) - hmat0(ag.im,ag.j0)) / (2*dx)) + fc*vmat0(ag.i0,ag.j0)));
    vmatp(ag.i0,ag.j0) = vmatm(ag.i0,ag.j0) + (2*dt * (( -grav * (hmat0(ag.i0,ag.jp) - hmat0(ag.i0,ag.jm)) / (2*dy)) - fc*umat0(ag.i0,ag.j0)));
    hmatp(ag.i0,ag.j0) = hmatm(ag.i0,ag.j0) + (2*dt *  -Hm(ag.i0,ag.j0) *...
        (  ((umat0(ag.ip,ag.j0) - umat0(ag.im,ag.j0))/(2*dx))   +((vmat0(ag.i0,ag.jp) - vmat0(ag.i0,ag.jm))/(2*dy)))   );
elseif GridScheme == 'B'
    umatp(ag.i0,ag.j0) = umatm(ag.i0,ag.j0) + (2*dt * (   ( -grav * (hmat0(ag.ip,ag.j0) + hmat0(ag.ip,ag.jp) - hmat0(ag.i0,ag.j0) - hmat0(ag.i0,ag.jp))...
        / (2*dx))+ fc*vmat0(ag.i0,ag.j0)));
    vmatp(ag.i0,ag.j0) = vmatm(ag.i0,ag.j0) + (2*dt * (   ( -grav * (hmat0(ag.i0,ag.jp) + hmat0(ag.ip,ag.jp) - hmat0(ag.i0,ag.j0) - hmat0(ag.ip,ag.j0))...
        / (2*dy))- fc*umat0(ag.i0,ag.j0)));
    hmatp(ag.i0,ag.j0) = hmatm(ag.i0,ag.j0) + (2*dt * -Hm(ag.i0,ag.j0) * ( ((umat0(ag.i0,ag.j0) + umat0(ag.i0,ag.jm) - umat0(ag.im,ag.j0) - umat0(ag.im,ag.jm))/(2 * dx))+...
        ((vmat0(ag.i0,ag.j0) + vmat0(ag.im,ag.j0) - vmat0(ag.i0,ag.jm) - vmat0(ag.im,ag.jm))/(2 * dy))));
    
elseif GridScheme == 'C'
    umatp(ag.i0,ag.j0) = umatm(ag.i0,ag.j0) + (2*dt * (  (-grav * (hmat0(ag.ip,ag.j0) - hmat0(ag.i0,ag.j0))/dx)...
        + ((fc/4)*(vmat0(ag.i0,ag.j0) + vmat0(ag.ip,ag.j0) + vmat0(ag.ip,ag.jm) + vmat0(ag.i0,ag.jm)))  ));
    
    vmatp(ag.i0,ag.j0) = vmatm(ag.i0,ag.j0) + (2*dt * (  (-grav * (hmat0(ag.i0,ag.jp) - hmat0(ag.i0,ag.j0))/dy)...
        - ((fc/4)*(umat0(ag.i0,ag.j0) + umat0(ag.i0,ag.jp) + umat0(ag.im,ag.jp) + umat0(ag.im,ag.j0)))  ));
    
    hmatp(ag.i0,ag.j0) = hmatm(ag.i0,ag.j0) + (2.*dt .* -Hm(ag.i0,ag.j0) .*...
        (((umat0(ag.i0,ag.j0) - umat0(ag.im,ag.j0))/dx) + (vmat0(ag.i0,ag.j0) - vmat0(ag.i0,ag.jm))/dy));
end
end

function [umat0f,vmat0f,hmat0f] = robertasselinfilt(gamma,umatp,umat0,umatm,vmatp,vmat0,vmatm,hmatp,hmat0,hmatm)
%%%Compute a filtered value using a Robert Asselin Filter to avoid the numberical mode effects%%%
umat0f = umat0 + gamma * (umatm - 2*umat0 + umatp);
vmat0f = vmat0 + gamma * (vmatm - 2*vmat0 + vmatp);
hmat0f = hmat0 + gamma * (hmatm - 2*hmat0 + hmatp);
end

function [Vtot,PE,KE,TE] = returnstats(tpos,umat,vmat,hmat,dx,dy,Hm)
%%%Calculate the Volume, Potential Energy, Kinetic Energy, and Total Energy in the simulation area and return values%%%
grav=9.8;
Vtot  = sum(nansum(hmat)) * dx *dy;
PE    = (grav/2) * sum(nansum((hmat)^2)) * dx *dy;
KE    = sum((Hm(:)/2) .* (umat(:)).^2 + (vmat(:)).^2) * dx *dy;
TE    = PE + KE;
end

function [hmat,umat,vmat] = spongezone(SpSize,hmat,umat,vmat,Nc,Ec,Sc,Wc,extval)
%%%Apply a sponge border at designated sides%%%
if sum([Nc,Ec,Sc,Wc]) > 0
    relaxfact = 0.5 * ( 1+cos ( pi* ( linspace ( 0,SpSize-1,SpSize) / SpSize) ) );
    if Nc == 1
        relaxfactN = relaxfact;
        hmat(1:SpSize,:) = (1-relaxfactN') .* hmat(1:SpSize,:) + relaxfactN' .* extval .* (hmat(1:SpSize,:).*0+1);
        umat(1:SpSize,:) = (1-relaxfactN') .* umat(1:SpSize,:) + relaxfactN' .* extval .* (umat(1:SpSize,:).*0+1);
        vmat(1:SpSize,:) = (1-relaxfactN') .* vmat(1:SpSize,:) + relaxfactN' .* extval .* (vmat(1:SpSize,:).*0+1);
        
    end
    if Sc == 1
        relaxfactS = relaxfact;
        hmat(end-SpSize+1:end,:) = (relaxfactS') .* hmat(end-SpSize+1:end,:) + relaxfactS' .* extval .* ((hmat(end-SpSize+1:end,:).*0)+1);
        umat(end-SpSize+1:end,:) = (relaxfactS') .* umat(end-SpSize+1:end,:) + relaxfactS' .* extval .* ((umat(end-SpSize+1:end,:).*0)+1);
        vmat(end-SpSize+1:end,:) = (relaxfactS') .* vmat(end-SpSize+1:end,:) + relaxfactS' .* extval .* ((vmat(end-SpSize+1:end,:).*0)+1);
        
    end
    if Ec == 1
        relaxfactE = flipud(relaxfact);
        hmat(:,end-SpSize+1:end) = (relaxfactE) .* hmat(:,end-SpSize+1:end) + relaxfactE .* extval .* (hmat(:,end-SpSize+1:end).*0+1);
        umat(:,end-SpSize+1:end) = (relaxfactE) .* umat(:,end-SpSize+1:end) + relaxfactE .* extval .* (umat(:,end-SpSize+1:end).*0+1);
        vmat(:,end-SpSize+1:end) = (relaxfactE) .* vmat(:,end-SpSize+1:end) + relaxfactE .* extval .* (vmat(:,end-SpSize+1:end).*0+1);
        
    end
    if Wc == 1
        relaxfactW = relaxfact;
        hmat(:,1:SpSize) = (1-relaxfactW) .* hmat(:,1:SpSize) + relaxfactW .* extval .* (hmat(:,1:SpSize).*0+1);
        umat(:,1:SpSize) = (1-relaxfactW) .* umat(:,1:SpSize) + relaxfactW .* extval .* (umat(:,1:SpSize).*0+1);
        vmat(:,1:SpSize) = (1-relaxfactW) .* vmat(:,1:SpSize) + relaxfactW .* extval .* (vmat(:,1:SpSize).*0+1);
        
    end
end
end

function [hmat,umat,vmat] = cyclebound(hmat,umat,vmat,cycleNS,cycleEW)
%%%Apply a cyclic boundary condition%%%
if cycleNS == 1
    hmat(1,:) = hmat(1,:)+hmat(end-1,:);    umat(1,:) = umat(1,:)+umat(end-1,:);    vmat(1,:) = vmat(1,:)+vmat(end-1,:);
    hmat(end,:) = hmat(end,:)+hmat(2,:);  umat(end,:) = umat(end,:)+umat(2,:);   vmat(end,:) = vmat(end,:)+vmat(2,:);
end
if cycleEW == 1
    hmat(:,1) = hmat(:,1)+hmat(:,end-1);    umat(:,1) = umat(:,1)+hmat(:,end-1);    vmat(:,1) = vmat(:,1)+vmat(:,end-1);
    hmat(:,end) = hmat(:,end)+hmat(:,2);   umat(:,end) = umat(:,end)+umat(:,2); vmat(:,end) = vmat(:,end)+vmat(:,2);
end
end


function [vmat] = addUwind(vmat,windspeed,imt)
%%%Aplly a wind stress by adding constant vertical y-oriented velocity over area%%%
% MAKE MORE ROBUST
afxarea = 15:100;
afyarea=15:imt-15;
vmat(afyarea,afxarea) = vmat(afyarea,afxarea) + windspeed;
end
