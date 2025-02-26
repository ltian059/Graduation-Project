'''
Created on Dec 25, 2018

'''

import time
import collections
import subprocess
import os
import csv
import math
import logging
import datetime

import multiprocessing
# from processBR import processBR
import threading
import queue
import numpy as np
from breathingBeltHandlerHacked import CollectionThreadGDXRBDummy, GoDirectDevices
from BeltBreathRate import BreathRate
from multiprocessing.connection import Listener

DIRECTORY_PATH = r"D:\\OneDrive\\Desktop\\Graduate Project\\Summer 2024 Health Monitoring - Charlie's Work\\Charlie_Code\\Data Collection\\data\\belt" + time.strftime(u"%Y%m%d") + "/"

def sensor_thread(device, rateQ):
    name = device.name
    if not os.path.exists(DIRECTORY_PATH + name + '/'):
        os.makedirs(DIRECTORY_PATH + name + '/')

    # CSV file paths
    force_data_csv_path = os.path.join(DIRECTORY_PATH + name + '/', 'force_data.csv')
    breathing_rate_csv_path = os.path.join(DIRECTORY_PATH + name + '/', 'breathing_rate.csv')

    bbeltDataLock = threading.Lock()
    stopEvent = threading.Event()
    bbeltDataQ = queue.Queue()
    bbeltThread = CollectionThreadGDXRBDummy(
        threadID=1, name=name, device=device,
        dataQueue=bbeltDataQ, dataLock=bbeltDataLock,
        stopEvent=stopEvent
    )
    bbeltThread.start()
    bbeltDataDeck = collections.deque(maxlen=15 * 10)
    dataList = []
    timeList = []
    t = threading.currentThread()

    # Open CSV files for writing
    with open(force_data_csv_path, 'w', newline='') as force_file, open(breathing_rate_csv_path, 'w', newline='') as rate_file:
        force_writer = csv.writer(force_file)
        rate_writer = csv.writer(rate_file)

        try:
            while getattr(t, "do_run", True):
                if not bbeltDataQ.empty():
                    while not bbeltDataQ.empty():
                        dataList.append(bbeltDataQ.get())
                        timeList.append(time.time())
                    bbeltDataDeck.extend(dataList)
                    dataList = []
                    if len(bbeltDataDeck) == 15 * 10:
                        beltData = np.array(bbeltDataDeck, dtype=float)
                        breathing_rate = BreathRate(beltData[:, 1])
                        bbeltDataLock.acquire()
                        rateQ.put(breathing_rate)
                        bbeltDataLock.release()

                        timestamp = float(time.time())

                        # Write raw force data to CSV
                        for data in beltData:
                            force_writer.writerow([timeList.pop(0), data[1]])


                        # Write breathing rate to CSV
                        rate_writer.writerow([timestamp, breathing_rate])

                        bbeltDataDeck.clear()  # Clear the deque after processing

                time.sleep(0.1)  # Small delay to prevent high CPU usage
        except Exception as e:
            print(f"Error in sensor_thread: {e}")
        finally:
            stopEvent.set()
            bbeltThread.join()
if __name__ == "__main__":
    devices = GoDirectDevices()
    rateQ = queue.Queue()
    threads = []

    for device in devices.device_list:
        t = threading.Thread(target=sensor_thread, args=(device, rateQ))
        t.do_run = True
        t.start()
        threads.append(t)

    try:
        while any(t.is_alive() for t in threads):
            while not rateQ.empty():
                rate = rateQ.get()
                print(f"Breathing rate: {rate}")
            time.sleep(1)  # Small delay to prevent high CPU usage
    except KeyboardInterrupt:
        print("Terminating program.")
    finally:
        for t in threads:
            t.do_run = False
            t.join()

        # Ensure all devices are properly stopped and closed
        for device in devices.device_list:
            device.stop()
            device.close()

        print("All threads and devices have been terminated.")
