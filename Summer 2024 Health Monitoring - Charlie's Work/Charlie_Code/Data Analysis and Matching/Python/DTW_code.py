import os
import numpy as np
import pandas as pd
from datetime import datetime, timedelta
import matplotlib.pyplot as plt
from scipy.signal import resample
from scipy.signal import butter
from scipy.interpolate import interp1d
from scipy.signal import filtfilt
from fastdtw import fastdtw

def read_csv_file(file_path):
    return pd.read_csv(file_path).values

def Array_Normalization(Array):
    normA = Array - np.min(Array)
    normA = normA / np.max(normA)
    return normA

def Baseline_Drift_Removal(sig, fs):
    order = 8
    fcutlow = 5 / 60
    fcuthigh = 0.5
    nyquist = 0.5 * fs
    low = fcutlow / nyquist
    high = fcuthigh / nyquist
    b, a = butter(order, [low, high], btype='band')
    filt_sig = filtfilt(b, a, sig)
    return filt_sig

def FFTanalysis(y, fs):
    len_y = len(y)
    NFFT = 2 ** np.ceil(np.log2(len_y)).astype(int)
    y = y - np.mean(y)
    sub = fft(y, NFFT) / len_y
    sub = 2 * np.abs(sub[:NFFT // 2 + 1])
    f = (fs / 2) * np.linspace(0, 1, NFFT // 2 + 1) * 60
    return sub, f

def main():
    folders = [r"C:\Users\chafi\Desktop\Radar_Project\Lab_Radar_Belt\Normal_Dataset\Seating\dataset_3"]
    UTC_offset = -5
    ETC_offset = -4

    for folder in folders:
        file_list = os.listdir(folder)

        # Read Respiration Belt Data
        for file_name in file_list:
            if "belt" in file_name or "bb" in file_name:
                belt_file_name = file_name
                break

        belt_data = read_csv_file(os.path.join(folder, belt_file_name))
        belt_fs = 10

        belt_posix_timestamp = np.linspace(belt_data[0, 0], belt_data[-1, 0], len(belt_data))
        belt_datetime_timestamp = [datetime.utcfromtimestamp(ts) for ts in belt_posix_timestamp]
        belt_local_datetime_timestamp = [ts + timedelta(hours=ETC_offset) for ts in belt_datetime_timestamp]

        chest_meas = np.round(belt_data[:, 1], 2)

        # Read Radar Data
        for file_name in file_list:
            if "radar" in file_name or "rd" in file_name:
                radar_file_name = file_name
                break

        radar_data = read_csv_file(os.path.join(folder, radar_file_name))
        radar_fs = 17
        radar_resolution = 9.9 / 188
        approx_range = 1.5

        rows, columns = radar_data.shape
        range_bin_dist = np.arange(1, columns) * radar_resolution
        radar_posix_timestamp = radar_data[:, 0]
        radar_datetime_timestamp = [datetime.utcfromtimestamp(ts) for ts in radar_posix_timestamp]
        radar_local_datetime_timestamp = [ts + timedelta(hours=ETC_offset) for ts in radar_datetime_timestamp]

        range_bin_index = np.abs(range_bin_dist - approx_range).argmin() + 1
        vital_sig = radar_data[:, range_bin_index]

        filt_vital_sig = Baseline_Drift_Removal(vital_sig, radar_fs)
        belt_filt_sig = Baseline_Drift_Removal(chest_meas, belt_fs)

        duration = (belt_posix_timestamp[-1] - belt_posix_timestamp[0]) / belt_fs
        belt_est_hr, bp_belt_freq = FFTanalysis(belt_filt_sig, belt_fs)
        radar_est_hr, bp_radar_freq = FFTanalysis(filt_vital_sig, radar_fs)

        hr_error = abs(belt_est_hr - radar_est_hr)
        print(f'Heart rate estimation error is {hr_error:.1f} bpm')

        res_filt_vital_sig = resample(filt_vital_sig, int(len(filt_vital_sig) * belt_fs / radar_fs))
        res_bp_filt_vital_sig = resample(filt_vital_sig, int(len(filt_vital_sig) * belt_fs / radar_fs))

        R = np.corrcoef(chest_meas, res_filt_vital_sig)
        print(f'Correlation coefficient of breathing signals is {R[0, 1]:.2f}')

        bp_R = np.corrcoef(belt_filt_sig, res_bp_filt_vital_sig)
        print(f'Correlation coefficient of heart signals is {bp_R[0, 1]:.2f}')

        # Matching
        signal_belt1 = chest_meas[:, 0]
        signal_radar1 = vital_sig[:, 0]
        signal_belt2 = chest_meas[:, 1]
        signal_radar2 = vital_sig[:, 1]

        x1 = np.linspace(0, 1, len(signal_radar1))
        x2 = np.linspace(0, 1, len(signal_belt1))
        signal_belt1_upsampled = interp1d(x2, signal_belt1, kind='linear')(x1)

        x1 = np.linspace(0, 1, len(signal_radar2))
        x2 = np.linspace(0, 1, len(signal_belt2))
        signal_belt2_upsampled = interp1d(x2, signal_belt2, kind='linear')(x1)

        signal_belt1_normalized = 2 * (signal_belt1_upsampled - np.min(signal_belt1_upsampled)) / (np.max(signal_belt1_upsampled) - np.min(signal_belt1_upsampled)) - 1
        signal_belt2_normalized = 2 * (signal_belt2_upsampled - np.min(signal_belt2_upsampled)) / (np.max(signal_belt2_upsampled) - np.min(signal_belt2_upsampled)) - 1
        signal_radar1_normalized = 2 * (signal_radar1 - np.min(signal_radar1)) / (np.max(signal_radar1) - np.min(signal_radar1)) - 1
        signal_radar2_normalized = 2 * (signal_radar2 - np.min(signal_radar2)) / (np.max(signal_radar2) - np.min(signal_radar2)) - 1

        ts = np.linspace(0, duration, len(signal_radar2_normalized))

        plt.figure()
        plt.plot(ts, signal_belt1_normalized, 'b', label='Belt')
        plt.plot(ts, signal_radar1_normalized, 'r', label='Radar')
        plt.legend()
        plt.show()

        plt.figure()
        plt.plot(ts, signal_belt2_normalized, 'b', label='Belt')
        plt.plot(ts, signal_radar2_normalized, 'r', label='Radar')
        plt.legend()
        plt.show()

        dist_belt1_radar1, _ = fastdtw(signal_belt1_normalized, signal_radar1_normalized)
        dist_belt1_radar2, _ = fastdtw(signal_belt1_normalized, signal_radar2_normalized)
        dist_belt2_radar1, _ = fastdtw(signal_belt2_normalized, signal_radar1_normalized)
        dist_belt2_radar2, _ = fastdtw(signal_belt2_normalized, signal_radar2_normalized)

        distances = [dist_belt1_radar1, dist_belt1_radar2, dist_belt2_radar1, dist_belt2_radar2]
        names = ['B1R1', 'B1R2', 'B2R1', 'B2R2']

        print('DTW Distances:')
        for name, dist in zip(names, distances):
            print(f'{name}: {dist}')

        min_dist = min(distances)
        min_idx = distances.index(min_dist)
        print(f'Best match: {names[min_idx]}')
        print(f'Minimum DTW Distance: {min_dist}')

if __name__ == "__main__":
    main()
