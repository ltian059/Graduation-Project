function filt_sig = Baseline_Removal(sig,fs)
% High-pass filter
order=8;   %order of filter
fcutlow = 0.83;   %low cut frequency in Hz
fcuthigh = 1.7;   %high cut frequency in Hz
[b,a]=butter(order,[fcutlow,fcuthigh]/(fs/2),'bandpass');   % fs/2 term in the cutoff freq is the Nyquist Sampling rate 
filt_sig = filter(b,a,sig);  %filtered signal
end