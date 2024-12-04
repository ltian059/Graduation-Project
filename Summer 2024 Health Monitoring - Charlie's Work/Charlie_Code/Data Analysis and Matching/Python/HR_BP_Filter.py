import numpy as np
from scipy.signal import butter, filtfilt

def Baseline_Removal(sig, fs):
    order = 8   # order of filter
    fcutlow = 0.83   # low cut frequency in Hz
    fcuthigh = 1.7   # high cut frequency in Hz
    nyquist = 0.5 * fs
    low = fcutlow / nyquist
    high = fcuthigh / nyquist
    b, a = butter(order, [low, high], btype='band')
    filt_sig = filtfilt(b, a, sig)
    return filt_sig
