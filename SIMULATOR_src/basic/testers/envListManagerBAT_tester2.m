%script para testar o envListManagerBAT
clear all;

mi = (pi*4e-7);
M = 5e-7;
w = 1e6;
R = [1.5 1.5 1.5]';%resist�ncia dos RLCs
maxPower = 50;
tTime = 6000;%segundos de simula��o (em tempo virtual)

coilPrototype = coil([0;1],[0;1],[0;1],1,mi);%dummie coil

%dummie group
groupPrototype.coils.obj = coilPrototype;
groupPrototype.R = -1;
groupPrototype.C = inf;

envPrototype = Environment(...
    [groupPrototype;groupPrototype;groupPrototype],...
    w,mi);%dummie environment
envPrototype.M = M*[0 1 0.2;1 0 0.5;0.2 0.5 0]/mi; %indut�ncia m�tua de 50uH (sem a permissividade magn�tica)

envList = [envPrototype envPrototype];

%bateria
fase1Limit = 0.7;          % (70%)
limitToBegin = 0.93;       % (93%)
constantCurrent_min = 0.5; % (A)
constantCurrent_max = 3.4;   % (A)
constantVoltage = 4.2;     % (V)

Rc = -1;      % (ohm. -1=calcular automaticamente)
Rd = -1;       % (ohm. -1=calcular automaticamente)
Rmax = 1e7;   % (ohm)
Q0 = 0;       % (As)
Qmax = 4320;  % (As), que equivale a 1200 mAh

bat = linearBattery('test_data.txt',Rc,Rd,Q0,Qmax,Rmax,fase1Limit,...
              constantCurrent_min,constantCurrent_max,constantVoltage,...
              limitToBegin,false);

power_m = 0.5; % (W)
power_sd = 0.001;
minV = 2.3;     % (V)
minVTO = 3.3;   % (V)
err = 0.05;     % (5%)
efficiency = 0.95; % (95% de efici�ncia de convers�o AC/DC)

dev = genericDeviceWithBattery(bat,power_m,power_sd,minV,minVTO,err,efficiency);
deviceList = [struct('obj',dev), struct('obj',dev)];

ifactor=1.5;
dfactor=2;
iVel=0.01;
err = 0.005;

step=0.2;     % (s)

%managers
elManager = envListManager(envList,0,w,R,tTime,err,...
              Rmax,ifactor,dfactor,iVel,maxPower);
manager = envListManagerBAT(elManager,deviceList,step,true);


Vt = 5;
manager = setVt(manager, Vt, 0.01);

[~,~,~,~,manager] = getSystemState(manager,tTime);

for i=1:length(manager.DEVICE_DATA)
	LOG = endDataAquisition(manager.DEVICE_DATA(i));
	plotBatteryChart(LOG);
	%plotBatteryChart2010(LOG);
end
