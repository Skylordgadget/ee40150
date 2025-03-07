%% Load Files
clc; clf; close all; clear;

percent_train = 0.1; % percentage of data to be used for training
percent_test = 1 - percent_train; % percentage of data to be used for testing
percent_samples = 1; % percent of samples in each file to be used

% set the directory path
new_dir_path = '..\recordings\New\';
worn_dir_path = '..\recordings\Worn\';

% get a list of all the files in the directory
new_files = readdir(new_dir_path,'txt');
worn_files = readdir(worn_dir_path,'txt');

% load the contents of all the files into MATLAB (this takes some time)
new_recordings = loadrecordings(new_files);
worn_recordings = loadrecordings(worn_files); 

% get the resultant bending moment in the x and y direction using the
% Euclidian theorem
new_mr = euclidian(new_recordings);

% TODO trim recordings to remove startup noise
new_mr_train = [];
figure;
for i=1:ceil(length(new_mr)*percent_train) 
    subplot(ceil(length(new_mr)*percent_train),1,i);
    plot(new_mr{i});
    hold on;
    xline(ceil(length(new_mr{i})*percent_samples),'LineWidth',3,'Color',"red");
    hold off;
    new_mr_train = [new_mr_train ; new_mr{i}(1:ceil(length(new_mr{i})*percent_samples))];
end

new_mr_test = [];
for i=ceil(length(new_mr)*percent_train):length(new_mr)
    new_mr_test = [new_mr_test ; new_mr{i}(1:ceil(length(new_mr{i})*percent_samples))];
end

worn_mr = euclidian(worn_recordings);

worn_mr_test = [];
for i=1:ceil(length(worn_mr))
    worn_mr_test = [worn_mr_test ; worn_mr{i}(:)];
end

disp('done loading')
%% Time Series Autoencoder
clf; close(findall(groot, "Type", "figure"));

feature_dimension = 1;

% layers = [ sequenceInputLayer(feature_dimension)
%     fullyConnectedLayer(4)
%     reluLayer
%     fullyConnectedLayer(2)
%     reluLayer
%     fullyConnectedLayer(4)
%     reluLayer
%     fullyConnectedLayer(feature_dimension)];

layers = [ sequenceInputLayer(feature_dimension)
    convolution1dLayer(127,32,Padding="causal")
    reluLayer
    convolution1dLayer(63,8,Padding="causal")
    reluLayer
    convolution1dLayer(15,2,Padding="causal")
    reluLayer
    fullyConnectedLayer(8)
    reluLayer
    fullyConnectedLayer(32)
    reluLayer
    fullyConnectedLayer(feature_dimension)];

options = trainingOptions('adam', ...
    'InitialLearnRate', 0.1, ...
    'Plots', 'training-progress', ...
    'Metrics','rmse', ...
    'MaxEpochs', 100);

net = trainnet(new_mr_train, new_mr_train, layers, "mse", options);
decoded_new = predict(net,new_mr_test);
decoded_worn = predict(net,worn_mr_test);

helperVisualizeModelBehavior(new_mr_test, worn_mr_test, decoded_new, decoded_worn);


%% FFT Autoencoder 
clf; close(findall(groot, "Type", "figure"));

const = 0;

signal_lim = 64;
Fs = 2500; % sampling frequency
T = 1/Fs; % time interval
L = signal_lim; % length of signal
t = (0:L-1)*T; % points in time

new_mr_train_pre_fft = reshape(new_mr_train(1:(length(new_mr_train) - mod(length(new_mr_train), signal_lim))), [signal_lim, floor(length(new_mr_train)/signal_lim)]);
new_mr_train_post_fft = cell(floor(length(new_mr_train)/signal_lim),1);

% avg_spectrum = zeros(1,(signal_lim/2)+1);

for i=1:floor(length(new_mr_train)/signal_lim)
    Y = fft(new_mr_train_pre_fft(:,i));
    P2 = abs(Y/L);
    P1 = P2(1:L/2+1);
    P1(2:end-1) = 2*P1(2:end-1);
    new_mr_train_post_fft{i} = P1 + const;
    % avg_spectrum = avg_spectrum + P1';
end

% avg_spectrum = avg_spectrum ./ floor(length(new_mr_train)/signal_lim);
% 
% figure;
% plot(Fs/L*(0:(L/2)),avg_spectrum);

new_mr_test_pre_fft = reshape(new_mr_test(1:(length(new_mr_test) - mod(length(new_mr_test), signal_lim))), [signal_lim, floor(length(new_mr_test)/signal_lim)]);
new_mr_test_post_fft = cell(floor(length(new_mr_test)/signal_lim),1);

for i=1:floor(length(new_mr_test)/signal_lim)
    Y = fft(new_mr_test_pre_fft(:,i));
    P2 = abs(Y/L);
    P1 = P2(1:L/2+1);
    P1(2:end-1) = 2*P1(2:end-1);
    new_mr_test_post_fft{i} = P1 + const;
    % avg_spectrum = avg_spectrum + P1';
end

worn_mr_test_pre_fft = reshape(worn_mr_test(1:(length(worn_mr_test) - mod(length(worn_mr_test), signal_lim))), [signal_lim, floor(length(worn_mr_test)/signal_lim)]);
worn_mr_test_post_fft = cell(floor(length(worn_mr_test)/signal_lim),1);


for i=1:floor(length(worn_mr_test)/signal_lim)
    Y = fft(worn_mr_test_pre_fft(:,i));
    P2 = abs(Y/L);
    P1 = P2(1:L/2+1);
    P1(2:end-1) = 2*P1(2:end-1);
    worn_mr_test_post_fft{i} = P1 + const;
    % avg_spectrum = avg_spectrum + P1';
end

% feature_dimension = 1;

feature_dimension = (signal_lim/2) + 1;

new_mr_train_post_fft = flip_data(new_mr_train_post_fft);
new_mr_test_post_fft = flip_data(new_mr_test_post_fft);
worn_mr_test_post_fft = flip_data(worn_mr_test_post_fft);

layers = [ sequenceInputLayer(feature_dimension)
    fullyConnectedLayer(feature_dimension)
    tanhLayer
    fullyConnectedLayer(8)
    tanhLayer
    fullyConnectedLayer(4)
    tanhLayer
    fullyConnectedLayer(2)
    tanhLayer
    fullyConnectedLayer(4)
    tanhLayer
    fullyConnectedLayer(8)
    tanhLayer
    fullyConnectedLayer(feature_dimension)];

options = trainingOptions('adam', ...
    'InitialLearnRate', 0.1, ...
    'Plots', 'training-progress', ...
    'Metrics','rmse', ...
    'MaxEpochs', 1, ...
    'ExecutionEnvironment','parallel-cpu');

net_fft = trainnet(new_mr_train_post_fft, new_mr_train_post_fft, layers, "mse", options);
decoded_new_fft = predict(net_fft,new_mr_test_post_fft{120});
decoded_worn_fft = predict(net_fft,worn_mr_test_post_fft{260});

helperVisualizeModelBehavior(new_mr_test_post_fft{120}, worn_mr_test_post_fft{120}, decoded_new_fft, decoded_worn_fft);

%% Plot MSE

decoded_new_fft_mse = zeros(length(new_mr_test_post_fft),1);
for i=1:length(new_mr_test_post_fft)
    decoded_new_fft = predict(net_fft,new_mr_test_post_fft{i});
    decoded_new_fft_mse(i) = mean(abs(decoded_new_fft' - new_mr_test_post_fft{i}').^2);
end

decoded_worn_fft_mse = zeros(length(worn_mr_test_post_fft),1);
for i=1:length(worn_mr_test_post_fft)
    decoded_worn_fft = predict(net_fft,worn_mr_test_post_fft{i});
    decoded_worn_fft_mse(i) = mean(abs(decoded_worn_fft' - worn_mr_test_post_fft{i}').^2);
end

figure;
subplot(2,1,1);
plot(decoded_new_fft_mse);
ylim([0 10])
title("new mse")
subplot(2,1,2);
plot(decoded_worn_fft_mse);
ylim([0 10])
title("worn mse")

%% Helper Functions

