clc;
clear;

% Use readmatrix to load the data from the CSV
data = readmatrix("D:\OneDrive\Desktop\Graduate Project\Belt\data\belt20241005\GDX-RB 0K1000Z9\tide_Li_force_data_20241005203009.csv");
experiment = "Tide";
myTitle = "Subjet 1 (Li) Respiratory Signal over time ("+experiment+")";
exportPath = "./beltPlot";

if ~exist(exportPath,'dir')
    mkdir(exportPath)
end
% Extract time and respiratory signal
time = data(:, 1);
resp_signal = data(:, 2);
time_in_seconds = time - time(1);

% Plot respiratory signal
figure;
set(gcf, 'Position', [100, 100, 800, 600]);  % add just window size [x, y, width, height]
plot(time_in_seconds, resp_signal);
xlabel('Time (s)');
ylabel('Respiratory Signal');
title(myTitle);

exportgraphics(gcf, exportPath+"\" + myTitle+".png", 'Resolution', 1000);
