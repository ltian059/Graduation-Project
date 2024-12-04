function s_filt = lp_filter_signal_to_remove_freqs_above_resp(s, Fs)
%% Filter pre-processed signal to remove freqs above resp

flag  = 'scale';

Fpass = 0.8899;  % in Hz     (1.2 and 0.8899 provide a -3dB cutoff of 1 Hz)
Fstop = 1.2;  % in Hz
Dpass = 0.05;
Dstop = 0.01;

% create filter
[N,Wn,BETA,TYPE] = kaiserord([Fpass Fstop]/(Fs/2), [1 0], [Dstop Dpass]);
b  = fir1(N, Wn, TYPE, kaiser(N+1, BETA), flag);
AMfilter = dfilt.dffir(b);

%% Check frequency response
% Gives a -3 dB cutoff at ? Hz, using:
% freqz(AMfilter.Numerator)
% norm_cutoff_freq = 0.3998;    % insert freq here from plot
% cutoff_freq = norm_cutoff_freq*(Fs/2);

% Prepare signal
s_dt=detrend(s);
s_filt = filtfilt(AMfilter.numerator, 1, s_dt);
end