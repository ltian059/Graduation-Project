% This code was developed by Miodrag Bolic for the book PERVASIVE CARDIAC AND RESPIRATORY MONITORING DEVICES: 
% https://github.com/Health-Devices/CARDIAC-RESPIRATORY-MONITORING 

clc;
clear all;
close all;

%% Generating Signal
fs=100;

% breathing modulation parameter
br_rate=0.15; %breathing rate in Hz
br_rate_bpm=br_rate*60;
fm=0.05; % frequency modulation
bm=0.1; % baseline modulation
am=0.1; % amplitude modulation

% ECG beat data
% ecg_data.beat.t = 0:0.01:1;
% ecg_data.beat.v = [-0.120000000000000,-0.120000000000000,-0.125000000000000,-0.122500113257034,-0.125000000000000,-0.120000000000000,-0.125000000000000,-0.117500065569862,-0.125000000000000,-0.117499958278698,-0.120000000000000,-0.120000000000000,-0.124999856955537,-0.122500005960186,-0.105000131124091,-0.115000000000000,-0.110000000000000,-0.122499946358326,-0.125000000000000,-0.109999558946239,-0.100000357611158,-0.0899996065808297,-0.0750000000000000,-0.0775001728453928,-0.0850000000000000,-0.0975001490224131,-0.100000000000000,-0.0925001251639052,-0.0949997377518178,-0.0824998986647591,-0.0800000000000000,-0.0800000000000000,-0.100000429133389,-0.0299993562231754,0.464997210632973,0.997500745023246,0.954992990821313,0.134999821173104,-0.194999845035165,-0.165000035761116,-0.119999880796281,-0.117499958273724,-0.110000202646322,-0.107499934437955,-0.109999928477768,-0.100000000000000,-0.100000000000000,-0.0900000000000000,-0.0949999761592562,-0.0824998390749790,-0.0800000000000000,-0.0675001609250210,-0.0649999761592562,-0.0574998867564668,-0.0500000000000000,-0.0400000000000000,-0.0300000000000000,-0.0124999344379545,0.00500020264632248,0.0275000417262755,0.0649997615925615,0.100000035761115,0.145000309929670,0.189999988078207,0.224999666229586,0.252499970199070,0.270000000000000,0.275000000000000,0.250000214566695,0.197500232447252,0.114999761592563,0.0325003040057223,-0.0299992132554528,-0.0849997496721898,-0.105000023840744,-0.130000000000000,-0.130000000000000,-0.140000000000000,-0.130000000000000,-0.127500196709585,-0.120000000000000,-0.120000000000000,-0.110000000000000,-0.110000000000000,-0.105000000000000,-0.105000000000000,-0.100000000000000,-0.100000000000000,-0.100000000000000,-0.100000000000000,-0.104999821194421,-0.110000000000000,-0.110000000000000,-0.105000000000000,-0.114999773512934,-0.120000000000000,-0.115000000000000,-0.122500113257034,-0.115000000000000,-0.120000000000000,-0.110000000000000];
% ecg_data.sig.v=repmat(ecg_data.beat.v,1,100);   % repeat the original ecg_data 100 times and concatenate them together
% ecg_data.sig.t=1/fs:1/fs:N/fs;

% PPG beat data
ppg_data.beat.t = 0:0.01:1;
ppg_data.beat.v = [1077,1095.27676998271,1150.39696200268,1253.64011384634,1410.01430649103,1614.23738042021,1852.88862847947,2107.19963850395,2354.10827203910,2571.83504395768,2747.58603743220,2878.78047565119,2967.12445239160,3018.75510162723,3042.94721680823,3047.45001341082,3037.62026345592,3018.14128598677,2991.80738548651,2959.68011205818,2924.12507822977,2885.14270668177,2843.86782834153,2802.08903767062,2759.59973773619,2716.75011175682,2673.89981522322,2630.12661808970,2584.21488466353,2533.75439619717,2480.71246051141,2423.10076799285,2360.92007271860,2294.87110683952,2226.11520653275,2155.41275815825,2085.84032425344,2019.82560572195,1959.08788519998,1905.61966740180,1860.15018328118,1823.59858526554,1799.16523439130,1785.68124422590,1781.40496155451,1785.65000894081,1795.60758813888,1810.23123770638,1825.88000834451,1843.33369762174,1863.68739383102,1877.70370775466,1882.41001847768,1880.67124988824,1874.06744888836,1862.89381761287,1847.14991953269,1829.89768909817,1810.34993145378,1788.72101296379,1765.94996721702,1742.03613261809,1717.39751028193,1692.75877484727,1668.68005245276,1644.48098438338,1619.84239547012,1595.97728854980,1572.41003606020,1548.84233116767,1525.27517210550,1501.70741230815,1478.27021279132,1455.77367020325,1433.54980777827,1412.12496274662,1390.69993145582,1369.27500149014,1348.40755237670,1328.05378822197,1308.39978542052,1289.88870123678,1272.51984025750,1256.29379973178,1241.20988734577,1229.73332273703,1217.97235166145,1206.26252309710,1195.54992698555,1185.27003397509,1176.98743219884,1169.12989658769,1160.98994575908,1153.99245954403,1146.99245931931,1138.20624497094,1127.13495738213,1112.99225070036,1097.13740724184,1083.85480956071,1080];
ppg_data.sig.v=repmat(ppg_data.beat.v,1,100);   % repeat the original ppg_data 100 times and concatenate them together
N=length(ppg_data.sig.v);
ppg_data.sig.t=1/fs:1/fs:N/fs;

T=1/fs;

figure 
plot(ppg_data.sig.t,ppg_data.sig.v);
    title('Unmodulated PPG')
    xlabel('Time (s)')
    ylabel('Amplitude (V)')
        xlim([0,10])

% ecg_data.sig.v=ecg_data.sig.v+0.05*randn(1,length(ecg_data.sig.v)); % add AWGN white noise to ecg_data
%     figure
%     plot(ecg_data.sig.t,ecg_data.sig.v);
%     title('Unmodulated ECG')
%     xlabel('Time (s)')
%     ylabel('Amplitude (V)')
%         xlim([0,10])

% Simulating breathing modulation on the ECG signal
% PPG BM baseline modulation
ppg_data.sig.v_bm=ppg_data.sig.v+bm*sin(2*pi*ppg_data.sig.t*br_rate);
figure
plot(ppg_data.sig.t,ppg_data.sig.v_bm)
title('Simulated PPG waveform with baseline change')
    xlabel('Time (s)')
    ylabel('Amplitude (V)')
    xlim([0,10])

% PPG AM amplitude modulation
ppg_data.sig.v_am=ppg_data.sig.v.*(1+am*cos(2*pi*ppg_data.sig.t*br_rate));
figure
plot(ppg_data.sig.t,ppg_data.sig.v_am)
title('Simulated PPG waveform with amplitude modulation')
    xlabel('Time (s)')
    ylabel('Amplitude (V)')
    xlim([0,10])

% PPG FM frequency modulation
mod_time = ppg_data.sig.t + fm*sin(2*pi*br_rate*ppg_data.sig.t);
ppg_data.sig.v_fm = interp1(mod_time, ppg_data.sig.v, ppg_data.sig.t);
figure
plot(ppg_data.sig.t,ppg_data.sig.v_fm)
title('Simulated PPG waveform with frequency modulation')
    xlabel('Time (s)')
    ylabel('Amplitude (V)')
    xlim([0,10])

% PPG all modulations 
ppg_data.sig.v_all=interp1(mod_time, (ppg_data.sig.v_bm+ppg_data.sig.v_am)/2, ppg_data.sig.t);
figure
plot(ppg_data.sig.t,ppg_data.sig.v_all)
title('Simulated PPG waveform with all modulations')
    xlabel('Time (s)')
    ylabel('Amplitude (V)')
    xlim([0,10])

%% EHF
% The nomination of Fpass and Fstop is reverse, but the actual function is
% correct
ppg.Fpass = 38.5;  % in Hz
ppg.Fstop = 33.12;  % in Hz   (33.12 and 38.5 provide a -3 dB cutoff of 35 Hz)
ppg.Dpass = 0.05;
ppg.Dstop = 0.01;

% Now filt_characteristics will directly reference the 'ppg' structure
filt_characteristics = ppg;

s = ppg_data.sig.v_all;
s_filt.fs = fs;
s_filt.v = elim_vhfs(s, s_filt.fs, filt_characteristics);
s_filt.t = (1/s_filt.fs)*(1:length(s_filt.v));

s = s_filt; 

%% PDt
% High-pass filter data for peak detection
s_filt = elim_sub_cardiac(s);
[peaks,onsets,artifs] = adaptPulseSegment(s_filt.v,fs); % IMS: IMS peak detector

%% FPt
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
    %                     % to check:
    %                     old_peaks  = rel_data.p; old_onsets = rel_data.tr;
    %                     plot(diff(old_peaks.t), 'b'), hold on, plot(diff(peaks.t), 'r')
    %                     close all
    %                     plot(diff(old_onsets.t)), hold on, plot(diff(onsets.t))
    %                     close all
end

feat_data = calc_am(peaks, onsets, fs);
% feat_data = calc_fm(peaks, fs);
% feat_data = calc_bw(peaks, onsets, fs);

feat_data.timings = rel_data.timings;

%% RS - resampling
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

%% ELF
% INTERFACE
old_data = resampled_data;

data.hpfilt.t = old_data.t;
try
    data.hpfilt.v = elim_vlfs(old_data, up);
catch
    % if there aren't enough points to use the filter, simply carry forward the previous data
    data.hpfilt.v = old_data.v;
end
data.hpfilt.fs = old_data.fs;

%% Visualization
figure
plot(data.hpfilt.t,data.hpfilt.v)
title('Extracting Respiratory Signal')
    xlabel('Time (s)')
    ylabel('Amplitude (V)')
    xlim([0 95])