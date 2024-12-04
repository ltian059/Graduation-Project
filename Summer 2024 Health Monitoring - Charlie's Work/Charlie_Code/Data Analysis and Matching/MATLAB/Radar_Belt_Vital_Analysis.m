clc;
clear all;
%close all;

folders = ["dataset_1";"dataset_3"];
for k = 1:numel(folders(:,1))
    folder=folders(k,:);
    % UTC_offset corresponding to the Winter time in Canada (Nov 6, 2022 - Mar 12,2023)
    % ETC_offset corresponding to the Summer time in Canada (Mar 12, 2022 - Nov 5,2023)
    UTC_offset = -5; 
    ETC_offset = -4;
    
    % List the .csv files in 
    file_list = dir(folder);
    
    %% Read Respiration Belt Data
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
    
    belt_posix_timestamp = linspace(belt_data(1,1),belt_data(end,1),length(belt_data))';
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
    approx_range = 3; % 
    
    [rows columns] = size(radar_data);
    range_bin_dist = (1:columns-1) * radar_resolution;
    radar_posix_timestamp = radar_data(:,1);
    radar_datetime_timestamp = datetime(radar_posix_timestamp,'convertfrom','posixtime', 'Format', 'yyyy-MM-dd HH:mm:ss.SSS');
    radar_local_datetime_timestamp = radar_datetime_timestamp + hours(ETC_offset);
    
    radar_mat = radar_data(:,2:end);
    
    %% Confirm the existence of vital signs in Radar Matrix
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
    
    % Crop the belt data
    belt_local_datetime_timestamp = belt_local_datetime_timestamp(belt_align_idx:end);
    chest_meas = chest_meas(belt_align_idx:end);
    
    %% Data segmentation
    %duration = floor(max(length(chest_meas)/belt_fs,length(radar_data)/radar_fs));  % seconds
    duration = 30;
    belt_len = duration * belt_fs;
    radar_len = duration * radar_fs;
    seg_num = min(floor(length(chest_meas)/belt_len),floor(rows/radar_len));    % segmentation number without overlap
    
    %% Vital signs extraction
    seg_id = 3;
    chest_meas_seg = chest_meas((seg_id-1)*belt_len+1 : seg_id*belt_len);
    belt_seg_datetime_ts = belt_local_datetime_timestamp((seg_id-1)*belt_len+1 : seg_id*belt_len);
    chest_meas_seg = Baseline_Drift_Removal(chest_meas_seg,belt_fs);
    
    phase_radar_mat = unwrap(angle(radar_mat));
    radar_mat_seg = phase_radar_mat((seg_id-1)*radar_len+1 : seg_id*radar_len,:);
    
    approx_bin_idx = floor(approx_range / radar_resolution);
    
    % Candidate bins
    bin_idx_st = approx_bin_idx-9;
    bin_idx_end = approx_bin_idx+10;
    vital_cand_mat = radar_mat_seg(:, bin_idx_st : bin_idx_end);
    vital_datetime_ts = radar_local_datetime_timestamp((seg_id-1)*radar_len+1 : seg_id*radar_len);
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
    
    % order=8;   %order of filter
    % fcuthigh = 5/60;   %high cut frequency in Hz (1 Hz = 60 bpm /60 sec)
    % [b,a]=butter(order,fcuthigh/(radar_fs/2),'high');   % fs/2 term in the cutoff freq is the Nyquist Sampling rate 
    % filt_vital_sig = filter(b,a,vital_sig);  %filtered signal
    
    filt_vital_sig = filt_vital_cand_mat(:,per_argmax_ind);
    
    %% Data visualization
    figure
    subplot(2,1,1)
    plot(belt_seg_datetime_ts,chest_meas_seg)
    title('Respiration Belt Force Measurement')
    xlabel('time')
    ylabel('force (N)') 
    
    subplot(2,1,2)
    plot(vital_datetime_ts,filt_vital_sig)
    % plot(vital_datetime_ts,vital_sig)
    title('Radar Extracted Vital Signal in ' + string(vital_bin_dist) + ' m range bin' + ' id: ' + string(vital_bin_idx))
    xlabel('time')
    ylabel('phase magnitude')
    
    %% Spectrum Analysis
    % Respiration Belt
    % belt_len = length(chest_meas_seg);
    % belt_NFFT = 2^nextpow2(belt_len);
    % chest_meas_seg = chest_meas_seg - mean(chest_meas_seg); 
    % belt_sub = fft(chest_meas_seg,belt_NFFT)/belt_len;    % normalized sub-frequency magnitude
    % belt_sub = 2*abs(belt_sub(1:belt_NFFT/2+1));
    % belt_f = belt_fs/2*linspace(0,1,belt_NFFT/2+1)*60; % sub-frequency
    % 
    % [belt_br_freq_mag,belt_br_freq_loc] = max(belt_sub);
    % belt_est_br = belt_f(belt_br_freq_loc);
    % fprintf('Respiration belt estimated breathing rate is %.2f bpm \n',belt_est_br);
    
    % Breathing Rate Estimation
    % Respiration Belt
    [belt_subfreq_mag,belt_freq] = FFTanalysis(chest_meas_seg,belt_fs);
    [belt_br_freq_mag,belt_br_freq_loc] = max(belt_subfreq_mag);
    belt_est_br = belt_freq(belt_br_freq_loc);
    fprintf('Respiration belt estimated breathing rate is %.2f bpm \n',belt_est_br);
    
    % Radar
    [radar_subfreq_mag,radar_freq] = FFTanalysis(filt_vital_sig,radar_fs);
    [radar_br_freq_mag,radar_br_freq_loc] = max(radar_subfreq_mag);
    radar_est_br = radar_freq(radar_br_freq_loc);
    fprintf('Radar estimated breathing rate is %.2f bpm \n',radar_est_br);
    
    br_error = abs(belt_est_br - radar_est_br);
    fprintf('Breathing rate estimation error is %.1f bpm \n',br_error);
    
    figure
    subplot(2,1,1)
    plot(belt_freq,belt_subfreq_mag)
    xlabel('Frequency (acts/min)');ylabel('Amplitude Spectrum');
    xlim([0 100])
    title('Amplitude Spectrum of Chest Force Measurements');
    
    subplot(2,1,2)
    plot(radar_freq,radar_subfreq_mag)
    xlabel('Frequency (acts/min)');ylabel('Amplitude Spectrum');
    xlim([0 100])
    title('Amplitude Spectrum of Phase');
    
    % Heart Rate Estimation
    % Respiration Belt
    bp_chest_meas_seg = HR_BP_Filter(chest_meas_seg,belt_fs);
    all_belt(:,k)=-bp_chest_meas_seg;
    [bp_belt_subfreq_mag,bp_belt_freq] = FFTanalysis(bp_chest_meas_seg,belt_fs);
    [bp_belt_hr_freq_mag,bp_belt_hr_freq_loc] = max(bp_belt_subfreq_mag);
    belt_est_hr = bp_belt_freq(bp_belt_hr_freq_loc);
    fprintf('Respiration belt estimated heart rate is %.2f bpm \n',belt_est_hr);
    
    % [~,belt_hr_count] = zerocrossrate(bp_chest_meas_seg,TransitionEdge="rising");
    % belt_zc_est_hr = belt_hr_count * 60/duration;
    % fprintf('Respiration belt zero-crossing heart rate is %.2f bpm \n',belt_zc_est_hr);
    
    % Radar
    bp_filt_vital_sig = HR_BP_Filter(vital_cand,radar_fs);
    all_radar(:,k)=bp_filt_vital_sig;
    [bp_radar_subfreq_mag,bp_radar_freq] = FFTanalysis(bp_filt_vital_sig,radar_fs);
    [bp_radar_hr_freq_mag,bp_radar_hr_freq_loc] = max(bp_radar_subfreq_mag);
    radar_est_hr = bp_radar_freq(bp_radar_hr_freq_loc);
    fprintf('Radar estimated heart rate is %.2f bpm \n',radar_est_hr);
    
    % [~,radar_hr_count] = zerocrossrate(bp_filt_vital_sig,TransitionEdge="rising");
    % radar_zc_est_hr = radar_hr_count * 60/duration;
    % fprintf('Radar zero-crossing heart rate is %.2f bpm \n',radar_zc_est_hr);
    
    hr_error = abs(belt_est_hr - radar_est_hr);
    fprintf('Heart rate estimation error is %.1f bpm \n',hr_error);
    
    % zc_hr_error = abs(belt_zc_est_hr - radar_zc_est_hr);
    % fprintf('Zero-crossing heart rate estimation error is %.1f bpm \n',zc_hr_error);
    
    figure
    subplot(2,1,1)
    plot(belt_seg_datetime_ts,bp_chest_meas_seg)
    title('Bandpass Respiration Belt Force Measurement')
    xlabel('time')
    ylabel('force (N)') 
    subplot(2,1,2)
    plot(vital_datetime_ts,bp_filt_vital_sig)
    title('Bandpass Radar Extracted Vital Signal')
    xlabel('time')
    ylabel('phase magnitude')
    
    figure
    subplot(2,1,1)
    plot(bp_belt_freq,bp_belt_subfreq_mag)
    xlabel('Frequency (acts/min)');ylabel('Amplitude Spectrum');
    xlim([0 100])
    title('Amplitude Spectrum of Bandpass Chest Force Measurements');
    
    subplot(2,1,2)
    plot(bp_radar_freq,bp_radar_subfreq_mag)
    xlabel('Frequency (acts/min)');ylabel('Amplitude Spectrum');
    xlim([0 100])
    title('Amplitude Spectrum of Bandpass Phase');
    
    %% Data correlation measurement
    % Resample the radar vital signal to respiration belt sampling rate
    res_filt_vital_sig = resample(filt_vital_sig,belt_fs,radar_fs);
    res_bp_filt_vital_sig = resample(bp_filt_vital_sig,belt_fs,radar_fs);
    
    % Correlation Coefficient of filtered radar vital signal and respiration belt signal
    R = corrcoef(chest_meas_seg,res_filt_vital_sig);
    fprintf('Correlation coefficient of breathing signals is %.2f  \n',R(1,2));
    
    bp_R = corrcoef(bp_chest_meas_seg,res_bp_filt_vital_sig);
    fprintf('Correlation coefficient of heart signals is %.2f  \n',bp_R(1,2));
end

