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

using RD104BleApi.CySmart;

namespace RD104BleApi.Ble
{
    public interface IBleDongle
    {
        /// <summary>
        /// COM Port dongle is connected to or string for Win BLE
        /// </summary>
        string ComPort { get; set; }
        /// <summary>
        /// Connect to dongle
        /// </summary>
        /// <returns><c>true</c> for success. <c>false</c> for failure.</returns>
        bool Connect();
        /// <summary>
        /// Connected state to dongle
        /// </summary>
        bool Connected { get; }
        /// <summary>
        /// Connect to BLE device
        /// </summary>
        /// <param name="address">BLE Address of device</param>
        /// <returns>BLE Device</returns>
        CySmartBleDevice ConnectToDevice(BleAddress address);
        /// <summary>
        /// Connected state of BLE Device
        /// </summary>
        bool DeviceConnected { get; }
        /// <summary>
        /// Event for devices found during scanning
        /// </summary>
        event EventHandler<BleDeviceEventArgs> DeviceFound;
        /// <summary>
        /// Disconnect from BLE Dongle
        /// </summary>
        /// <returns></returns>
        bool Disconnect();
        /// <summary>
        /// Event for device disconnect
        /// </summary>
        event EventHandler<BleDeviceEventArgs> Disconnected;
        /// <summary>
        /// Disconnect from currently connected device
        /// </summary>
        /// <returns><c>true</c> for success. <c>false</c> for failure.</returns>
        bool DisconnectFromDevice();
        /// <summary>
        /// Get last RSSI (dBm)
        /// </summary>
        /// <returns>value</returns>
        sbyte LastRssi();
        /// <summary>
        /// Start scanning. Results in DeviceFound event.
        /// </summary>
        /// <returns><c>true</c> for success. <c>false</c> for failure.</returns>
        bool StartScan();
        /// <summary>
        /// Stop scanning.
        /// </summary>
        /// <returns><c>true</c> for success. <c>false</c> for failure.</returns>
        bool StopScan();
    }
}
