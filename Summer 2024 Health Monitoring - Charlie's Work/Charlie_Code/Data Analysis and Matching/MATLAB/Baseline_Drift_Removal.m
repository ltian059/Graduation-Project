function filt_sig = Baseline_Drift_Removal(sig,fs)
% High-pass filter
order=1;   %order of filter
fcutlow = 5/60;   %low cut frequency in Hz
fcuthigh = 0.5;   %high cut frequency in Hz
filt_sig=bandpass(sig,[fcutlow,fcuthigh],fs); 
end