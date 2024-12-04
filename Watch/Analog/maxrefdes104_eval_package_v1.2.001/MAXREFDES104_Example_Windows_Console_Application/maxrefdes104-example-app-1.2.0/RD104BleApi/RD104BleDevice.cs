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

using CySmart.DongleCommunicator.API;
using RD104BleApi.Ble;
using RD104BleApi.CySmart;

namespace RD104BleApi
{
    /// <summary>
    /// RD104 specific GATT characteristics/descriptors/UUID
    /// </summary>
    public class RD104BleDevice
    {
        /// <summary>FW API Service UUID </summary>
        const string SensorServiceUuid = "6E400000-B5A3-F393-E0A9-E50E24DCCA9E";
        /// <summary>FW API Characteristic UUID </summary>
        const string SensorServiceStreamDataCharUuid = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E";
        /// <summary>FW API Characteristic UUID </summary>
        const string SensorServiceConfigCharUuid = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E";

        private CyGattService service;
        private CyGattCharacteristic characteristic_notify;
        private CyGattCharacteristic characteristic_config;
        private CyGattDescriptor descriptor_cccd;

        private ushort NotifyHandle;
        private ushort CccdHandle;
        private ushort ConfigHandle;

        CySmartBleDevice device;

        public RD104BleDevice(CySmartBleDevice device)
        {
            this.device = device;
        }

        public event EventHandler<BleNotifyDataEventArgs> NotificationAvailable;

        public IGattCharacteristic ReadWriteConfig
        {
            get; private set;
        }

        public void InitializeCccd(bool enable)
        {
            device.WriteDescriptor(CccdHandle, new byte[]
            {
                (byte)(enable ? 0x01 : 0x00), 0x00 // 16-bit little endian CCCD value
            }); // Enable notifications CCCD

            InitializeNotifyCallBack();
        }

        public bool InitializeUuid()
        {
            if (!device.DiscoverServices())
                return false;

            service = device.GetService(SensorServiceUuid);
            if (service == null)
                return false;

            characteristic_config = device.GetCharacteristic(SensorServiceConfigCharUuid, service);
            if (characteristic_config == null)
                return false;
            ConfigHandle = characteristic_config.Handle;

            characteristic_notify = device.GetCharacteristic(SensorServiceStreamDataCharUuid, service);
            if (characteristic_notify == null)
                return false;
            NotifyHandle = characteristic_notify.Handle;

            descriptor_cccd = device.GetDescriptor(characteristic_notify);
            if (descriptor_cccd == null)
                return false;
            CccdHandle = descriptor_cccd.Handle;

            ReadWriteConfig = new CySmartCharacteristic(device, ConfigHandle);

            return true;
        }

        public int SetMtu()
        {
            return device.SetMaximumMtu();
        }

        private void InitializeNotifyCallBack()
        {
            device.CharacteristicChangedHandler = info =>
            {
                // Split into 20 byte chunks
                for (int i = 0; i < info.Value.Length / 20; i++)
                {
                    var data20 = new byte[20];
                    for (int j = 0; j < data20.Length; j++)
                    {
                        data20[j] = info.Value[i * 20 + j];
                    }

                    NotificationAvailable?.Invoke(this, new BleNotifyDataEventArgs()
                    {
                        First = (i == 0),
                        Data = data20
                    });
                }
            };
        }
    }
}
