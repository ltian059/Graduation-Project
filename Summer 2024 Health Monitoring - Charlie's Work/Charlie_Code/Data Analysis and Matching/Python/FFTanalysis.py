import numpy as np
from scipy.fft import fft

def FFTanalysis(y, fs):
    len_y = len(y)
    NFFT = 2 ** np.ceil(np.log2(len_y)).astype(int)
    y = y - np.mean(y)
    sub = fft(y, NFFT) / len_y
    sub = 2 * np.abs(sub[:NFFT // 2 + 1])
    f = (fs / 2) * np.linspace(0, 1, NFFT // 2 + 1) * 60
    return sub, f
