import csv
import pandas as pd
from parse import parse_wall_clock_start
from datetime import datetime, timedelta


def parse_enhanced_body(body_data, start_time, sampling_interval_ms):
    packet_size = 20
    sample_index = 1  # global sample index
    samples = []
    i = 0  # pointer
    file_size = 0  # record file_size that has been read (offset)

    current_timestamp = None

    while i < len(body_data):
        packet = body_data[i:i + packet_size]

        if len(packet) < packet_size:
            break

        counter_ppg = packet[0]
        notification_byte_ppg = packet[1]
        if notification_byte_ppg != 0x00:
            # If the packet is not ppg packet, continue
            i += packet_size
            continue

        # PPG data (6 data, 3-byte each)
        # Each sample has 3 PPG measurements
        ppg_data = []
        for j in range(2, 20, 3):
            if j + 2 < 20:
                # Combine 3 bytes into a 24-bit integer
                ppg_raw = (packet[j] << 16) | (packet[j + 1] << 8) | packet[j + 2]
                # Mask off the upper 4 bits (tag bits)
                adc_counts = ppg_raw & 0xFFFFF  # Keep lower 20 bits
                # Convert to signed integer (20-bit two's complement)
                if adc_counts & 0x80000:  # If sign bit is set
                    adc_counts -= 0x100000  # Subtract 2^20 to get negative value
                ppg_data.append(adc_counts)

        sample1_ppg = ppg_data[:3]  # First 3 measurements
        sample2_ppg = ppg_data[3:]  # Next 3 measurements

        i += packet_size  # move to the next packet
        if i >= len(body_data):
            break  # insufficient data, stop parse

        # Parse Accel data packet
        packet_accel = body_data[i:i + packet_size]
        if len(packet_accel) < packet_size:
            break  # insufficient data
        counter_accel = packet_accel[0]
        notification_byte_accel = packet_accel[1]
        if notification_byte_accel != 0x01:
            # If the packet is not accelerometer data, skip
            i += packet_size
            continue

        # Extract accel data
        accel_data = []
        for j in range(2, 14, 2):
            if j + 1 < 20:
                accel_raw = (packet_accel[j] << 8) | packet_accel[j + 1]
                if accel_raw & 0x8000:
                    # if the accel data is negative
                    accel_raw -= 0x10000
                accel_data.append(accel_raw)
        # Split into 2 samples
        sample1_accel = accel_data[:3]
        sample2_accel = accel_data[3:]
        i += packet_size

        # Combine sample ppg and accel data

        if sample_index == 1:
            current_timestamp = start_time + timedelta(milliseconds=counter_accel)
        else:
            current_timestamp += timedelta(milliseconds=sampling_interval_ms)
        # Sample 1

        samples.append({
            'Timestamp[Day.Month.Year Hour:Minute:Second:Milisecond]': current_timestamp.strftime(
                '%d.%m.%Y %H:%M:%S:%f')[:-3],
            'Sample_Index': sample_index,
            'Counter_PPG': counter_ppg,
            'Counter_Accel': counter_accel,
            # 'PPG_Data': sample1_ppg,
            'LED1_PPG1': sample1_ppg[0],
            'LED2_PPG1': sample1_ppg[1],
            'LED3_PPG1': sample1_ppg[2],
            # 'Accel_Data': sample1_accel
            'ACC_X[mg]': sample1_accel[0],
            'ACC_Y[mg]': sample1_accel[1],
            'ACC_Z[mg]': sample1_accel[2]
        })
        sample_index += 1
        current_timestamp += timedelta(milliseconds=sampling_interval_ms)

        # Sample 2
        samples.append({
            'Timestamp[Day.Month.Year Hour:Minute:Second:Milisecond]': current_timestamp.strftime(
                '%d.%m.%Y %H:%M:%S:%f')[:-3],
            'Sample_Index': sample_index,
            'Counter_PPG': counter_ppg,
            'Counter_Accel': counter_accel,
            # 'PPG_Data': sample2_ppg,
            'LED1_PPG1': sample2_ppg[0],
            'LED2_PPG1': sample2_ppg[1],
            'LED3_PPG1': sample2_ppg[2],
            # 'Accel_Data': sample2_accel
            'ACC_X[mg]': sample2_accel[0],
            'ACC_Y[mg]': sample2_accel[1],
            'ACC_Z[mg]': sample2_accel[2]
        })

        sample_index += 1

    return samples

# Load the binary file
FILE_PATH = r"D:\OneDrive\Desktop\Graduate Project\log\20241012\MAX86176_1012_120657.bin"
ACTUAL_FRAME_RATE = 300.62  # Hz
HEADER_SIZE = 18 * 7  # The header is 18 * 7 = 126 bytes
OUTPUT_CSV_FILE_PATH = './parsed_data.csv'



# Reading the binary file
with open(FILE_PATH, 'rb') as f:
    file_content = f.read()

# file_content = file_content.replace('\n', '').replace(' ','')
# byte_data = bytes.fromhex(file_content)

header = file_content[:HEADER_SIZE]

start_time = parse_wall_clock_start(header)
print(f"Start Time: {start_time}")

body = file_content[HEADER_SIZE:]

sampling_interval_ms = (1 / ACTUAL_FRAME_RATE) * 1000  # ms
# Parsing the body with the new format for PPG and Accelerometer data
samples = parse_enhanced_body(body, start_time, sampling_interval_ms)

# Converting to a DataFrame for visualization
df_samples = pd.DataFrame(samples)

# Calculate elapsed time and timestamps

# Exporting the parsed PPG and Accelerometer data to a CSV file
df_samples.to_csv(OUTPUT_CSV_FILE_PATH, index=False, quoting=csv.QUOTE_NONNUMERIC)
