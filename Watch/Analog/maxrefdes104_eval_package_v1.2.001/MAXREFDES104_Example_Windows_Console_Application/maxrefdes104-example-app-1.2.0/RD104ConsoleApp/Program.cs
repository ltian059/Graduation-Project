/*******************************************************************************
* Copyright (C) Maxim Integrated Products, Inc., All rights Reserved.
* 
* This software is protected by copyright laws of the United States and
* of foreign countries. This material may also be protected by patent laws
* and technology transfer regulations of the United States and of foreign
* countries. This software is furnished under a license agreement and/or a
* nondisclosure agreement and may only be used or reproduced in accordance
* with the terms of those agreements. Dissemination of this information to
* any party or parties not specified in the license agreement and/or
* nondisclosure agreement is expressly prohibited.
*
* The above copyright notice and this permission notice shall be included
* in all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
* OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
* IN NO EVENT SHALL MAXIM INTEGRATED BE LIABLE FOR ANY CLAIM, DAMAGES
* OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
* ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
* OTHER DEALINGS IN THE SOFTWARE.
*
* Except as contained in this notice, the name of Maxim Integrated
* Products, Inc. shall not be used except as stated in the Maxim Integrated
* Products, Inc. Branding Policy.
*
* The mere transfer of this software does not imply any licenses
* of trade secrets, proprietary technology, copyrights, patents,
* trademarks, maskwork rights, or any other form of intellectual
* property whatsoever. Maxim Integrated Products, Inc. retains all
* ownership rights.
*******************************************************************************
*/
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

using RD104BleApi;
using RD104BleApi.Ble;
using RD104BleApi.CySmart;

namespace RD104ConsoleApp
{
    /// <summary>
    /// Example Program for MAXREFDES104 Host BLE communication
    ///
    /// This program connects to the dongle, scans for MAXREFDES104, connects
    /// and configures the device, and prints outs selected raw values and
    /// algorithm outputs to the console.
    ///
    /// This is an example program and does not illustrate every feature of the
    /// reference design.
    ///
    /// The RD104BleApi project implements the commands from the MAXREFDES104
    /// HSP 3.0 Host BLE API document. Refer to this document for byte value
    /// definitions and decoding.
    ///
    /// Before running this program, you must configure the comPort string to
    /// match with the dongle.
    /// </summary>
    class Program
    {
        IBleDongle dongle;
        RD104Api api;

        List<ulong> bleAddresses = new List<ulong>();
        List<byte> ppgDataCache = new List<byte>();

        RegisterSettings registerSettingsAlgoHub;
        RegisterSettings registerSettingsSensorHub;

        public Program()
        {
            // 3 Meas for HR, SpO2, and ECG
            // See MAX86176 datasheet for register map details
            registerSettingsAlgoHub = new RegisterSettings();
            registerSettingsAlgoHub.Addresses = new byte[]
            {
                0x11, 0x12,
                0x1c, 0x1d, 0x1e,
                0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26,
                0x28, 0x29, 0x2A, 0x2B, 0x2C, 0x2D, 0x2E,
                0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36,
                0x90
            };

            registerSettingsAlgoHub.Values = new byte[]
            {
                0x07, 0x04,
                0x20, 0x05, 0x1F,
                0x08, 0x18, 0x3F, 0x50, 0x08, 0x14, 0x00,
                0x01, 0x1A, 0x3F, 0x50, 0x01, 0x28, 0x00,
                0x02, 0x1A, 0x3F, 0x50, 0x01, 0x28, 0x00,
                0x82
            };

            // 3 Meas - Initial LED currents
            registerSettingsSensorHub = new RegisterSettings();
            registerSettingsSensorHub.Addresses = new byte[]
            {
                0x25,
                0x2D,
                0x35
            };

            registerSettingsSensorHub.Values = new byte[]
            {
                0x14,
                0x28,
                0x28
            };
        }

        static void Main(string[] args)
        {
            string comPort = "com4"; // TODO - change this to match dongle's COM port

            var p = new Program();
            p.Run(comPort);
        }

        public void Run(string comPort)
        {
            // Dongle Connect
            Console.WriteLine("Connecting to dongle on " + comPort);
            dongle = new CySmartBleDongle(comPort);
            if (!dongle.Connect())
            {
                Console.Error.WriteLine("Error: Unable to connect to dongle at " + comPort);
                return;
            }

            // Scan for Devices
            Console.WriteLine("Scanning for BLE Devices");
            Console.WriteLine("Enter number for device to connect to...");
            bleAddresses.Clear();
            dongle.DeviceFound += OnDongleDeviceFound;
            dongle.StartScan();
            var input = Console.ReadLine();
            dongle.StopScan();
            bool r = int.TryParse(input, out int index);
            if (!r)
            {
                Console.Error.WriteLine("Error: Failed to parse value: " + input);
                return;
            }

            // Connect to Device
            var device = new RD104BleDevice(dongle.ConnectToDevice(new BleAddress(bleAddresses[index], 0)));
            if (device == null)
            {
                Console.Error.WriteLine("Error: Failed to connect to device " + bleAddresses[index]);
                dongle.Disconnect();
                return;
            }

            // Setup
            if (!device.InitializeUuid())
            {
                Console.Error.WriteLine("Error: Failed to initialize UUID and characteristics");
                dongle.Disconnect();
                return;
            }

            device.InitializeCccd(true); // Enable BLE notifications
            device.SetMtu(); // Require larger MTU size

            // Setup API
            api = new RD104Api(device.ReadWriteConfig);
            // Pick 1 out of SetupAlgoHubAgc(), SetupAlgoHubAec(), or SetupRaw()
            // SetupAlgoHubAgc();
            // SetupAlgoHubAec();
            SetupRaw();
            // SetupSensorHubAgc();
            // SetupSensorHubAec();
            device.NotificationAvailable += OnDeviceNotificationAvailable;
            ppgDataCache.Clear();

            var version = api.McuVersionRead();
            Console.WriteLine("Ver: " + version.ToString());

            // Start data collection
            Console.WriteLine("Press <enter> to start and <enter> to stop");
            Console.ReadLine();
            api.McuEnableSensors(true);
            Console.ReadLine();
            api.McuEnableSensors(false);

            // Disconnect from dongle
            dongle.Disconnect();

            Console.WriteLine("Press <enter> to exit");
            Console.ReadLine();
        }

        private static string ByteArrayToString(byte[] data)
        {
            string str = "";

            for (int i = 0; i < data.Length; i++)
            {
                str += data[i].ToString("X02") + " ";
            }

            return str;
        }

        private static List<byte> StripHeader(byte[] notiBytes)
        {
            List<byte> stripHeader = new List<byte>();
            for (int i = 2; i < 20; i++)
            {
                stripHeader.Add(notiBytes[i]);
            }
            return stripHeader;
        }

        /// <summary>
        /// Example Algo Hub AEC settings
        /// </summary>
        private void SetupAlgoHubAec()
        {
            // Setup 3 measurements and ECG
            for (int i = 0; i < registerSettingsAlgoHub.Addresses.Length; i++)
            {
                api.AfeReadModifyWriteRegister(registerSettingsAlgoHub.Addresses[i], 7, 0, registerSettingsAlgoHub.Values[i]);
            }

            api.AlgorithmOperationMode(1); // Enable Algo Output
            api.AlgorithmMode(0); // HR & SpO2
            api.AlgorithmAfeControl(1); // AGC
            api.McuEnableAccelerometer(true);

            api.AlgorithmAecSamplingFramerateAveraging(3, 0); // Initial at 25sps/1avg
            api.AlgorithmAecIntegrationTime(0, 3); // Initial integration time 117.3us
            api.AlgorithmAecTargetPDCurrent(6, 4); // Min PD Current 4uA
            api.AlgorithmAecTargetPDCurrent(7, 10); // Initial PD Current 10uA
            api.AlgorithmAecDacOffset(0, 0, 0); // Meas 1, 0uA, 0uA
        }

        /// <summary>
        /// Example Algo Hub AGC settings
        /// </summary>
        private void SetupAlgoHubAgc()
        {
            // Setup 3 measurements and ECG
            for (int i = 0; i < registerSettingsAlgoHub.Addresses.Length; i++)
            {
                api.AfeReadModifyWriteRegister(registerSettingsAlgoHub.Addresses[i], 7, 0, registerSettingsAlgoHub.Values[i]);
            }

            api.AlgorithmOperationMode(1); // Enable Algo Output
            api.AlgorithmMode(0); // HR & SpO2
            api.AlgorithmAfeControl(2); // AGC
            api.McuEnableAccelerometer(true);

            api.AlgorithmAgcHRTargetPDCurrent(10); // 10uA
        }

        /// <summary>
        /// Example Raw Mode settings (no algorithm outputs)
        /// </summary>
        private void SetupRaw()
        {
            api.AlgorithmOperationMode(0); // Set Raw/Normal mode - must be first (to exit out of SH mode)

            // Setup 3 measurements and ECG
            for (int i = 0; i < registerSettingsAlgoHub.Addresses.Length; i++)
            {
                api.AfeReadModifyWriteRegister(registerSettingsAlgoHub.Addresses[i], 7, 0, registerSettingsAlgoHub.Values[i]);
            }

            api.McuEnableAccelerometer(true);
        }

        /// <summary>
        /// Example Sensor Hub AEC settings
        /// </summary>
        private void SetupSensorHubAec()
        {
            // Setup 3 measurements LED current
            for (int i = 0; i < registerSettingsSensorHub.Addresses.Length; i++)
            {
                api.AfeReadModifyWriteRegister(registerSettingsSensorHub.Addresses[i], 7, 0, registerSettingsSensorHub.Values[i]);
            }

            api.AlgorithmOperationMode(2); // Enable Sensor Hub Mode
            api.AlgorithmMode(0); // HR & SpO2
            api.AlgorithmAfeControl(1); // AGC
            api.McuEnableAccelerometer(true);

            api.AlgorithmAecSamplingFramerateAveraging(3, 0); // Initial at 25sps/1avg
            api.AlgorithmAecIntegrationTime(0, 3); // Initial integration time 117.3us
            api.AlgorithmAecTargetPDCurrent(6, 4); // Min PD Current 4uA
            api.AlgorithmAecTargetPDCurrent(7, 10); // Initial PD Current 10uA
            api.AlgorithmAecDacOffset(0, 0, 0); // Meas 1, 0uA, 0uA
        }

        /// <summary>
        /// Example Sensor Hub AGC settings
        /// </summary>
        private void SetupSensorHubAgc()
        {
            // Setup 3 measurements LED current
            for (int i = 0; i < registerSettingsSensorHub.Addresses.Length; i++)
            {
                api.AfeReadModifyWriteRegister(registerSettingsSensorHub.Addresses[i], 7, 0, registerSettingsSensorHub.Values[i]);
            }

            api.AlgorithmOperationMode(2); // Enable Sensor Hub Mode
            api.AlgorithmMode(0); // HR & SpO2
            api.AlgorithmAfeControl(2); // AGC
            api.McuEnableAccelerometer(true);

            api.AlgorithmAgcHRTargetPDCurrent(10); // 10uA
        }

        /// <summary>
        /// Example notification packet parsing for some packet types
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void OnDeviceNotificationAvailable(object sender, BleNotifyDataEventArgs e)
        {
            Console.Write(ByteArrayToString(e.Data));

            if (e.Notify == 0 && ppgDataCache.Count > 0) // Parse raw values
            {
                Console.Write(" ");
                var parsedData = NotifyPpgData.PpgParse(ppgDataCache, 1, 3, 2, true); // See API doc for frames value
                ppgDataCache.Clear();
                Console.Write(
                    parsedData.MeasData[0].PD1Tag[0] + " " + parsedData.MeasData[0].PD1[0] + " " // Meas 1 PD1
                    + parsedData.MeasData[0].PD2Tag[0] + " " + parsedData.MeasData[0].PD2[0] + " " // Meas 1 PD2
                    + parsedData.MeasData[1].PD1Tag[0] + " " + parsedData.MeasData[1].PD1[0] + " " // Meas 2 PD1
                    + parsedData.MeasData[1].PD2Tag[0] + " " + parsedData.MeasData[1].PD2[0] + " " // Meas 2 PD2
                    + parsedData.MeasData[2].PD1Tag[0] + " " + parsedData.MeasData[2].PD1[0] + " " // Meas 3 PD1
                    + parsedData.MeasData[2].PD2Tag[0] + " " + parsedData.MeasData[2].PD2[0] + " " // Meas 3 PD2
                    + parsedData.AccelerometerX[0] + " " + parsedData.AccelerometerY[0] + " " + parsedData.AccelerometerZ[0]);
            }

            if (e.Notify == 0 || e.Notify == 1 || e.Notify == 2 || e.Notify == 10) // Sensor 0, 1, 2, 3
            {
                ppgDataCache.AddRange(StripHeader(e.Data));
            }

            if (e.Notify == 0x10) // Algorithm
            {
                var parsedData = NotifyAlgorithmData.Parse(StripHeader(e.Data));
                Console.Write(parsedData.HeartRate + " " + parsedData.HeartRateConfidence + " " +  parsedData.SpO2);
            }

            if (e.Notify == 0x0B) // ECG
            {
                var parsedData = NotifyEcgData.EcgParse(StripHeader(e.Data), false);
                var ecgDataString = "";
                for (int i = 0; i < parsedData.EcgData.Length; i++)
                {
                    ecgDataString += parsedData.EcgData[i].Ecg + " ";
                }
                Console.Write(ecgDataString);
            }

            Console.Write(Environment.NewLine);
        }

        /// <summary>
        /// Example BLE dongle scan results handling
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void OnDongleDeviceFound(object sender, BleDeviceEventArgs e)
        {
            if (e.Name.StartsWith("MAXREFDES104") && !bleAddresses.Contains(e.Address))
            {
                Console.WriteLine("[" + bleAddresses.Count + "] " + e.Address.ToString("X02")
                    + " Type: " + e.AddressType + " Power: " + e.Rssi + " Name: " + e.Name);
                bleAddresses.Add(e.Address);
            }
        }
    }
}
