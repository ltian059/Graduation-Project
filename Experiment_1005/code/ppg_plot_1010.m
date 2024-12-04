%% This script load the PPG data and display it with a non-overlap sliding window

clc;
clear all;
% close all;

folder = "D:\OneDrive\Desktop\Graduate Project\log\20241014"

filename = "parsed_file_14102024142619.csv"

file_path = fullfile(folder,filename);

%% Load the data
opts = detectImportOptions(file_path, 'Delimiter', ',');
opts.VariableNamesLine = 1;
data = readtable(file_path, opts);

datasource = data.LED3_PPG1;
%% Preprocessing data
% Replace the colon before milliseconds with a period
% Get the number of timestamps
num_timestamps = length(data.Timestamp_Day_Month_YearHour_Minute_Second_Milisecond_);
% Initialize the modified timestamp column
data.Timestamp_modified = cell(num_timestamps, 1);

for i = 1:num_timestamps
    timestamp_str = data.Timestamp_Day_Month_YearHour_Minute_Second_Milisecond_{i};
    
    % using regular expression to match second and millisecond parts
    tokens = regexp(timestamp_str, '(\d{2}):(\d{1,3})$', 'tokens');
    if ~isempty(tokens)
        seconds_part = tokens{1}{1};
        milliseconds_part = tokens{1}{2};
        % append the millisecond part to 3 digits
        milliseconds_padded = sprintf('%03d', str2double(milliseconds_part));
        % replace colon with dot
        timestamp_modified = regexprep(timestamp_str, '(\d{2}):(\d{1,3})$', [seconds_part '.' milliseconds_padded]);
        data.Timestamp_modified{i} = timestamp_modified;
    else
        % if the timestamp does not match，record warning information
        data.Timestamp_modified{i} = timestamp_str;
        warning('format of timestamp does not match，cannot parse：%s', timestamp_str);
    end
end

% Parse the appended timestamps to datetime object
data.Time_in_datetime = datetime(data.Timestamp_modified, 'InputFormat', 'dd.MM.yyyy HH:mm:ss.SSS');
elapsed_time = seconds(data.Time_in_datetime - data.Time_in_datetime(1));

time = elapsed_time; % Use datetime timestamps
fs = 250;

%% Plot Accelerometer Data
figure;
% set(gcf, 'Position', [100, 100, 800, 600]);  % [x, y, width, height]
hold on;
plot(time, data.ACC_X_mg_, 'r', 'LineWidth', 1, 'DisplayName', 'ACC_X');
plot(time, data.ACC_Y_mg_, 'g', 'LineWidth', 1, 'DisplayName', 'ACC_Y');
plot(time, data.ACC_Z_mg_, 'b', 'LineWidth', 1, 'DisplayName', 'ACC_Z');

xlabel('Time (seconds)');
ylabel('Acceleration (mg)');
title('Accelerometer data');
legend(Location="eastoutside");
grid on;
hold off;
xlim([time(1) time(end)])

% %% Plot window PPG data
% % Use sliding windows to plot LED1_PPG1
% fs = 250;
% window_size = 15 * fs;
% step_size = window_size;
% num_samples = length(data.LED1_PPG1);   % Green light
% time = elapsed_time; % Use datetime timestamps
% 
% for i = 1:step_size:(num_samples - window_size + 1)
%     % Get data for the current window
%     window_data = data.LED1_PPG1(i:i + window_size - 1);
%     window_time = time(i:i + window_size - 1);
% 
%     % Plot the data
%     figure;
%     plot(window_time, window_data);
%     xlabel('Time (Seconds)');
%     ylabel('PPG signals');
% 
%     time_start_datetime = data.Time_in_datetime(1) + seconds(window_time(1));
%     time_end_datetime = data.Time_in_datetime(1) + seconds(window_time(end));
% 
%     title(['LED1\_PPG1, window: ', datestr(time_start_datetime, 'yyyy-mm-dd HH:MM:SS'), ' - ', datestr(time_end_datetime, 'yyyy-mm-dd HH:MM:SS')]);
%     xlim([window_time(1), window_time(end)]);
%     grid on;
% 
%     % Prepare filename-friendly timestamps
%     filename_start = datestr(time_start_datetime, 'yyyy-mm-dd_HH-MM-SS-FFF');
%     filename_end = datestr(time_end_datetime, 'yyyy-mm-dd_HH-MM-SS-FFF');
% end

%% plot LED1_PPG1
figure;
% time = PPG(:,1);
% datasource = PPG(:,2);
plot(time, datasource);
xlabel('Time (seconds)');
ylabel('PPG signals');
title('LED1\_PPG1');

xlim([time(1) time(end)])

% ylim([min_value_LED1 - padding_LED1, max_value_LED1 + padding_LED1]); % set range of y-axis
grid on;

%% Respiratory signal extraction
% HPF
s = datasource;

% s_filt.v = elim_vlfs(s);
% s_filt.t = (1/fs)*(1:length(s_filt.v));

% Eliminate very low frequencies，using a high-pass filter with −3 dB cutoff frequency of 4 breaths per minute (bpm)
Fstop = 0.02;  % in Hz
Fpass = 0.157;  % in Hz     (0.157 and 0.02 provide a - 3dB cutoff of 0.0665 Hz, 4bpm)
Dstop = 0.01;  % Stopband attenuation (0.1% or -40 dB) 0.01
Dpass = 0.05;  % Passband ripple (1%) 0.05

% Eliminate nans
s(isnan(s)) = mean(s(~isnan(s)));
% Create filter
% parameters for the low-pass filter to be used
flag  = 'scale';
[N,Wn,BETA,TYPE] = kaiserord([Fstop Fpass]/(fs/2), [0 1], [Dstop Dpass]);
b  = fir1(N, Wn, TYPE, kaiser(N+1, BETA), flag);
AMfilter = dfilt.dffir(b);
% Remove VHFs
s_dt=detrend(s);
s_filt_v = filtfilt(AMfilter.numerator, 1, s_dt);

s_filt.v = s_filt_v;
s_filt.t = (1/fs)*(1:length(s_filt.v));

figure
plot(s_filt.t,s_filt.v)
title('PPG waveform after remove VLFs')
    xlabel('Time (s)')
    ylabel('Amplitude (V)')
    xlim([s_filt.t(1),s_filt.t(end)])

s = s_filt.v; 

%% Remove Cardio frequency
% Filter signal to remove very high frequencies (VHFs)
ppg.Fpass = 25/60;  % in Hz
ppg.Fstop = 35/60;  % in Hz   (33.12 and 38.5 provide a -3 dB cutoff of 35 Hz)
ppg.Dpass = 0.05;
ppg.Dstop = 0.01;


% Now filt_characteristics will directly reference the 'ppg' structure
filt_characteristics = ppg;
s_filt.fs = fs;

% Eliminate nans
s(isnan(s)) = mean(s(~isnan(s)));
% Create filter
% parameters for the low-pass filter to be used
flag  = 'scale';
[N,Wn,BETA,TYPE] = kaiserord([filt_characteristics.Fpass filt_characteristics.Fstop]/(s_filt.fs/2), [1 0], [filt_characteristics.Dpass filt_characteristics.Dstop]);
b  = fir1(N, Wn, TYPE, kaiser(N+1, BETA), flag);
AMfilter = dfilt.dffir(b);
% Remove VHFs
s_dt=detrend(s);
s_filt_EHF = filtfilt(AMfilter.numerator, 1, s_dt);

s_filt.v = s_filt_EHF;
s_filt.t = (1/s_filt.fs)*(1:length(s_filt.v));

s = s_filt; 

figure
plot(s_filt.t,s_filt.v)
title('PPG waveform after remove cardio frequencies')
    xlabel('Time (s)')
    ylabel('Amplitude (V)')
    xlim([s_filt.t(1),s_filt.t(end)])

%% EHF
% % Filter signal to remove very high frequencies (VHFs)
% ppg.Fpass = 33.12;  % in Hz
% ppg.Fstop = 38.5;  % in Hz   (33.12 and 38.5 provide a -3 dB cutoff of 35 Hz)
% ppg.Dpass = 0.05;
% ppg.Dstop = 0.01;
% 
% % % 绘制原始信号
% % figure;
% % plot(s_filt.t, s_filt.v);
% % title('PPG Signal after filtering out VLF');
% % xlabel('Time (s)');
% % ylabel('Amplitude (V)');
% % xlim([s_filt.t(1), s_filt.t(end)]);
% % grid on;
% 
% % Now filt_characteristics will directly reference the 'ppg' structure
% filt_characteristics = ppg;
% s_filt.fs = fs;
% 
% % Eliminate nans
% s(isnan(s)) = mean(s(~isnan(s)));
% % Create filter
% % parameters for the low-pass filter to be used
% flag  = 'scale';
% [N,Wn,BETA,TYPE] = kaiserord([filt_characteristics.Fpass filt_characteristics.Fstop]/(s_filt.fs/2), [1 0], [filt_characteristics.Dpass filt_characteristics.Dstop]);
% b  = fir1(N, Wn, TYPE, kaiser(N+1, BETA), flag);
% AMfilter = dfilt.dffir(b);
% % Remove VHFs
% s_dt=detrend(s);
% s_filt_EHF = filtfilt(AMfilter.numerator, 1, s_dt);
% 
% s_filt.v = s_filt_EHF;
% s_filt.t = (1/s_filt.fs)*(1:length(s_filt.v));
% 
% s = s_filt; 
% 
% figure
% plot(s_filt.t,s_filt.v)
% title('PPG waveform after remove VHFs')
%     xlabel('Time (s)')
%     ylabel('Amplitude (V)')
%     xlim([s_filt.t(1),s_filt.t(end)])

%% PDt
% detects PPG pulse peaks in PPG signals.
% Filter pre-processed signal to remove frequencies below cardiac freqs
s.v(isnan(s.v)) = mean(s.v(~isnan(s.v)));

% % Downsample
% filt_resample_fs = 25; % up.paramSet.filt_resample_fs -> filt_resample_fs
% d_s = downsample_data(s, filt_resample_fs);
% % Make filter
% % Filter characteristics: Eliminate LFs (below cardiac freqs): For 30bpm cutoff
% elim_sub_cardiac.Fpass = 0.63;  % in Hz; up.paramSet.elim_sub_cardiac.Fpass -> elim_sub_cardiac.Fpass
% elim_sub_cardiac.Fstop = 0.43;  % in Hz     (0.63 and 0.43 provide a - 3dB cutoff of 0.5 Hz); up.paramSet.elim_sub_cardiac.Fstop -> elim_sub_cardiac.Fstop
% elim_sub_cardiac.Dpass = 0.05;  % up.paramSet.elim_sub_cardiac.Dpass -> elim_sub_cardiac.Dpass
% elim_sub_cardiac.Dstop = 0.01;  % up.paramSet.elim_sub_cardiac.Dstop -> elim_sub_cardiac.Dstop
% 
% flag  = 'scale';        % Sampling Flag
% [N,Wn,BETA,TYPE] = kaiserord([elim_sub_cardiac.Fstop elim_sub_cardiac.Fpass]/(d_s.fs/2), [0 1], [elim_sub_cardiac.Dstop elim_sub_cardiac.Dpass]);
% b  = fir1(N, Wn, TYPE, kaiser(N+1, BETA), flag);   % Calculate the coefficients using the FIR1 function.
% AMfilter = dfilt.dffir(b);
% 
% temp_filt = filtfilt(AMfilter.numerator, 1, d_s.v);
% 
% % Resample
% s_filt_rs.v = interp1(d_s.t, temp_filt, s.t);
% s_filt.v = s.v(:)-s_filt_rs.v(:);
% s_filt.t = s.t;
% s_filt.fs = s.fs;

[peaks,onsets,artifs] = adaptPulseSegment(s_filt.v,fs); % IMS: IMS peak detector

figure
plot(s_filt.t,s_filt.v)
hold on;
% Identify Pulse Peaks in original version
% plot(s_filt.t(peaks), s_filt.v(peaks), 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
plot(s_filt.t(peaks), s_filt.v(peaks), 'ro', 'MarkerSize', 8);
% Add labels and title
xlabel('Time (s)');
ylabel('Amplitude');
title('PPG Signal peak detection using IMS');
legend('PPG Signal', 'Detected Peaks');
% Show the plot
hold off;
xlim([s_filt.t(1),s_filt.t(end)])

%% FPt
% FPT detects Fiducial Points from PPG peak and trough annotations
% INTERFACE: relevant data variable rel_data from PDt
rel_data.s.t = s.t;
rel_data.s.v = s.v;
rel_data.beats.tr.t = s.t(onsets);
rel_data.beats.tr.v = s.v(onsets);
rel_data.beats.p.t = s.t(peaks);
rel_data.beats.p.v = s.v(peaks);
rel_data.fs = fs;
rel_data.timings = s.t;

% PPG Peaks
% Find peaks as max between detected onsets
temp.p_max.t = nan(length(rel_data.beats.tr.t)-1,1);
temp.p_max.v = nan(length(rel_data.beats.tr.t)-1,1);
for beat_no = 1 : (length(rel_data.beats.tr.t)-1)
    rel_range = find(rel_data.s.t >= rel_data.beats.tr.t(beat_no) & rel_data.s.t < rel_data.beats.tr.t(beat_no+1));
    [~, rel_el] = max(rel_data.s.v(rel_range));
    temp.p_max.t(beat_no) = rel_data.s.t(rel_range(rel_el));
    temp.p_max.v(beat_no) = rel_data.s.v(rel_range(rel_el));
end

% PPG Troughs
% Find troughs as min between detected peaks
temp.tr_min.t = nan(length(temp.p_max.t)-1,1);
temp.tr_min.v = nan(length(temp.p_max.t)-1,1);
for beat_no = 1 : (length(temp.p_max.t)-1)
    rel_range = find(rel_data.s.t >= temp.p_max.t(beat_no) & rel_data.s.t < temp.p_max.t(beat_no+1));
    [~, rel_el] = min(rel_data.s.v(rel_range));
    temp.tr_min.t(beat_no) = rel_data.s.t(rel_range(rel_el));
    temp.tr_min.v(beat_no) = rel_data.s.v(rel_range(rel_el));
end

% get rid of any nans (arise if the peak is at the very first element of the signal)
bad_els = isnan(temp.tr_min.t);
temp.tr_min.t = temp.tr_min.t(~bad_els);
temp.tr_min.v = temp.tr_min.v(~bad_els);

% very ocassionally it picks out the same trough or peak twice (if two consecutive peaks are ridiculously close together so share some of the same search range)
[~, rel_els, ~] = unique(temp.tr_min.t);
temp.tr_min.t = temp.tr_min.t(rel_els);
temp.tr_min.v = temp.tr_min.v(rel_els);

% Carry forward detected peaks and onsets
temp.det_p.t = rel_data.beats.p.t;
temp.det_p.v = rel_data.beats.p.v;
temp.det_tr.t = rel_data.beats.tr.t;
temp.det_tr.v = rel_data.beats.tr.v;

% carry forward fs and timings
temp.fs = rel_data.fs;
temp.timings = rel_data.timings;

%% FMe
% FMe measures features from peak and trough values
% INTERFACE: relevant data variable rel_data from FPt
rel_data = temp;
clear peaks onsets

% choose which peaks and onsets:
rel_data.tr = rel_data.tr_min;
rel_data.p = rel_data.p_max;

if isempty(rel_data.tr.t) || isempty(rel_data.p.t)
    [peaks.t, peaks.v, onsets.t, onsets.v] = deal([]);
else

    % Want an onset followed by a peak.
    if rel_data.tr.t(1) > rel_data.p.t(1)
        rel_data.p.t = rel_data.p.t(2:end);
        rel_data.p.v = rel_data.p.v(2:end);
    end
    % Want the same number of peaks and onsets
    diff_in_length = length(rel_data.p.t) - length(rel_data.tr.t);
    if diff_in_length > 0
        rel_data.p.t = rel_data.p.t(1:(end-diff_in_length));
        rel_data.p.v = rel_data.p.v(1:(end-diff_in_length));
    elseif diff_in_length < 0
        rel_data.tr.t = rel_data.tr.t(1:(end-diff_in_length));
        rel_data.tr.v = rel_data.tr.v(1:(end-diff_in_length));
    end
    % find onsets and peaks
    onsets.t = rel_data.tr.t; onsets.t = onsets.t(:);
    onsets.v = rel_data.tr.v; onsets.v = onsets.v(:);
    peaks.t = rel_data.p.t; peaks.t = peaks.t(:);
    peaks.v = rel_data.p.v; peaks.v = peaks.v(:);

    % exclude ectopics
    % following: Mateo, J. & Laguna, P., 2003. Analysis of heart rate variability in the presence of ectopic beats using the heart timing signal. IEEE transactions on bio-medical engineering, 50(3), pp.334–43. Available at: http://www.ncbi.nlm.nih.gov/pubmed/12669990.
    tk_neg1 = peaks.t(1:(end-2));
    tk = peaks.t(2:(end-1));
    tk_pos1 = peaks.t(3:end);
    r = 2*abs( (tk_neg1 - (2*tk) + tk_pos1)./ ...
        ( (tk_neg1-tk).*(tk_neg1 - tk_pos1).*(tk-tk_pos1) ) );
    thresh = min([4.3*std(r), 0.5]);

    %%%%%%%%%%%%%%%%%%%%%%
    % additional rule inserted by PC:
    % thresh = 0.5;   % so that artificial data with a very low variability doesn't trigger.
    %%%%%%%%%%%%%%%%%%%%%%
    temp = [0;r;0]; temp = logical(temp>thresh);

    tk_neg1 = onsets.t(1:(end-2));
    tk = onsets.t(2:(end-1));
    tk_pos1 = onsets.t(3:end);
    r = 2*abs( (tk_neg1 - (2*tk) + tk_pos1)./ ...
        ( (tk_neg1-tk).*(tk_neg1 - tk_pos1).*(tk-tk_pos1) ) );
    thresh = min([4.3*std(r), 0.5]);
    %%%%%%%%%%%%%%%%%%%%%%
    % additional rule inserted by PC:
    %thresh = 0.5;   % so that artificial data with a very low variability doesn't trigger.
    %%%%%%%%%%%%%%%%%%%%%%
    temp2 = [0;r;0]; temp2 = logical(temp2>thresh);

    peaks.t(temp | temp2) = nan; peaks.v(temp | temp2) = nan;
    onsets.t(temp | temp2) = nan; onsets.v(temp | temp2) = nan;
end

feat_data = calc_am(peaks, onsets, fs);
% feat_data = calc_fm(peaks, fs);
% feat_data = calc_bw(peaks, onsets, fs);

feat_data.timings = rel_data.timings;

figure
plot(feat_data.t,feat_data.v)
title('PPG waveform after beat-by-beat feature extraction')
    xlabel('Time (s)')
    ylabel('Amplitude (V)')
    xlim([s_filt.t(1),s_filt.t(end)])

%% RS - resampling
% RS resamples feat-based respiratory signals at a regular sampling rate
fs_orig = fs;
% fs = 5; % fs = up.paramSet.resample_fs;
fs = fs_orig; 
% resampled_data = lin(feat_data, fs);
resampled_data = cub(feat_data, fs);
resampled_data.fs = fs;

% Bandpass filtering to remove frequencies not related to respiration (non-respiratory frequencies)
try
    resampled_data = bpf_signal_to_remove_non_resp_freqs(resampled_data, resampled_data.fs, up);
catch
    % if there aren't enough samples, then don't BPF:
    resampled_data = resampled_data;
end

figure
plot(resampled_data.t,resampled_data.v)
title('PPG waveform after resampling')
    xlabel('Time (s)')
    ylabel('Amplitude (V)')
    xlim([s_filt.t(1),s_filt.t(end)])

%% ELF
% ELF eliminates very low frequencies from resampled respiratory
% INTERFACE
old_data = resampled_data;

resp_data.hpfilt.t = old_data.t;
try
    resp_data.hpfilt.v = elim_vlfs(old_data);
catch
    % if there aren't enough points to use the filter, simply carry forward the previous data
    resp_data.hpfilt.v = old_data.v;
end
resp_data.hpfilt.fs = old_data.fs;

%% Visualization
figure
plot(resp_data.hpfilt.t,resp_data.hpfilt.v)
title('Extracting Respiratory Signal')
    xlabel('Time (s)')
    ylabel('Amplitude (V)')
    % xlim([0 95])
    xlim([resp_data.hpfilt.t(1),resp_data.hpfilt.t(end)])
