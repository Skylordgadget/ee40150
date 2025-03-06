clc; clf; close all; clear;

newToolData = readmatrix("..\recordings\New\0022_d12_z_ap1_ae3_vc45_n2_f0.03_vfws2(4)-2.txt", 'CommentStyle', '#');

Mx = newToolData(:,3); My = newToolData(:,4);
Mr =                  

signal_lim = 256;
Fs = 2500; % sampling frequency
T = 1/Fs; % time interval
L = signal_lim; % length of signal
t = (0:L-1)*T; % points in time

figure;
subplot(3,1,1); 
plot(t,Mx(1:signal_lim)); % bending moment in the X direction

subplot(3,1,2);
plot(t,My(1:signal_lim)); % bending moment in the Y direction

subplot(3,1,3);
plot(t,Mr(1:signal_lim)); % resultant bending moment

figure;
Y = fft(Mr(1:signal_lim));

P2 = abs(Y/L);
P1 = P2(1:L/2+1);
P1(2:end-1) = 2*P1(2:end-1);
f = Fs/L*(0:(L/2));

figure;
plot(f,P1)

autoenc = trainAutoencoder(P1',25,...
        'EncoderTransferFunction','satlin',...
        'DecoderTransferFunction','purelin',...
        'L2WeightRegularization',0.01,...
        'SparsityRegularization',4,...
        'SparsityProportion',0.10);

newToolData = readmatrix("..\recordings\New\0022_d12_z_ap1_ae3_vc45_n2_f0.03_vfws2(4)-3.txt", 'CommentStyle', '#');

Mx = newToolData(:,3); My = newToolData(:,4);
Mr = sqrt(Mx.^2 + My.^2);

Y = fft(Mr(1:signal_lim));

P2 = abs(Y/L);
P1 = P2(1:L/2+1);
P1(2:end-1) = 2*P1(2:end-1);
f = Fs/L*(0:(L/2));

yReconstructed = predict(autoenc, P1');

plot(f,P1);
hold on;
plot(f,yReconstructed);
hold off;