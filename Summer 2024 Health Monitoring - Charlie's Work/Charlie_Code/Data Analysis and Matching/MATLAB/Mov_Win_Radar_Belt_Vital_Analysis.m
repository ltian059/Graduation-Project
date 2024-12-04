clc;
clear all;
close all;

% folder = 'E:\Lab\HR_data\Normal_Dataset\Lying\radar@head\Normal_dataset_6';
folder = '/Users/chaficlabaki/Desktop/Radar Project/Lab_Radar_Belt/Normal_Dataset/Valid_Seating/Normal_dataset_9';

% UTC_offset corresponding to the Winter time in Canada (Nov 6, 2022 - Mar 12,2023)
% ETC_offset corresponding to the Summer time in Canada (Mar 12, 2022 - Nov 5,2023)
UTC_offset = -5; 
ETC_offset = -4;

% List the .csv files in 
file_list = dir(folder);

%% Read Respiration Belt Data
% Find the belt_file_name according to keywords bb or belt
% Read the files
for i = 1:numel(file_list)
    file_name = file_list(i).name;
%     isempty(strfind(file_name,"belt"))
    if contains(file_name,"belt") || contains(file_name,"bb")
        belt_file_name = file_name;
    end
end
% belt_file_name = 'belt_back_normal.csv';
belt_data = readmatrix(fullfile(folder,belt_file_name));
belt_fs = 10;   % default respiration belt sampling rate

belt_posix_timestamp = belt_data(:,1);
belt_datetime_timestamp = datetime(belt_posix_timestamp,'convertfrom','posixtime', 'Format', 'yyyy-MM-dd HH:mm:ss.SSS');
belt_local_datetime_timestamp = belt_datetime_timestamp + hours(ETC_offset);

chest_meas = round(belt_data(:,2),2);    % resolution 0.01 N

%% Read Radar Data
for i = 1:numel(file_list)
    file_name = file_list(i).name;
%     isempty(strfind(file_name,"belt"))
    if contains(file_name,"radar") || contains(file_name,"rd")
        radar_file_name = file_name;
    end
end
% radar_file_name = 'radar_back_normal_1.809m.csv';
radar_data = readmatrix(fullfile(folder,radar_file_name));
radar_fs = 17;    % radar sampling rate
radar_resolution = 9.9/188; % meter
approx_range = 1.6; % 

[rows columns] = size(radar_data);
range_bin_dist = (1:columns-1) * radar_resolution;
radar_posix_timestamp = radar_data(:,1);
radar_datetime_timestamp = datetime(radar_posix_timestamp,'convertfrom','posixtime', 'Format', 'yyyy-MM-dd HH:mm:ss.SSS');
radar_local_datetime_timestamp = radar_datetime_timestamp + hours(ETC_offset);

radar_mat = radar_data(:,2:end);

%% Plot the Range-Time Map
% Addressing Static Multi-path: simply subtracting the current radar frame from the previous frame
% Calculate the absolute value of the radar matrix to make the trajectory more visible 
diff_radar_mat = abs(diff(radar_mat));
diff_radar_mat = transpose(diff_radar_mat);

% Remove direct path (0-10 range bin)
direct_path_num = 10;
% Normalize Each Radar Scan
[rd_mat_rows rd_mat_columns] = size(diff_radar_mat()); 
for i = 1:rd_mat_columns
   diff_radar_mat(:,i) = Array_Normalization(diff_radar_mat(:,i)); 
end

time = radar_local_datetime_timestamp(1:end-1);
dist = transpose(range_bin_dist);

figure
inst_RT_map = pcolor(time, dist, diff_radar_mat);
set(inst_RT_map, 'EdgeColor', 'none')
ylim([direct_path_num*radar_resolution dist(end)])
xlim([time(1) time(end)])
title('Range Time Map')

%% Data alignment
% According to the data collection mechanism, radar collection starts about
% 5 seconds later than the respiration belt collection

radar_start_ts = radar_local_datetime_timestamp(1);
belt_align_idx = knnsearch(datenum(belt_local_datetime_timestamp),datenum(radar_start_ts));

belt_end_ts = belt_local_datetime_timestamp(end);
radar_align_idx = knnsearch(datenum(radar_local_datetime_timestamp),datenum(belt_end_ts));

% Crop the belt data
belt_local_datetime_timestamp = belt_local_datetime_timestamp(belt_align_idx:end);
chest_meas = chest_meas(belt_align_idx:end);

% Crop the radar data
radar_local_datetime_timestamp = radar_local_datetime_timestamp(1:radar_align_idx);
radar_mat = radar_mat(1:radar_align_idx,:);

%% Vital signs extraction
% Premise: according to the Range-Time Map analysis (preprocessing, CFAR
% detection, tracking), we find the target is quasi-stationary in a certain
% period at a certain location (target location is a flat line over
% time),e.g. approx_range in this case,
% then we will first find out the best range bin data for analyzing.
% In real scenario, the start and the end of the vital-dominant interval
% will be the start and end of duration that no location variation is
% found.

phase_radar_mat = unwrap(angle(radar_mat));
approx_bin_idx = floor(approx_range / radar_resolution);

% Candidate bins
bin_idx_st = approx_bin_idx-9;
bin_idx_end = approx_bin_idx+10;
vital_cand_mat = phase_radar_mat(:, bin_idx_st : bin_idx_end);
fprintf('Radar vital candidates have been extracted \n')

% Vital Candidates Analysis
[vital_cand_mat_rows vital_cand_columns] = size(vital_cand_mat);
per_ratio_set = zeros([vital_cand_columns,1]);

filt_vital_cand_mat = zeros([vital_cand_mat_rows vital_cand_columns]);

for i = 1:vital_cand_columns
    cur_bin_idx = bin_idx_st + i - 1;
    cur_dist = round(cur_bin_idx*radar_resolution, 2);
    vital_cand = vital_cand_mat(:,i);
    vital_cand = vital_cand - mean(vital_cand); % Analyzed vital candidate is a zero-mean array     
    
    % Baseline removal: highpass filter
    filt_vital_cand = Baseline_Drift_Removal(vital_cand,radar_fs);
    filt_vital_cand_mat(:,i) = filt_vital_cand;
    
    % Frequency Analysis
    [subfreq_mag,freq] = FFTanalysis(filt_vital_cand,radar_fs); % If radar has been decimated we should use decimated fs
    [argvalue, argmax_ind] = max(subfreq_mag);
    max_power_freq = freq(argmax_ind);
    max_power = argvalue;

    [fft_row,fft_col] = size(subfreq_mag);
    remain_avg_power = (sum(subfreq_mag) - max_power) / (fft_row - 1);

    % Periodicity index: max_freq / remain_average_freq
    ratio_max_avg = max_power / remain_avg_power;
    per_ratio_set(i) = ratio_max_avg;
end

% Select vital signal range bin
[per_argvalue, per_argmax_ind] = max(per_ratio_set);
vital_bin_idx = bin_idx_st + per_argmax_ind -1;
vital_bin_dist = round(vital_bin_idx*radar_resolution, 2);
vital_sig = vital_cand_mat( : ,per_argmax_ind); % original range bin signal

filt_vital_sig = filt_vital_cand_mat(:,per_argmax_ind);

%% Data visualization
figure
subplot(2,1,1)
plot(belt_local_datetime_timestamp,chest_meas)
title('Respiration Belt Force Measurement')
xlabel('time')
ylabel('force (N)') 

subplot(2,1,2)
plot(radar_local_datetime_timestamp,filt_vital_sig)
title('Radar Extracted Vital Signal in ' + string(vital_bin_dist) + ' m range bin' + ' id: ' + string(vital_bin_idx))
xlabel('time')
ylabel('phase magnitude')

%% Moving window data segmentation
duration = 30;  % seconds
hr_duration = 15;   % seconds
belt_len = duration * belt_fs;
radar_len = duration * radar_fs;
update_dur = 1;    % seconds; update every 1 second. overlap duration = duration - update_dur = 29 seconds
% seg_num = min(floor(length(chest_meas)/belt_len),floor(rows/radar_len));    % segmentation number without overlap

% segmentation number with overlap
belt_seg_num = floor((length(chest_meas) - (belt_len-update_dur*belt_fs))/(update_dur*belt_fs));
radar_seg_num = floor((length(filt_vital_sig) - (radar_len-update_dur*radar_fs))/(update_dur*radar_fs)); 
seg_num = min(belt_seg_num,radar_seg_num);

% for loop
chest_meas_seg_set = zeros([seg_num,belt_len]);
radar_vital_seg_set = zeros([seg_num,radar_len]);
per_test_flag_set = zeros([seg_num,1]);
ratio_max_avg_set = zeros([seg_num,1]);
br_error_set = NaN([seg_num,1]);
br_acc_set = NaN([seg_num,1]);
br_corr_set = NaN([seg_num,1]);

belt_hr_sig_set = NaN([seg_num,hr_duration*belt_fs]);
radar_hr_sig_set = NaN([seg_num,hr_duration*radar_fs]);
hr_error_set = NaN([seg_num,1]);
zc_hr_error_set = NaN([seg_num,1]);
hr_acc_set = NaN([seg_num,1]);
hr_diff = NaN([seg_num,1]);
hr_corr_set = NaN([seg_num,1]);

for seg_id = 1:seg_num
    chest_meas_seg = chest_meas((seg_id-1)*belt_fs+1 : (seg_id-1)*belt_fs+belt_len);
    chest_meas_seg_set(seg_id,:) = chest_meas_seg;
    
    radar_vital_seg = filt_vital_sig((seg_id-1)*radar_fs+1 : (seg_id-1)*radar_fs+radar_len);
    radar_vital_seg_set(seg_id,:) = radar_vital_seg;
    
    % Radar vital periodicity measurement
    [subfreq_mag,freq] = FFTanalysis(radar_vital_seg,radar_fs); % If radar has been decimated we should use decimated fs
    [argvalue, argmax_ind] = max(subfreq_mag);
    max_power_freq = freq(argmax_ind);
    max_power = argvalue;
    [fft_row,fft_col] = size(subfreq_mag);
    remain_avg_power = (sum(subfreq_mag) - max_power) / (fft_row - 1);
    ratio_max_avg = max_power / remain_avg_power;
    ratio_max_avg_set(seg_id) = ratio_max_avg;
    if ratio_max_avg > 10 && max_power_freq >= 10
        per_test_flag = 1;  % Pass the periodicity test
    else
        per_test_flag = 0;  % Fail the periodicity test
    end
    per_test_flag_set(seg_id) = per_test_flag;
    
    % If pass the periodicity test, extract the segment's breathing rate
    if per_test_flag == 1
        % Compare the BR estimation result with belt data 
        radar_est_br = max_power_freq;
        [belt_subfreq_mag,belt_freq] = FFTanalysis(chest_meas_seg,belt_fs);
        [belt_br_freq_mag,belt_br_freq_loc] = max(belt_subfreq_mag);
        belt_est_br = belt_freq(belt_br_freq_loc);
        br_error_set(seg_id) = abs(belt_est_br - radar_est_br);
        br_acc_set(seg_id) = (1 - abs(belt_est_br - radar_est_br)/belt_est_br) * 100;   % accuracy show in percentage
        
        % Calculate the cross-correlation of radar and belt data
        res_radar_vital_seg = resample(radar_vital_seg,belt_fs,radar_fs);
        br_corr = corrcoef(chest_meas_seg,res_radar_vital_seg);
        br_corr_set(seg_id) = br_corr(1,2);
        
        
        % Segmentation for HR signal extraction (the last 20-sec data would not be able to analyze if BR is valid)
        radar_hr_seg = HR_BP_Filter(radar_vital_seg(1:hr_duration*radar_fs),radar_fs);
        radar_hr_sig_set(seg_id,:) = radar_hr_seg;
        % bp_filt_vital_sig = HR_BP_Filter(filt_vital_sig,radar_fs);
        [bp_radar_subfreq_mag,bp_radar_freq] = FFTanalysis(radar_hr_seg,radar_fs);
        [bp_radar_hr_freq_mag,bp_radar_hr_freq_loc] = max(bp_radar_subfreq_mag);
        radar_est_hr = bp_radar_freq(bp_radar_hr_freq_loc);
        % Zero-crossing heart rate
        [~,radar_hr_count] = zerocrossrate(radar_hr_seg,TransitionEdge="rising");
        radar_zc_est_hr = radar_hr_count * 60/hr_duration;

        
        belt_hr_seg = HR_BP_Filter(chest_meas_seg(1:hr_duration*belt_fs),belt_fs);
        belt_hr_sig_set(seg_id,:) = belt_hr_seg;
        % bp_chest_meas_seg = HR_BP_Filter(belt_hr_seg,belt_fs);
        [bp_belt_subfreq_mag,bp_belt_freq] = FFTanalysis(belt_hr_seg,belt_fs);
        [bp_belt_hr_freq_mag,bp_belt_hr_freq_loc] = max(bp_belt_subfreq_mag);
        belt_est_hr = bp_belt_freq(bp_belt_hr_freq_loc);
        % Zero-crossing heart rate
        [~,belt_hr_count] = zerocrossrate(belt_hr_seg,TransitionEdge="rising");
        belt_zc_est_hr = belt_hr_count * 60/hr_duration;
        
        % Compare the HR estimation result with belt data
        hr_error_set(seg_id) = abs(belt_est_hr - radar_est_hr);
        zc_hr_error_set(seg_id) = abs(radar_zc_est_hr - belt_zc_est_hr);
        hr_acc_set(seg_id) = (1 - abs(belt_est_hr - radar_est_hr)/belt_est_hr) * 100;   % show in percentage
        hr_diff(seg_id) = abs(belt_est_hr - belt_zc_est_hr);
        % Calculate the cross-correlation of radar and belt data
        res_radar_hr_seg = resample(radar_hr_seg,belt_fs,radar_fs);
        hr_corr = corrcoef(belt_hr_seg,res_radar_hr_seg);
        hr_corr_set(seg_id) = hr_corr(1,2);
    end
end

mean_ratio_max_avg = mean(ratio_max_avg_set);
fprintf('Mean periodicity ratio of valid signal segment is %.2f \n',mean_ratio_max_avg);

num_vital = nnz(per_test_flag_set);   % Number of nonzero matrix elements
fprintf('Number of valid vital signal segment is %d \n',num_vital);

% mean_br_error = mean(br_error_set,'omitnan');
% fprintf('Mean error of valid signal segment BR estimation result is %.2f \n',mean_br_error);

mean_br_acc = mean(br_acc_set,'omitnan');
fprintf('Mean accuracy of valid signal segment BR estimation result is %.2f %%\n',mean_br_acc);

median_br_acc = median(br_acc_set,'omitnan');
fprintf('Median accuracy of valid signal segment BR estimation result is %.2f %% \n',median_br_acc);

pct_br_acc = prctile(br_acc_set(~isnan(br_acc_set)),10);
fprintf('90th Percentile accuracy of valid signal segment BR estimation result is %.2f %% \n',pct_br_acc);

% mean_br_corr = mean(abs(br_corr_set),'omitnan');
% fprintf('Mean cross-correlation of radar BR signal and belt BR signal is %.2f \n',mean_br_corr);

% mean_hr_error = mean(hr_error_set,'omitnan');
% fprintf('Mean error of valid signal segment HR estimation result is %.2f \n',mean_hr_error);

mean_hr_acc = mean(hr_acc_set,'omitnan');
fprintf('Mean accuracy of valid signal segment HR estimation result is %.2f %%\n',mean_hr_acc);

median_hr_acc = median(hr_acc_set,'omitnan');
fprintf('Median accuracy of valid signal segment HR estimation result is %.2f %% \n',median_hr_acc);

pct_hr_acc = prctile(hr_acc_set(~isnan(hr_acc_set)),10);
fprintf('90th Percentile accuracy of valid signal segment HR estimation result is %.2f %% \n',pct_hr_acc);

% mean_zc_hr_error = mean(zc_hr_error_set,'omitnan');
% fprintf('Mean error of valid signal segment zero-crossing HR estimation result is %.2f \n',mean_zc_hr_error);

% mean_hr_diff = mean(hr_diff,'omitnan');
% fprintf('Mean difference of valid signal segment between zero-crossing HR estimation and spectrum analysis result is %.2f \n',mean_hr_diff);

% mean_hr_corr = mean(abs(hr_corr_set),'omitnan');
% fprintf('Mean cross-correlation of radar HR signal and belt HR signal is %.2f \n',mean_hr_corr);




% seg_id = 1;
% 
% chest_meas_seg = chest_meas((seg_id-1)*belt_len+1 : seg_id*belt_len);
% belt_seg_datetime_ts = belt_local_datetime_timestamp((seg_id-1)*belt_len+1 : seg_id*belt_len);
% chest_meas_seg = Baseline_Drift_Removal(chest_meas_seg,belt_fs);
% 
% filt_vital_sig_seg = filt_vital_sig((seg_id-1)*radar_len+1 : seg_id*radar_len,:);
% 
% %% Spectrum Analysis
% % Breathing Rate Estimation
% % Respiration Belt
% [belt_subfreq_mag,belt_freq] = FFTanalysis(chest_meas_seg,belt_fs);
% [belt_br_freq_mag,belt_br_freq_loc] = max(belt_subfreq_mag);
% belt_est_br = belt_freq(belt_br_freq_loc);
% fprintf('Respiration belt estimated breathing rate is %.2f bpm \n',belt_est_br);
% 
% % Radar
% [radar_subfreq_mag,radar_freq] = FFTanalysis(filt_vital_sig,radar_fs);
% [radar_br_freq_mag,radar_br_freq_loc] = max(radar_subfreq_mag);
% radar_est_br = radar_freq(radar_br_freq_loc);
% fprintf('Radar estimated breathing rate is %.2f bpm \n',radar_est_br);
% 
% br_error = abs(belt_est_br - radar_est_br);
% fprintf('Breathing rate estimation error is %.1f bpm \n',br_error);
% 
% figure
% subplot(2,1,1)
% plot(belt_freq,belt_subfreq_mag)
% xlabel('Frequency (acts/min)');ylabel('Amplitude Spectrum');
% xlim([0 100])
% title('Amplitude Spectrum of Chest Force Measurements');
% 
% subplot(2,1,2)
% plot(radar_freq,radar_subfreq_mag)
% xlabel('Frequency (acts/min)');ylabel('Amplitude Spectrum');
% xlim([0 100])
% title('Amplitude Spectrum of Phase');
% 
% % Heart Rate Estimation
% % Respiration Belt
% bp_chest_meas_seg = HR_BP_Filter(chest_meas_seg,belt_fs);
% [bp_belt_subfreq_mag,bp_belt_freq] = FFTanalysis(bp_chest_meas_seg,belt_fs);
% [bp_belt_hr_freq_mag,bp_belt_hr_freq_loc] = max(bp_belt_subfreq_mag);
% belt_est_hr = bp_belt_freq(bp_belt_hr_freq_loc);
% fprintf('Respiration belt estimated heart rate is %.2f bpm \n',belt_est_hr);
% 
% % Radar
% bp_filt_vital_sig = HR_BP_Filter(filt_vital_sig,radar_fs);
% [bp_radar_subfreq_mag,bp_radar_freq] = FFTanalysis(bp_filt_vital_sig,radar_fs);
% [bp_radar_hr_freq_mag,bp_radar_hr_freq_loc] = max(bp_radar_subfreq_mag);
% radar_est_hr = bp_radar_freq(bp_radar_hr_freq_loc);
% fprintf('Radar estimated heart rate is %.2f bpm \n',radar_est_hr);
% 
% hr_error = abs(belt_est_hr - radar_est_hr);
% fprintf('Heart rate estimation error is %.1f bpm \n',hr_error);
% 
% figure
% subplot(2,1,1)
% plot(belt_seg_datetime_ts,bp_chest_meas_seg)
% title('Bandpass Respiration Belt Force Measurement')
% xlabel('time')
% ylabel('force (N)') 
% subplot(2,1,2)
% plot(vital_datetime_ts,bp_filt_vital_sig)
% title('Bandpass Radar Extracted Vital Signal')
% xlabel('time')
% ylabel('phase magnitude')
% 
% figure
% subplot(2,1,1)
% plot(bp_belt_freq,bp_belt_subfreq_mag)
% xlabel('Frequency (acts/min)');ylabel('Amplitude Spectrum');
% xlim([0 100])
% title('Amplitude Spectrum of Bandpass Chest Force Measurements');
% 
% subplot(2,1,2)
% plot(bp_radar_freq,bp_radar_subfreq_mag)
% xlabel('Frequency (acts/min)');ylabel('Amplitude Spectrum');
% xlim([0 100])
% title('Amplitude Spectrum of Bandpass Phase');
% 
% %% Data correlation measurement
% % Resample the radar vital signal to respiration belt sampling rate
% res_filt_vital_sig = resample(filt_vital_sig,belt_fs,radar_fs);
% res_bp_filt_vital_sig = resample(bp_filt_vital_sig,belt_fs,radar_fs);
% 
% % Correlation Coefficient of filtered radar vital signal and respiration belt signal
% R = corrcoef(chest_meas_seg,res_filt_vital_sig);
% fprintf('Correlation coefficient of breathing signals is %.2f  \n',R(1,2));
% 
% bp_R = corrcoef(bp_chest_meas_seg,res_bp_filt_vital_sig);
% fprintf('Correlation coefficient of heart signals is %.2f  \n',bp_R(1,2));