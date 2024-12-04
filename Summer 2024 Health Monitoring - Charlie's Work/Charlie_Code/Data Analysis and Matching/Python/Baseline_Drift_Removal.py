import numpy as np
from scipy.signal import butter, filtfilt

def bandpass_filter(data, lowcut, highcut, fs, order=8):
    nyquist = 0.5 * fs
    low = lowcut / nyquist
    high = highcut / nyquist
    b, a = butter(order, [low, high], btype='band')
    y = filtfilt(b, a, data)
    return y

def Baseline_Drift_Removal(sig, fs):
    fcutlow = 5 / 60   # low cut frequency in Hz
    fcuthigh = 0.5     # high cut frequency in Hz
    filt_sig = bandpass_filter(sig, fcutlow, fcuthigh, fs)
    return filt_sig
