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

% PPG beat data
ppg_data.beat.t = 0:0.01:1;
ppg_data.beat.v = [1077,1095.27676998271,1150.39696200268,1253.64011384634,1410.01430649103,1614.23738042021,1852.88862847947,2107.19963850395,2354.10827203910,2571.83504395768,2747.58603743220,2878.78047565119,2967.12445239160,3018.75510162723,3042.94721680823,3047.45001341082,3037.62026345592,3018.14128598677,2991.80738548651,2959.68011205818,2924.12507822977,2885.14270668177,2843.86782834153,2802.08903767062,2759.59973773619,2716.75011175682,2673.89981522322,2630.12661808970,2584.21488466353,2533.75439619717,2480.71246051141,2423.10076799285,2360.92007271860,2294.87110683952,2226.11520653275,2155.41275815825,2085.84032425344,2019.82560572195,1959.08788519998,1905.61966740180,1860.15018328118,1823.59858526554,1799.16523439130,1785.68124422590,1781.40496155451,1785.65000894081,1795.60758813888,1810.23123770638,1825.88000834451,1843.33369762174,1863.68739383102,1877.70370775466,1882.41001847768,1880.67124988824,1874.06744888836,1862.89381761287,1847.14991953269,1829.89768909817,1810.34993145378,1788.72101296379,1765.94996721702,1742.03613261809,1717.39751028193,1692.75877484727,1668.68005245276,1644.48098438338,1619.84239547012,1595.97728854980,1572.41003606020,1548.84233116767,1525.27517210550,1501.70741230815,1478.27021279132,1455.77367020325,1433.54980777827,1412.12496274662,1390.69993145582,1369.27500149014,1348.40755237670,1328.05378822197,1308.39978542052,1289.88870123678,1272.51984025750,1256.29379973178,1241.20988734577,1229.73332273703,1217.97235166145,1206.26252309710,1195.54992698555,1185.27003397509,1176.98743219884,1169.12989658769,1160.98994575908,1153.99245954403,1146.99245931931,1138.20624497094,1127.13495738213,1112.99225070036,1097.13740724184,1083.85480956071,1080];
ppg_data.sig.v=repmat(ppg_data.beat.v,1,100);   % repeat the original ppg_data 100 times and concatenate them together
N=length(ppg_data.sig.v);
ppg_data.sig.t=1/fs:1/fs:N/fs;

T=1/fs;

figure 
plot(ppg_data.sig.t,ppg_data.sig.v);
    title('Unmodulated PPG (segment)')
    xlabel('Time (s)')
    ylabel('Amplitude (V)')
        xlim([0,10])

% Simulating breathing modulation on the ECG signal
% PPG BM baseline modulation
ppg_data.sig.v_bm=ppg_data.sig.v+bm*sin(2*pi*ppg_data.sig.t*br_rate);
% figure
% plot(ppg_data.sig.t,ppg_data.sig.v_bm)
% title('Simulated PPG waveform with baseline change')
%     xlabel('Time (s)')
%     ylabel('Amplitude (V)')
%     xlim([0,10])

% PPG AM amplitude modulation
ppg_data.sig.v_am=ppg_data.sig.v.*(1+am*cos(2*pi*ppg_data.sig.t*br_rate));
% figure
% plot(ppg_data.sig.t,ppg_data.sig.v_am)
% title('Simulated PPG waveform with amplitude modulation')
%     xlabel('Time (s)')
%     ylabel('Amplitude (V)')
%     xlim([0,10])

% PPG FM frequency modulation
mod_time = ppg_data.sig.t + fm*sin(2*pi*br_rate*ppg_data.sig.t);
ppg_data.sig.v_fm = interp1(mod_time, ppg_data.sig.v, ppg_data.sig.t);
% figure
% plot(ppg_data.sig.t,ppg_data.sig.v_fm)
% title('Simulated PPG waveform with frequency modulation')
%     xlabel('Time (s)')
%     ylabel('Amplitude (V)')
%     xlim([0,10])

% PPG all modulations 
ppg_data.sig.v_all=interp1(mod_time, (ppg_data.sig.v_bm+ppg_data.sig.v_am)/2, ppg_data.sig.t);
figure
plot(ppg_data.sig.t,ppg_data.sig.v_all)
title('Simulated PPG waveform with all modulations (full)')
    xlabel('Time (s)')
    ylabel('Amplitude (V)')
    xlim([ppg_data.sig.t(1),ppg_data.sig.t(end)])

%% HPF
s = ppg_data.sig.v_all;

% Eliminate very low frequencies，using a high-pass filter with −3 dB cutoff frequency of 4 breaths per minute (bpm)
Fstop = 0.02;  % in Hz
Fpass = 0.157;  % in Hz     (0.157 and 0.02 provide a - 3dB cutoff of 0.0665 Hz, 4bpm)
Dstop = 0.01;  % Stopband attenuation (0.1% or -40 dB)
Dpass = 0.05;   % Passband ripple (1%)

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
title('PPG waveform after initial highpass filter')
    xlabel('Time (s)')
    ylabel('Amplitude (V)')
    xlim([s_filt.t(1),s_filt.t(end)])

s = s_filt.v; 

%% EHF
% Filter signal to remove very high frequencies (VHFs)
ppg.Fpass = 33.12;  % in Hz
ppg.Fstop = 38.5;  % in Hz   (33.12 and 38.5 provide a -3 dB cutoff of 35 Hz)
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
title('PPG waveform after remove VHFs')
    xlabel('Time (s)')
    ylabel('Amplitude (V)')
    xlim([s_filt.t(1),s_filt.t(end)])

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
    % xlim([0 95])
    xlim([ppg_data.sig.t(1),ppg_data.sig.t(end)])