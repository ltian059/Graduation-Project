import json
import datetime
import logging
import os

CONFIG_FILE = 'config.json'

try:
    with open(CONFIG_FILE, 'r') as config_file:
        config_content = config_file.read()

    corrected_config = config_content.replace("\\", "/")
    config = json.loads(corrected_config)
    LOGGING_LEVEL = config.get('logging', 'info')
    if not os.path.exists(config.get('logging_directory', './logs')):
        os.makedirs(config.get('logging_directory', './logs'))

    LOGGING_FILE_NAME = config.get('logging_directory', './') + '/' + 'log_' + datetime.datetime.now().strftime("%d%m%Y%H%M%S") + '.log'

    level = logging.INFO
    if LOGGING_LEVEL.lower() == 'debug':
        level = logging.DEBUG
    elif LOGGING_LEVEL.lower() == 'info':
        level = logging.INFO
    elif LOGGING_LEVEL.lower() == 'warning':
        level = logging.WARNING
    elif LOGGING_LEVEL.lower() == 'error':
        level = logging.ERROR
    else:
        level = logging.INFO

    # Configurate logging
    logging.basicConfig(
        level=level,
        filename=LOGGING_FILE_NAME,
        format='%(asctime)s - %(levelname)s - %(message)s',
        filemode='w'
    )

    # Add a StreamHandler so that logging can output to console at the same time
    console_handler = logging.StreamHandler()
    console_handler.setLevel(level)
    console_handler.setFormatter(logging.Formatter('%(asctime)s - %(levelname)s - %(message)s'))
    logging.getLogger().addHandler(console_handler)

    logging.debug(corrected_config)

except FileNotFoundError:
    logging.exception(f"Configuration file '{CONFIG_FILE}' not found.")
    input("Press any key to exit...")
    exit(1)
except json.JSONDecodeError as e:
    logging.exception(f"Error decoding JSON configuration file: {e}")
    input("Press any key to exit...")
    exit(1)
except Exception as e:
    logging.exception(f"An unexpected error occurred: {e}")
    input("Press any key to exit...")
    exit(1)

CLOCK = config.get('clock')
DESIRED_FRAME_RATE = config.get('desired_frame_rate')
AUTO_DETECT = config.get('auto_detect', True)
FILE_PATH = config.get('file_path', '')
SEARCH_PATTERN = config.get('search_pattern', '*.bin')
OUTPUT_DIRECTORY = config.get('output_directory', './')

CLOCK_DIVISOR = CLOCK // DESIRED_FRAME_RATE
ACTUAL_FRAME_RATE = round(CLOCK / CLOCK_DIVISOR, 2)
logging.info(f"Actual frame rate is {ACTUAL_FRAME_RATE}")
