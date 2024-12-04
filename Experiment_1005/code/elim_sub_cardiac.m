function s_filt = elim_sub_cardiac(old_data)    % elim_sub_cardiac(old_data, up) -> elim_sub_cardiac(old_data)
%% Filter pre-processed signal to remove frequencies below cardiac freqs

s = old_data;

%% Eliminate nans
s.v(isnan(s.v)) = mean(s.v(~isnan(s.v)));

%% Downsample
filt_resample_fs = 25; % up.paramSet.filt_resample_fs -> filt_resample_fs
d_s = downsample_data(s, filt_resample_fs);

%% Make filter
% Filter characteristics: Eliminate LFs (below cardiac freqs): For 30bpm cutoff
elim_sub_cardiac.Fpass = 0.63;  % in Hz; up.paramSet.elim_sub_cardiac.Fpass -> elim_sub_cardiac.Fpass
elim_sub_cardiac.Fstop = 0.43;  % in Hz     (0.63 and 0.43 provide a - 3dB cutoff of 0.5 Hz); up.paramSet.elim_sub_cardiac.Fstop -> elim_sub_cardiac.Fstop
elim_sub_cardiac.Dpass = 0.05;  % up.paramSet.elim_sub_cardiac.Dpass -> elim_sub_cardiac.Dpass
elim_sub_cardiac.Dstop = 0.01;  % up.paramSet.elim_sub_cardiac.Dstop -> elim_sub_cardiac.Dstop

flag  = 'scale';        % Sampling Flag
[N,Wn,BETA,TYPE] = kaiserord([elim_sub_cardiac.Fstop elim_sub_cardiac.Fpass]/(d_s.fs/2), [1 0], [elim_sub_cardiac.Dstop elim_sub_cardiac.Dpass]);
b  = fir1(N, Wn, TYPE, kaiser(N+1, BETA), flag);   % Calculate the coefficients using the FIR1 function.
AMfilter = dfilt.dffir(b);

%% Check frequency response
% Gives a -3 dB cutoff at ? Hz, using:
% freqz(AMfilter.Numerator)
% norm_cutoff_freq = 0.04;    % insert freq here from plot
% cutoff_freq = norm_cutoff_freq*(d_s.fs/2);

temp_filt = filtfilt(AMfilter.numerator, 1, d_s.v);

%% Resample
s_filt_rs.v = interp1(d_s.t, temp_filt, s.t);
s_filt.v = s.v(:)-s_filt_rs.v(:);
s_filt.t = s.t;
s_filt.fs = s.fs;
end