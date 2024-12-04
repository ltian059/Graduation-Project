import os
import numpy as np
import pandas as pd
from datetime import datetime, timedelta
import matplotlib.pyplot as plt
from scipy.signal import butter, filtfilt, resample
from scipy.fftpack import fft

# Define the custom functions (Array_Normalization, Baseline_Drift_Removal, FFTanalysis, HR_BP_Filter)

def Array_Normalization(Array):
    normA = Array - np.min(Array)
    normA = normA / np.max(normA)
    return normA

def Baseline_Drift_Removal(sig, fs):
    order = 1
    fcutlow = 5 / 60
    fcuthigh = 0.5
    nyquist = 0.5 * fs
    low = fcutlow / nyquist
    high = fcuthigh / nyquist
    b, a = butter(order, [low, high], btype='band')
    filt_sig = filtfilt(b, a, sig)
    return filt_sig

def HR_BP_Filter(sig, fs):
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

if __name__ == "__main__" :
    folders = [r"C:\Users\chafi\Desktop\Radar_Project\Charlie_Code\data\Exp 2"]
    #folders = [r"C:\Users\chafi\Desktop\Radar_Project\Lab_Radar_Belt\Normal_Dataset\Seating\dataset_1"]

    for k in range(len(folders)):
        folder = folders[k]

        UTC_offset = -5
        ETC_offset = -4

        # List the .csv files in
        file_list = os.listdir(folder)
        # Read Respiration Belt Data
        belt_file_name = []
        for file_name in file_list:
            if ("belt" in file_name or "bb" in file_name)and("._" not in file_name):
               belt_file_name.append(file_name)
        if not belt_file_name:
            raise FileNotFoundError("No belt data file found.")
        belt_data = pd.read_csv(os.path.join(folder, belt_file_name[0]), header=None)
        belt_data = belt_data.iloc[1:-1]
        belt_data = belt_data.applymap(lambda x: float(x))
        belt_fs = 10  # default respiration belt sampling rate

        belt_posix_timestamp = np.linspace(belt_data.iloc[0, 0], belt_data.iloc[-1, 0], len(belt_data))
        belt_datetime_timestamp = pd.to_datetime(belt_posix_timestamp, unit='s')
        belt_local_datetime_timestamp = belt_datetime_timestamp + pd.to_timedelta(ETC_offset, unit='h')

        chest_meas = belt_data.iloc[:, 1].round(2)  # resolution 0.01 N

        # Read Radar Data
        radar_file_name = None
        for file_name in file_list:
            if ("radar" in file_name or "rd" in file_name)and("._" not in file_name):
                radar_file_name = file_name
                break

        if not radar_file_name:
            raise FileNotFoundError("No radar data file found.")

        # Read the radar data as strings to handle complex numbers
        print("hi",os.path.join(folder, radar_file_name))
        radar_data_str = pd.read_csv(os.path.join(folder, radar_file_name), header=None)

        # Convert the data to complex numbers
        radar_data = radar_data_str.applymap(lambda x: complex(x))
        radar_fs = 17  # radar sampling rate
        radar_resolution = 9.9 / 188  # meter
        approx_range = 1.5  # meters

        rows, columns = radar_data.shape
        range_bin_dist = np.arange(1, columns) * radar_resolution
        radar_posix_timestamp = radar_data.iloc[:, 0].astype(float)
        radar_datetime_timestamp = pd.to_datetime(radar_posix_timestamp, unit='s')

        radar_local_datetime_timestamp = radar_datetime_timestamp + pd.to_timedelta(ETC_offset, unit='h')

        radar_mat = radar_data.iloc[:, 1:].values

        # Confirm the existence of vital signs in Radar Matrix
        diff_radar_mat = np.abs(np.diff(radar_mat, axis=0)).T

        # Remove direct path (0-10 range bin)
        direct_path_num = 10
        # Normalize Each Radar Scan
        for i in range(diff_radar_mat.shape[1]):
            diff_radar_mat[:, i] = Array_Normalization(diff_radar_mat[:, i])
        time = radar_local_datetime_timestamp[:-1]
        dist = range_bin_dist
        plt.figure()
        inst_RT_map = plt.pcolormesh(time, dist, diff_radar_mat, shading='auto')
        plt.ylim([direct_path_num * radar_resolution, dist[-1]])
        plt.xlim([time.iloc[0], time.iloc[-1]])
        plt.title('Range Time Map')
        plt.colorbar(inst_RT_map)
        plt.show(block=False)

        # Data alignment
        radar_start_ts = radar_local_datetime_timestamp.iloc[0]
        time_diffs = np.abs((belt_local_datetime_timestamp - radar_start_ts).total_seconds())
        belt_align_idx = np.argmin(time_diffs)

        # Crop the belt data
        belt_local_datetime_timestamp = belt_local_datetime_timestamp[belt_align_idx:]
        chest_meas = chest_meas[belt_align_idx:]

        # Data segmentation
        duration = 30
        belt_len = duration * belt_fs
        radar_len = duration * radar_fs
        seg_num = min(len(chest_meas) // belt_len, rows // radar_len)

        # Vital signs extraction
        seg_id = 2
        chest_meas_seg = chest_meas[(seg_id - 1) * belt_len: seg_id * belt_len]
        belt_seg_datetime_ts = belt_local_datetime_timestamp[(seg_id - 1) * belt_len: seg_id * belt_len]
        chest_meas_seg = Baseline_Drift_Removal(chest_meas_seg, belt_fs)

        phase_radar_mat = np.unwrap(np.angle(radar_mat), axis=0)
        radar_mat_seg = phase_radar_mat[(seg_id - 1) * radar_len: seg_id * radar_len, :]

        approx_bin_idx = int(approx_range / radar_resolution)

        # Candidate bins
        bin_idx_st = approx_bin_idx - 9
        bin_idx_end = approx_bin_idx + 10
        vital_cand_mat = radar_mat_seg[:, bin_idx_st:bin_idx_end]
        vital_datetime_ts = radar_local_datetime_timestamp[(seg_id - 1) * radar_len: seg_id * radar_len]
        print('Radar vital candidates have been extracted')

        # Vital Candidates Analysis
        per_ratio_set = np.zeros(vital_cand_mat.shape[1])

        filt_vital_cand_mat = np.zeros_like(vital_cand_mat, dtype=complex)

        for i in range(vital_cand_mat.shape[1]):
            cur_bin_idx = bin_idx_st + i
            cur_dist = round(cur_bin_idx * radar_resolution, 2)
            vital_cand = vital_cand_mat[:, i]
            vital_cand = vital_cand - np.mean(vital_cand)  # Analyzed vital candidate is a zero-mean array

            # Baseline removal: highpass filter
            filt_vital_cand = Baseline_Drift_Removal(vital_cand, radar_fs)

            filt_vital_cand_mat[:, i] = filt_vital_cand

            # Frequency Analysis
            subfreq_mag, freq = FFTanalysis(filt_vital_cand, radar_fs)
            argmax_ind = np.argmax(subfreq_mag)
            max_power_freq = freq[argmax_ind]
            max_power = subfreq_mag[argmax_ind]

            remain_avg_power = (np.sum(subfreq_mag) - max_power) / (len(subfreq_mag) - 1)

            # Periodicity index: max_freq / remain_average_freq
            ratio_max_avg = max_power / remain_avg_power
            per_ratio_set[i] = ratio_max_avg

        # Select vital signal range bin
        per_argmax_ind = np.argmax(per_ratio_set)
        vital_bin_idx = bin_idx_st + per_argmax_ind
        vital_bin_dist = round(vital_bin_idx * radar_resolution, 2)
        vital_sig = vital_cand_mat[:, per_argmax_ind]  # original range bin signal

        # Filter the vital signal
        filt_vital_sig = filt_vital_cand_mat[:, per_argmax_ind]

        # Data visualization
        plt.figure()
        plt.subplot(2, 1, 1)
        plt.plot(belt_seg_datetime_ts, chest_meas_seg)
        plt.title('Respiration Belt Force Measurement')
        plt.xlabel('time')
        plt.ylabel('force (N)')

        plt.subplot(2, 1, 2)
        plt.plot(vital_datetime_ts, filt_vital_sig.real)  # Plotting only the real part
        plt.title(f'Radar Extracted Vital Signal in {vital_bin_dist} m range bin id: {vital_bin_idx}')
        plt.xlabel('time')
        plt.ylabel('phase magnitude')
        plt.show(block=False)

        # Spectrum Analysis
        # Respiration Belt
        belt_subfreq_mag, belt_freq = FFTanalysis(chest_meas_seg, belt_fs)
        belt_br_freq_mag = np.max(belt_subfreq_mag)
        belt_br_freq_loc = np.argmax(belt_subfreq_mag)
        belt_est_br = belt_freq[belt_br_freq_loc]
        print(f'Respiration belt estimated breathing rate is {belt_est_br:.2f} bpm')

        # Radar
        radar_subfreq_mag, radar_freq = FFTanalysis(filt_vital_sig, radar_fs)
        radar_br_freq_mag = np.max(radar_subfreq_mag)
        radar_br_freq_loc = np.argmax(radar_subfreq_mag)
        radar_est_br = radar_freq[radar_br_freq_loc]
        print(f'Radar estimated breathing rate is {radar_est_br:.2f} bpm')

        br_error = np.abs(belt_est_br - radar_est_br)
        print(f'Breathing rate estimation error is {br_error:.1f} bpm')

        plt.figure()
        plt.subplot(2, 1, 1)
        plt.plot(belt_freq, belt_subfreq_mag)
        plt.xlabel('Frequency (acts/min)')
        plt.ylabel('Amplitude Spectrum')
        plt.xlim([0, 100])
        plt.title('Amplitude Spectrum of Chest Force Measurements')

        plt.subplot(2, 1, 2)
        plt.plot(radar_freq, radar_subfreq_mag)
        plt.xlabel('Frequency (acts/min)')
        plt.ylabel('Amplitude Spectrum')
        plt.xlim([0, 100])
        plt.title('Amplitude Spectrum of Phase')
        plt.show()
