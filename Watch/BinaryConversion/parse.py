import logging
import time
from datetime import datetime, timedelta
import os
import csv
import pandas as pd

stop_conversion = False


def parse_wall_clock_start(header_data):
    # Extract the second header (H2)
    header2 = header_data[18:36]  # Bytes 18 to 35 (index start from 0)
    # Extract Wall Clock bytes
    wc_bytes = [
        header2[16],  # WC[5]
        header2[17],  # WC[4]
        header2[11],  # WC[3]
        header2[12],  # WC[2]
        header2[13],  # WC[1]
        header2[14],  # WC[0]
    ]
    # Convert the byte list to bytes object
    wc_bytes_combined = bytes(wc_bytes)

    # Convert bytes to integer
    wall_clock_int = int.from_bytes(wc_bytes_combined, byteorder='big')

    # Convert milliseconds to seconds
    wall_clock_seconds = wall_clock_int / 1000.0

    # Convert to datetime object
    start_time = datetime.utcfromtimestamp(wall_clock_seconds) - timedelta(hours=4)
    return start_time


def parse_new_data(data, start_time, sampling_interval_ms, sample_index, current_timestamp):
    packet_size = 20
    samples = []
    i = 0  # pointer
    data_length = len(data)
    global stop_conversion

    while i + packet_size <= data_length:
        packet_ppg = data[i:i + packet_size]

        if len(packet_ppg) < packet_size:
            break  # insufficient data, wait for more data...

        counter = packet_ppg[0]
        notification_byte = packet_ppg[1]
        if notification_byte == 0xFE:
            stop_conversion = True
            i += packet_size
            break

        if notification_byte == 0x00:
            # PPG data (6 data, 3-byte each)
            # Each sample has 3 PPG measurements
            ppg_data = []
            for j in range(2, 20, 3):
                if j + 2 < 20:
                    # Combine 3 bytes into a 24-bit integer
                    ppg_raw = (packet_ppg[j] << 16) | (packet_ppg[j + 1] << 8) | packet_ppg[j + 2]
                    # Mask off the upper 4 bits (tag bits)
                    adc_counts = ppg_raw & 0xFFFFF  # Keep lower 20 bits
                    # Convert to signed integer (20-bit two's complement)
                    if adc_counts & 0x80000:  # If sign bit is set
                        adc_counts -= 0x100000  # Subtract 2^20 to get negative value
                    ppg_data.append(adc_counts)

            sample1_ppg = ppg_data[:3]  # First 3 measurements
            sample2_ppg = ppg_data[3:]  # Next 3 measurements

            i += packet_size  # move to the next packet
            if i > data_length:
                i -= packet_size
                break  # insufficient data, wait for more...

            # Parse Accel data packet
            packet_accel = data[i:i + packet_size]
            if len(packet_accel) < packet_size:
                i -= packet_size
                break  # insufficient data, wait for more...

            counter_accel = packet_accel[0]
            notification_byte_accel = packet_accel[1]

            if notification_byte_accel == 0xFE:
                stop_conversion = True
                i += packet_size
                break

            if notification_byte_accel == 0x01:
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

                # Combine sample ppg and accel data

                if current_timestamp is None:
                    current_timestamp = start_time + timedelta(milliseconds=23)
                else:
                    current_timestamp += timedelta(milliseconds=sampling_interval_ms)
                # Sample 1

                samples.append({
                    'Timestamp[Day.Month.Year Hour:Minute:Second:Milisecond]': current_timestamp.strftime(
                        '%d.%m.%Y %H:%M:%S:%f')[:-3],
                    'Sample_Index': sample_index,
                    'Counter_PPG': counter,
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
                logging.debug(f"sample index:{sample_index}, sample: {samples[0]}")
                sample_index += 1
                current_timestamp += timedelta(milliseconds=sampling_interval_ms)

                # Sample 2
                samples.append({
                    'Timestamp[Day.Month.Year Hour:Minute:Second:Milisecond]': current_timestamp.strftime(
                        '%d.%m.%Y %H:%M:%S:%f')[:-3],
                    'Sample_Index': sample_index,
                    'Counter_PPG': counter,
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
                logging.debug(f"sample index:{sample_index}, sample: {samples[1]}")
                logging.debug(f"sample indices:{sample_index-1, sample_index}, packet_ppg:{packet_ppg}, packet_accel:{packet_accel}")

                sample_index += 1
                i += packet_size  # move to the next packet
            else:
                i += packet_size
        else:
            i += packet_size

    leftover_data = data[i:]
    logging.info(f"Processed up to byte index {i}, leftover data length: {len(leftover_data)}")
    return samples, sample_index, current_timestamp, leftover_data

    # while i + (
    #         packet_size * 2) <= full_packet_length:  # A set is two packets, respectively a PPG packet and an accel packet
    #     packet_ppg = data[i:i + packet_size]
    #
    #     if len(packet_ppg) < packet_size:
    #         break  # insufficient data, wait for more data...
    #
    #     counter_ppg = packet_ppg[0]
    #     notification_byte_ppg = packet_ppg[1]
    #     if notification_byte_ppg == 0xFE:
    #         stop_conversion = True
    #         break
    #
    #     if notification_byte_ppg != 0x00:
    #         # If the packet is not ppg packet, continue
    #         i += packet_size
    #         continue
    #
    #     # PPG data (6 data, 3-byte each)
    #     # Each sample has 3 PPG measurements
    #     ppg_data = []
    #     for j in range(2, 20, 3):
    #         if j + 2 < 20:
    #             # Combine 3 bytes into a 24-bit integer
    #             ppg_raw = (packet_ppg[j] << 16) | (packet_ppg[j + 1] << 8) | packet_ppg[j + 2]
    #             # Mask off the upper 4 bits (tag bits)
    #             adc_counts = ppg_raw & 0xFFFFF  # Keep lower 20 bits
    #             # Convert to signed integer (20-bit two's complement)
    #             if adc_counts & 0x80000:  # If sign bit is set
    #                 adc_counts -= 0x100000  # Subtract 2^20 to get negative value
    #             ppg_data.append(adc_counts)
    #
    #     sample1_ppg = ppg_data[:3]  # First 3 measurements
    #     sample2_ppg = ppg_data[3:]  # Next 3 measurements
    #
    #     i += packet_size  # move to the next packet
    #     if i >= len(data):
    #         break  # insufficient data, wait for more...
    #
    #     # Parse Accel data packet
    #     packet_accel = data[i:i + packet_size]
    #     if len(packet_accel) < packet_size:
    #         break  # insufficient data
    #     counter_accel = packet_accel[0]
    #     notification_byte_accel = packet_accel[1]
    #
    #     if notification_byte_accel != 0x01:
    #         # If the packet is not accelerometer data, skip
    #         i += packet_size
    #         continue
    #
    #     # Extract accel data
    #     accel_data = []
    #     for j in range(2, 14, 2):
    #         if j + 1 < 20:
    #             accel_raw = (packet_accel[j] << 8) | packet_accel[j + 1]
    #             if accel_raw & 0x8000:
    #                 # if the accel data is negative
    #                 accel_raw -= 0x10000
    #             accel_data.append(accel_raw)
    #     # Split into 2 samples
    #     sample1_accel = accel_data[:3]
    #     sample2_accel = accel_data[3:]
    #
    #     # Combine sample ppg and accel data
    #
    #     if current_timestamp is None:
    #         current_timestamp = start_time + timedelta(milliseconds=23)
    #     else:
    #         current_timestamp += timedelta(milliseconds=sampling_interval_ms)
    #     # Sample 1
    #
    #     samples.append({
    #         'Timestamp[Day.Month.Year Hour:Minute:Second:Milisecond]': current_timestamp.strftime(
    #             '%d.%m.%Y %H:%M:%S:%f')[:-3],
    #         'Sample_Index': sample_index,
    #         'Counter_PPG': counter_ppg,
    #         'Counter_Accel': counter_accel,
    #         # 'PPG_Data': sample1_ppg,
    #         'LED1_PPG1': sample1_ppg[0],
    #         'LED2_PPG1': sample1_ppg[1],
    #         'LED3_PPG1': sample1_ppg[2],
    #         # 'Accel_Data': sample1_accel
    #         'ACC_X[mg]': sample1_accel[0],
    #         'ACC_Y[mg]': sample1_accel[1],
    #         'ACC_Z[mg]': sample1_accel[2]
    #     })
    #     sample_index += 1
    #     current_timestamp += timedelta(milliseconds=sampling_interval_ms)
    #
    #     # Sample 2
    #     samples.append({
    #         'Timestamp[Day.Month.Year Hour:Minute:Second:Milisecond]': current_timestamp.strftime(
    #             '%d.%m.%Y %H:%M:%S:%f')[:-3],
    #         'Sample_Index': sample_index,
    #         'Counter_PPG': counter_ppg,
    #         'Counter_Accel': counter_accel,
    #         # 'PPG_Data': sample2_ppg,
    #         'LED1_PPG1': sample2_ppg[0],
    #         'LED2_PPG1': sample2_ppg[1],
    #         'LED3_PPG1': sample2_ppg[2],
    #         # 'Accel_Data': sample2_accel
    #         'ACC_X[mg]': sample2_accel[0],
    #         'ACC_Y[mg]': sample2_accel[1],
    #         'ACC_Z[mg]': sample2_accel[2]
    #     })
    #
    #     sample_index += 1
    #
    #     i += packet_size  # move to the next packet
    #
    # leftover_data = data[i:]
    # print(f"Processed up to byte index {i}, leftover data length: {len(leftover_data)}")
    #
    # return samples, sample_index, current_timestamp, leftover_data


def save_samples_to_csv(output_file, samples):
    df_samples = pd.DataFrame(samples)
    with open(output_file, 'a', newline='', encoding='utf-8') as csvfile:
        df_samples.to_csv(csvfile, index=False, header=False, quoting=csv.QUOTE_NONNUMERIC)


def real_time_conversion(file_path, output_csv_file_path, actual_frame_rate):
    start_time = None
    sampling_interval_ms = (1 / actual_frame_rate) * 1000  #
    sample_index = 1
    file_size = 0  # record file_size that has been read (offset)
    current_timestamp = None
    leftover_data = b''  # Buffer for any leftover data from previous read
    global stop_conversion
    fieldnames = ['Timestamp[Day.Month.Year Hour:Minute:Second:Milisecond]', 'Sample_Index', 'Counter_PPG',
                  'Counter_Accel',
                  'LED1_PPG1', 'LED2_PPG1', 'LED3_PPG1',
                  'ACC_X[mg]', 'ACC_Y[mg]', 'ACC_Z[mg]']

    try:
        with open(file_path, 'rb') as f:
            f.seek(0, os.SEEK_SET)  # read from the beginning of the file
            file_size = f.tell()
            with open(output_csv_file_path, 'w', newline='', encoding='utf-8') as csvfile:
                writer = csv.DictWriter(csvfile, fieldnames)
                writer.writeheader()
            while not stop_conversion:
                try:
                    # Get the current size of the file
                    current_size = os.path.getsize(file_path)
                    if current_size > file_size:
                        # There is new data written
                        f.seek(file_size)
                        new_data = f.read(current_size - file_size)

                        data = leftover_data + new_data
                        logging.info(f"Read {len(new_data)} bytes, processing {len(data)} bytes (including leftover).")

                        file_size = current_size  # update the filesize

                        if start_time is None:
                            header_size = 18 * 7
                            if len(new_data) >= header_size:
                                header = new_data[:header_size]
                                start_time = parse_wall_clock_start(header)
                                logging.info(f"Start time is：{start_time.strftime('%Y-%m-%d %H:%M:%S.%f')[:-3]}")
                                # Process the rest of the data
                                body_data = data[header_size:]
                                samples, sample_index, current_timestamp, leftover_data = parse_new_data(body_data,
                                                                                                         start_time,
                                                                                                         sampling_interval_ms,
                                                                                                         sample_index,
                                                                                                         current_timestamp)
                                # Save the data
                                save_samples_to_csv(output_csv_file_path, samples)
                            else:
                                # Insufficient data, wait for more data
                                leftover_data = data
                                continue
                        else:
                            # start_time is existent
                            samples, sample_index, current_timestamp, leftover_data = parse_new_data(data, start_time,
                                                                                                     sampling_interval_ms,
                                                                                                     sample_index,
                                                                                                     current_timestamp)
                            # Save data
                            save_samples_to_csv(output_csv_file_path, samples)

                    else:
                        # No new data, wait...
                        time.sleep(0.1)


                except KeyboardInterrupt:
                    logging.info("Real time conversion has stopped.")
                    input("Press any key to exit...")
                    exit(1)

                except Exception as e:
                    logging.error(f"Error reading:{e}")
                    time.sleep(0.1)
            if leftover_data:
                logging.info("Processing leftover data after stopping.")
                stop_wc_bytes = [
                    leftover_data[4],
                    leftover_data[5],
                    leftover_data[0],
                    leftover_data[1],
                    leftover_data[2],
                    leftover_data[3]
                ]
                wc_bytes_combined = bytes(stop_wc_bytes)
                # Convert bytes to integer
                wall_clock_int = int.from_bytes(wc_bytes_combined, byteorder='big')
                # Convert milliseconds to seconds
                wall_clock_seconds = wall_clock_int / 1000.0
                # Convert to datetime object
                stop_time = datetime.utcfromtimestamp(wall_clock_seconds) - timedelta(hours=4)
                elapsed_time = stop_time - start_time
                hours = elapsed_time.seconds // 3600
                minutes = (elapsed_time.seconds % 3600) // 60
                seconds = elapsed_time.seconds % 60
                logging.info(f"Started at {start_time}")
                logging.info(f"Stopped at: {stop_time}")
                logging.info(f"Time elapsed: {hours}h {minutes}m {seconds}s")

    except FileNotFoundError:
        logging.exception(f"Could not find the file {file_path}")
        input("Press any key to exit...")
        exit(1)
