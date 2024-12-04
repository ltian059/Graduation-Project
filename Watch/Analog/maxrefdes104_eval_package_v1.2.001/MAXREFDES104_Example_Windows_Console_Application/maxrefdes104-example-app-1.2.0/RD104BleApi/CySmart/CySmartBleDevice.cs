using System;
using System.Collections.Generic;
using System.Threading;

using RD104BleApi.Ble;
using CySmart.DongleCommunicator.API;

namespace RD104BleApi.CySmart
{
    public class CySmartBleDevice
    {
        internal BleAddress address;
        internal IBleDongle dongle;

        internal ICyBleDevice cyBleDevice;

        List<CyGattService> primaryServices;

        DeviceCb deviceCb = new DeviceCb();
        GattClientCb gattClientCb = new GattClientCb();

        /// <summary>
        /// Constructor
        /// </summary>
        /// <param name="address">BLE Address</param>
        /// <param name="dongle">CySmart Dongle</param>
        /// <param name="cyBleDevice">CySmart Device</param>
        public CySmartBleDevice(BleAddress address, IBleDongle dongle, ICyBleDevice cyBleDevice)
        {
            this.address = address;
            this.dongle = dongle;
            this.cyBleDevice = cyBleDevice;

            cyBleDevice.GattClient.RegisterCallback(gattClientCb);

            dongle.Disconnected += OnDongleDisconnected;
        }


        /// <summary>
        /// Characteristic Changed Handler callback
        /// </summary>
        public Action<CyCharacteristicChangedInfo> CharacteristicChangedHandler
        {
            set
            {
                gattClientCb.CharacteristicChangedHandler = value;
            }
        }


        public event EventHandler<EventArgs> Disconnected;

        /// <inheritdoc/>
        public bool DiscoverServices()
        {
            AutoResetEvent sync = new AutoResetEvent(false);
            CyApiErr err = CyApiErr.OK;

            gattClientCb.ServiceDiscoveredHandler = (result, status) =>
            {
                if (status != CyStatus.BLE_STATUS_OK)
                    err = new CyApiErr("Failed to discover services. Reason: " + status.ToString());

                //serviceResult = result;
                primaryServices = result.Services;

                sync.Set();
            };

            err = cyBleDevice.GattClient.DiscoverAllServices();
            if (err.IsOK)
            {
                if (!sync.WaitOne(1000))
                    //Checking for timeout
                    err = new CyApiErr("Failed to discover services. Timeout Error");
            }

            return err.IsOk;
        }

        public int LastRssi()
        {
            return dongle.LastRssi();
        }

        /// <summary>
        /// Get CCCD from Descriptors
        /// </summary>
        /// <param name="descs">Descriptors to search</param>
        /// <returns>First CCCD found; otherwise 0</returns>
        public ushort FetchCCCD(List<CyGattDescriptor> descs)
        {
            CyUUID cyUuid = new CyUUID(0x2902);

            foreach (CyGattDescriptor desc in descs)
            {
                if (UuidMatch(desc.UUID, cyUuid))
                    return desc.Handle;
            }

            return 0;
        }

        /// <summary>
        /// Find service matching uuid
        /// </summary>
        /// <param name="uuid">uuid as string</param>
        /// <returns>service, otherwise null</returns>
        public CyGattService GetService(string uuid)
        {
            CyUUID cyUuid = new CyUUID(BleUtility.UuidConvert(uuid));


            //Changed from serviceResult to primaryServices
            foreach (CyGattService serv in primaryServices)
            {
                if (UuidMatch(serv.UUID, cyUuid))
                    return serv;
            }

            return null;
        }

        /// <summary>
        /// Get Characteristic with uuid contained within service
        /// </summary>
        /// <param name="uuid">uuid to match</param>
        /// <param name="service">service to search</param>
        /// <returns>first matching characteristic, otherwise null</returns>
        public CyGattCharacteristic GetCharacteristic(string uuid, CyGattService service)
        {
            //No longer used
            CyUUID cyUuid = new CyUUID(BleUtility.UuidConvert(uuid));

            foreach (CyGattCharacteristic charac in service.Characteristics)
            {
                if (UuidMatch(charac.UUID, cyUuid))
                    return charac;
            }

            return null;
        }

        /// <summary>
        /// Get descriptor within characteristic
        /// </summary>
        /// <param name="characteristic">characteristic to search (with UUID)</param>
        /// <returns>First matching descriptor; otherwise null</returns>
        public CyGattDescriptor GetDescriptor(CyGattCharacteristic characteristic)
        {
            //New use: fetching the CCCD handle from the notify characteristic

            //The CCCD uuid is always 0x2902
            CyUUID cyUuid = new CyUUID(0x2902);

            foreach (CyGattDescriptor desc in characteristic.Descriptors)
            {
                if (UuidMatch(desc.UUID, cyUuid))
                    return desc;
            }

            return null;
        }

        /*public bool Disconnect()
        {
            return dongle.DisconnectFromDevice(cyBleDevice);
        }*/

        public byte[] ReadCharacteristic(ushort handle)
        {
            //Log.Debug("Read Char: handle " + handle.ToString("X4"));
            AutoResetEvent sync = new AutoResetEvent(false);
            CyApiErr err = CyApiErr.OK;
            byte[] readData = null;

            //gattClientCb.CharacteristicReadByUUIDHandler = (result, status) =>
            gattClientCb.CharacteristicReadHandler = (result, status) =>
            {
                if (status != CyStatus.BLE_STATUS_OK)
                {
                    throw new BleException("Failed to read char. Reason: " + status.ToString());
                }

                readData = result.Value;
                sync.Set();
            };

            //err = cyBleDevice.GattClient.ReadCharacteristicByUUID(new CyReadCharacteristicByUUIDInfo(new CyUUID(uuid), handle, handle));
            err = cyBleDevice.GattClient.ReadCharacteristic(new CyGattReadInfo(handle));
            if (err.IsOK)
            {
                if (sync.WaitOne(1000))
                {
                    string dataStr = String.Empty;
                    foreach (byte b in readData)
                        dataStr += b.ToString("X2") + " ";
                }
                else
                {
                    throw new BleException("Read timed out.");
                }
            }

            return readData;
        }

        public byte[] ReadCharacteristic(CyGattCharacteristic characteristic)
        {
            AutoResetEvent sync = new AutoResetEvent(false);
            CyApiErr err = CyApiErr.OK;
            byte[] readData = null;

            //gattClientCb.CharacteristicReadByUUIDHandler = (result, status) =>
            gattClientCb.CharacteristicReadHandler = (result, status) =>
            {
                if (status != CyStatus.BLE_STATUS_OK)
                {
                    throw new BleException("Failed to read char. Reason: " + status.ToString());
                }

                readData = result.Value;
                sync.Set();
            };

            //err = cyBleDevice.GattClient.ReadCharacteristicByUUID(new CyReadCharacteristicByUUIDInfo(new CyUUID(uuid), handle, handle));
            err = cyBleDevice.GattClient.ReadCharacteristic(new CyGattReadInfo(characteristic));
            if (err.IsOK)
            {
                if (!sync.WaitOne(1000))
                {
                    throw new BleException("Read timed out.");
                }
            }

            return readData;
        }

        /// <summary>
        /// Set to the maximum MTU, hard coded to (240+1)
        /// </summary>
        /// <returns></returns>
        public int SetMaximumMtu()
        {
            AutoResetEvent sync = new AutoResetEvent(false);
            CyApiErr err = CyApiErr.OK;

            int mtuSize = -1;

            gattClientCb.GattMtuExchangedHandler = (result, status) =>
            {
                if (status != CyStatus.BLE_STATUS_OK)
                {
                    throw new BleException("Failed to set MTU size. Reason: " + status.ToString());
                }

                mtuSize = result.NegotiatedGattMtu;

                sync.Set();
            };

            err = cyBleDevice.GattClient.ExchangeMtu(new CyGattExchangeMtuInfo(512));
            if (err.IsOk)
            {
                if (!sync.WaitOne(1000))
                {
                    throw new BleException("GATT MTU Exchange time out");
                }
            }

            return mtuSize;
        }

        public bool WriteDescriptor(ushort handle, byte[] data)
        {
            AutoResetEvent sync = new AutoResetEvent(false);
            CyApiErr err = CyApiErr.OK;

            // Setup the descriptor write handler
            gattClientCb.DescriptorWriteHandler = (result, status) =>
            {
                if (status != CyStatus.BLE_STATUS_OK)
                {
                    throw new BleException("Failed to start/stop notification monitoring. Reason: " + status.ToString());
                }

                sync.Set();
            };

            // Initiate write descriptor request to the CCCD
            err = cyBleDevice.GattClient.WriteDescriptor(new CyGattWriteInfo(handle, data));
            if (err.IsOK)
            {
                if (!sync.WaitOne(1000))
                {
                    throw new BleException("WriteDescriptor timed out");
                }
            }

            return err.IsOK;
        }

        public bool WriteDescriptor(CyGattDescriptor descriptor, byte[] data)
        {
            AutoResetEvent sync = new AutoResetEvent(false);
            CyApiErr err = CyApiErr.OK;

            // Setup the descriptor write handler
            gattClientCb.DescriptorWriteHandler = (result, status) =>
            {
                if (status != CyStatus.BLE_STATUS_OK)
                {
                    throw new BleException("Failed to start/stop notification monitoring. Reason: " + status.ToString());
                }
                sync.Set();
            };

            // Initiate write descriptor request to the CCCD
            err = cyBleDevice.GattClient.WriteDescriptor(new CyGattWriteInfo(descriptor, data));
            if (err.IsOK)
            {
                if (!sync.WaitOne(1000))
                {
                    throw new BleException("WriteDescriptor timed out.");
                }
            }

            return err.IsOK;
        }

        public bool WriteCharcteristic(ushort handle, byte[] data)
        {
            AutoResetEvent sync = new AutoResetEvent(false);
            CyApiErr err = CyApiErr.OK;

            gattClientCb.CharacteristicWriteHandler = (result, status) =>
            {
                if (status != CyStatus.BLE_STATUS_OK)
                {
                    throw new BleException("Failed to write char. Reason: " + status.ToString());
                }

                sync.Set();
            };

            err = cyBleDevice.GattClient.WriteCharacteristic(new CyGattWriteInfo(handle, data));
            if (err.IsOK)
            {
                if (!sync.WaitOne(1000))
                {
                    throw new BleException("WriteCharcacteristic timed out");
                }
            }

            return err.IsOK;
        }

        public bool WriteCharacteristic(CyGattCharacteristic characteristic, byte[] data)
        {
            AutoResetEvent sync = new AutoResetEvent(false);
            CyApiErr err = CyApiErr.OK;

            gattClientCb.CharacteristicWriteHandler = (result, status) =>
            {
                if (status != CyStatus.BLE_STATUS_OK)
                {
                    throw new BleException("Failed to write char. Reason: " + status.ToString());
                }

                sync.Set();
            };

            err = cyBleDevice.GattClient.WriteCharacteristic(new CyGattWriteInfo(characteristic, data));
            if (err.IsOK)
            {
                if (!sync.WaitOne(1000))
                {
                    throw new BleException("WriteCharacteristic timed out.");
                }
            }

            return err.IsOK;
        }

        private CyGattCharacteristic FetchCharacteristic(string uuid, List<CyGattCharacteristic> characs)
        {
            CyUUID CyUuid = new CyUUID(BleUtility.UuidConvert(uuid));

            foreach (CyGattCharacteristic charac in characs)
            {
                if (UuidMatch(charac.UUID, CyUuid))
                {
                    return charac;
                }
            }

            return null;
        }

        private List<CyGattCharacteristic> DiscoverCharacteristics(CyGattService serv)
        {
            AutoResetEvent sync = new AutoResetEvent(false);
            List<CyGattCharacteristic> characs = new List<CyGattCharacteristic>();
            ushort sHandle = serv.StartHandle;
            ushort eHandle = serv.EndHandle;
            CyDiscoverCharacteristicsInfo info = new CyDiscoverCharacteristicsInfo(sHandle, eHandle);
            DiscoverCharacteristicCb DCCb = new DiscoverCharacteristicCb();
            CyApiErr err = CyApiErr.OK;

            DCCb.CharacteristicDiscoveredHandler = (result, status) =>
            {
                characs = result.Characteristics;
                sync.Set();
            };

            err = cyBleDevice.GattClient.DiscoverCharacteristics(info, DCCb);

            if (err.IsOK)
            {
                if (!sync.WaitOne(1000))
                    //Checking for timeout
                    err = new CyApiErr("Failed to discover services. Timeout Error");
            }

            return characs;
        }

        private List<CyGattDescriptor> DiscoverDescriptors(CyGattCharacteristic charac, CyGattService serv)
        {
            AutoResetEvent sync = new AutoResetEvent(false);
            List<CyGattDescriptor> descs = new List<CyGattDescriptor>();
            CyApiErr err = CyApiErr.OK;
            DescriptorCb DescCb = new DescriptorCb();
            ushort sHandle = charac.Handle;
            ushort imcurious = charac.DeclarationHandle;
            ushort eHandle = serv.EndHandle;
            CyDiscoverDescriptorsInfo info = new CyDiscoverDescriptorsInfo(sHandle, eHandle);

            DescCb.DescriptorDiscoveredHandler = (result, status) =>
            {
                descs = result.Descriptors;
                sync.Set();
            };

            err = cyBleDevice.GattClient.DiscoverDescriptors(info, DescCb);
            if (err.IsOK)
            {
                if (!sync.WaitOne(1000))
                    //Checking for timeout
                    err = new CyApiErr("Failed to discover services. Timeout Error");
            }

            return descs;
        }

        private void OnDongleDisconnected(object sender, BleDeviceEventArgs e)
        {
            if (e.Address.Equals(address.Address))
            {
                if (Disconnected != null)
                    Disconnected(this, new EventArgs());
            }
        }

        private bool UuidMatch(CyUUID uuid1, CyUUID uuid2)
        {
            if (uuid1.UUID128.Rank != uuid2.UUID128.Rank)
                return false;
            if (uuid1.IsUUID16Valid != uuid2.IsUUID16Valid)
                return false;
            if (uuid1.UUID128.Length != uuid2.UUID128.Length)
                return false;
            for (int ix = 0; ix < uuid1.UUID128.Length; ix++)
                if (uuid1.UUID128[ix] != uuid2.UUID128[ix])
                    return false;
            return true;
        }
    }
}
