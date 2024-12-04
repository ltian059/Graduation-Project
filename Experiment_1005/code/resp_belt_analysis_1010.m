clc;
clear all;
% close all;

%% Load data
% designated folder
folder = "D:\OneDrive\Desktop\Graduate Project\Belt\data\belt20241014\GDX-RB 0K1002U5"
filename = 'force_data_20241014142508.csv'
belt_data = readmatrix(fullfile(folder,filename));
belt_fs = 10;   % default respiration belt sampling rate

belt_posix_timestamp = belt_data(:,1);
belt_datetime_timestamp = datetime(belt_posix_timestamp,'convertfrom','posixtime', 'Format', 'yyyy-MM-dd HH:mm:ss.SSS');
start_date = belt_datetime_timestamp(1);
belt_local_datetime_timestamp = convert_to_ottawa_time(start_date,belt_datetime_timestamp);

chest_meas = round(belt_data(:,2),2);    % resolution 0.01 N

%% Plot
figure
plot(belt_local_datetime_timestamp,chest_meas)
title('Respiration Belt Force Measurement')
xlabel('time')
ylabel('force (N)') 
xlim([belt_local_datetime_timestamp(1) belt_local_datetime_timestamp(end)]);

