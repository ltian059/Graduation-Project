import threading
import subprocess

def run_script(script_path):
    subprocess.run(["python", script_path])

# Define the paths to the scripts
scripts = [
    r"D:\OneDrive\Desktop\Graduate Project\Summer 2024 Health Monitoring - Charlie's Work\Charlie_Code\Data Collection\bb2main_mps.py",
    r"D:\OneDrive\Desktop\Graduate Project\Summer 2024 Health Monitoring - Charlie's Work\Charlie_Code\Data Collection\Camera_Test_saveFrames.py",
    r"D:\OneDrive\Desktop\Graduate Project\Summer 2024 Health Monitoring - Charlie's Work\Charlie_Code\Data Collection\radarthread.py"
]

# Create a thread for each script
threads = []
for script in scripts:
    thread = threading.Thread(target=run_script, args=(script,))
    threads.append(thread)

# Start all threads
for thread in threads:
    thread.start()

# Wait for all threads to complete
for thread in threads:
    thread.join()
