function s_filt = elim_vlfs(data)
%% Filter pre-processed signal to remove frequencies below resp

fs = data.fs;
s = data;

%% Eliminate nans
s.v(isnan(s.v)) = mean(s.v(~isnan(s.v)));

%% Make filter
elim_vlf.Fpass = 0.157;  % in Hz
elim_vlf.Fstop = 0.02;   % in Hz     (0.157 and 0.02 provide a - 3dB cutoff of 0.0665 Hz)
elim_vlf.Dpass = 0.05;
elim_vlf.Dstop = 0.01;

flag  = 'scale';
[N,Wn,BETA,TYPE] = kaiserord([elim_vlf.Fstop elim_vlf.Fpass]/(fs/2), [0 1], [elim_vlf.Dstop elim_vlf.Dpass]);
b  = fir1(N, Wn, TYPE, kaiser(N+1, BETA), flag);
AMfilter = dfilt.dffir(b);

%% Check frequency response
% % Gives a -3 dB cutoff at ? Hz, using:
% freqz(AMfilter.Numerator)
% norm_cutoff_freq = 0.0266;    % insert freq here from plot
% cutoff_freq = norm_cutoff_freq*(fs/2);

s_filt = filtfilt(AMfilter.numerator, 1, s.v);
s_filt = s.v-s_filt;
end