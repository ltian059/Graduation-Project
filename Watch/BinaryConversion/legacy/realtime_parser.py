import datetime
from parse import real_time_conversion

CLOCK = 32000
DESIRED_FRAME_RATE = 250



if __name__ == '__main__':
    FILE_PATH = input("Please enter the path to the binary file: ")
    while not FILE_PATH.strip():
        print("File path is required.")
        FILE_PATH = input("Please enter the path to the binary file: ")

    clock_input = input("Please enter the Clock rate in Hz: (default is 32000)")
    if clock_input.strip() == "":
        pass
    else:
        CLOCK = float(clock_input)

    desired_frame_rate_input = input("Please enter the desired frame rate per second: (default is 250)")
    if desired_frame_rate_input.strip() == "":
        pass
    else:
        DESIRED_FRAME_RATE = float(desired_frame_rate_input)

    CLOCK_DIVISOR = CLOCK // DESIRED_FRAME_RATE
    ACTUAL_FRAME_RATE = round(CLOCK / CLOCK_DIVISOR, 2)
    print(f"Actual frame rate is {ACTUAL_FRAME_RATE}")


    file_path = FILE_PATH.strip('\"')  # Your binary file
    current_time = datetime.datetime.now().strftime("%d%m%Y%H%M%S")
    csv_file_path = f'./parsed_file_{current_time}.csv'  # output csv file
    real_time_conversion(file_path, csv_file_path, ACTUAL_FRAME_RATE)
    print(f"Completed")
    input("Press any key to exit...")

