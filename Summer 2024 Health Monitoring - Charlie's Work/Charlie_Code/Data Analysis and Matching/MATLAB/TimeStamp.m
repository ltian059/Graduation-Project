% Load CSV file
clear;
clc;
fid = fopen("D:\Analog Devices\MAX86176_20240921_070952_PPG.csv", 'r');
% Read each line as a string
data_lines = {};
while ~feof(fid)
    data_lines{end+1} = fgetl(fid);  % Read one line at a time
end

% Close the file
fclose(fid);

% Initialize cell arrays for timestamps and data
timestamps = {};
parsed_data = [];

% Loop through each line
for i = 1:length(data_lines)
    % Split the line at commas
    split_line = strsplit(data_lines{i}, ',');
    
    % First two columns are the date and time
    date_str = split_line{1};
    time_str = split_line{2};
    
    % Combine date and time into one string
    full_timestamp = strcat(date_str, ' ', time_str);
    timestamps{end+1} = full_timestamp;
    
    % The rest are the numerical values
    num_values = cellfun(@str2double, split_line(3:end));  % Convert the rest to numbers
    parsed_data = [parsed_data; num_values];
end