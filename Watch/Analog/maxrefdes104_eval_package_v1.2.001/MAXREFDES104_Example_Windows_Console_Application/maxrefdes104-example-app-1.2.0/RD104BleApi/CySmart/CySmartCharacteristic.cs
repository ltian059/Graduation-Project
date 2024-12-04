using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

using RD104BleApi.Ble;

namespace RD104BleApi.CySmart
{
    public class CySmartCharacteristic : IGattCharacteristic
    {
        ushort handle;
        CySmartBleDevice bleDevice;

        /// <summary>
        /// Constructor
        /// </summary>
        /// <param name="bleDevice">characteristic associated with device</param>
        /// <param name="handle">BLE handle this class will be associated with</param>
        public CySmartCharacteristic(CySmartBleDevice bleDevice, ushort handle)
        {
            this.bleDevice = bleDevice;
            this.handle = handle;
        }

        /// <summary>
        /// <see cref="ICharacteristicStream.Read" />
        /// </summary>
        /// <returns>read bytes</returns>
        public byte[] Read()
        {
            byte[] result;
            result = bleDevice.ReadCharacteristic(handle);

            return result;
        }

        /// <summary>
        /// <see cref="ICharacteristicStream.Write(byte[])" />
        /// </summary>
        /// <param name="data">write bytes</param>
        /// <returns><c>true</c> if success; otherwise <c>false</c>.</returns>
        public bool Write(byte[] data)
        {
            bool result;

            result = bleDevice.WriteCharcteristic(handle, data);

            return result;
        }
    }
}
