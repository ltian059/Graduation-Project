import datetime
import glob
import logging
import os
from parse import real_time_conversion
import configuration

if __name__ == '__main__':
    if configuration.AUTO_DETECT:
        list_of_files = glob.glob(configuration.SEARCH_PATTERN)
        if not list_of_files:
            logging.error("No .bin files found in the current directory. Will try to use the file in config instead.")
        else:
            latest_file = max(list_of_files, key=os.path.getmtime)
            logging.info(f"The newest .bin file found: {latest_file}")
            configuration.FILE_PATH = latest_file
    else:
        # FILE_PATH = input("Please enter the path to the binary file: ")
        while not configuration.FILE_PATH.strip():
            logging.error("When auto detect is disabled, file path is required in the config file.")
            input("Press any key to exit...")
            exit(1)
            # FILE_PATH = input("Please enter the path to the binary file: ")

    if not configuration.FILE_PATH.strip():
        logging.error("No file path provided. Exiting...")
    else:
        file_path = configuration.FILE_PATH.strip('\"')  # Your binary file
        current_time = datetime.datetime.now().strftime("%d%m%Y%H%M%S")
        csv_file_path = f'./parsed_file_{current_time}.csv'  # output csv file
        real_time_conversion(file_path, csv_file_path, configuration.ACTUAL_FRAME_RATE)
        logging.info(f"Completed")

    input("Press any key to exit...")
