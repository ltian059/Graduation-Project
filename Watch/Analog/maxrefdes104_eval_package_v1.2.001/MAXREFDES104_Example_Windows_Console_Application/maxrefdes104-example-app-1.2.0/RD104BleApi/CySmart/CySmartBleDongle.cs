using System;
using System.Collections.Generic;
using System.Globalization;
using System.Threading;

using RD104BleApi.Ble;
using CySmart.DongleCommunicator.API;

namespace RD104BleApi.CySmart
{
    /// <summary>
    /// CySmart implementation of BleDongle
    /// </summary>
    public class CySmartBleDongle : IBleDongle
    {
        string comPort;

        ICySmartDongleCommunicator communicator;

        ICyBleDevice peerDevice;

        BleMgrCb bleMgrCb;
        ScanCb scanCb;

        bool connected;
        bool deviceConnected = false;

        /// <summary>
        /// Default Constructor
        /// </summary>
        public CySmartBleDongle()
        {

        }

        /// <summary>
        /// Constructor
        /// </summary>
        /// <param name="comPort">COM Port CySmart dongle is connected to</param>
        public CySmartBleDongle(string comPort)
        {
            this.comPort = comPort;
        }

        /// <summary><see cref="IBleDongle.DeviceFound"/></summary>
        public event EventHandler<BleDeviceEventArgs> DeviceFound;
        /// <summary><see cref="IBleDongle.Disconnected"/></summary>
        public event EventHandler<BleDeviceEventArgs> Disconnected;

        /// <summary><see cref="IBleDongle.ComPort"/></summary>
        public string ComPort
        {
            get
            {
                return comPort;
            }
            set
            {
                comPort = value;
            }
        }

        /// <summary><see cref="IBleDongle.Connected"/></summary>
        public bool Connected
        {
            get
            {
                return connected;
            }
        }

        /// <summary><see cref="IBleDongle.DeviceConnected"/></summary>
        public bool DeviceConnected
        {
            get
            {
                return deviceConnected;
            }
        }

        /// <summary><see cref="IBleDongle.Connect"/></summary>
        public bool Connect()
        {
            CySmartDongleMgr dongleMgr = CySmartDongleMgr.GetInstance();
            CyApiErr err = dongleMgr.TryGetCySmartDongleCommunicator(new CyDongleInfo(comPort), out communicator);
            if (err.IsOK)
            {
                scanCb = new ScanCb();
                bleMgrCb = new BleMgrCb();
                err = communicator.BleMgr.RegisterBleMgrCallback(bleMgrCb);
                if (err.IsNotOk)
                    throw new BleException("RegisterBleMgrCallBack failed.");
                SetupScanResultHelper();

                connected = err.IsOK;

                return connected;
            }
            else
            {
                connected = false;
                return connected;
            }
        }

        /// <summary><see cref="IBleDongle.Disconnect"/></summary>
        public bool Disconnect()
        {
            if (communicator == null)
            {
                return true;
            }

            CyApiErr err = CySmartDongleMgr.GetInstance().CloseCommunicator(communicator);

            connected = !(err.IsOK);

            return err.IsOK;
        }

        public CySmartBleDevice ConnectToDevice(BleAddress address)
        {
            ICyBleDevice cyBleDevice;

            if (!ConnectToDevice(address, out cyBleDevice))
            {
                return null;
            }

            CySmartBleDevice bleDevice = new CySmartBleDevice(address, this, cyBleDevice);

            return bleDevice;
        }

        /// <summary><see cref="IBleDongle.DisconnectFromDevice"/></summary>
        public bool DisconnectFromDevice()
        {
            return DisconnectFromDevice(peerDevice);
        }

        /// <summary><see cref="IBleDongle.StartScan"/></summary>
        public bool StartScan()
        {
            AutoResetEvent sync = new AutoResetEvent(false);
            CyApiErr err = CyApiErr.OK;

            scanCb.ScanStatusChangedHandler = (status) =>
            {
                sync.Set();
            };

            err = communicator.BleMgr.StartScan(new CyBleScanSettings(), scanCb);
            if (err.IsOK)
                sync.WaitOne();

            return err.IsOK;

        }

        /// <summary><see cref="IBleDongle.StopScan"/></summary>
        public bool StopScan()
        {
            AutoResetEvent sync = new AutoResetEvent(false);
            CyApiErr err = CyApiErr.OK;

            // Setup the scan status changed handler
            scanCb.ScanStatusChangedHandler = (status) =>
            {
                if (status != CyScanStatus.STOPPED)
                    err = new CyApiErr("Failed to stop the scan");

                sync.Set();
            };

            err = communicator.BleMgr.StopScan();
            if (err.IsOK)
            {
                if (!sync.WaitOne(1000))
                    return false;
            }

            return err.IsOk;
        }

        /// <summary><see cref="IBleDongle.LastRssi"/></summary>
        public sbyte LastRssi()
        {
            AutoResetEvent sync = new AutoResetEvent(false);
            CyApiErr err = CyApiErr.OK;
            sbyte power = -100;


            bleMgrCb.GetRssiHandler = (rssi, status) =>
            {
                if (status != CyStatus.BLE_STATUS_OK)
                    err = new CyApiErr("Failed to get RSSI");

                power = rssi;

                sync.Set();
            };

            err = communicator.BleMgr.GetRSSI();
            if (err.IsOK)
                sync.WaitOne(1000);

            return power;

        }

        public void Dispose()
        {
            if (communicator != null)
                communicator.Dispose();
        }

        private bool ConnectToDevice(BleAddress address, out ICyBleDevice cyBleDevice)
        {
            CyBleBdAddress deviceAddr;

            AutoResetEvent sync = new AutoResetEvent(false);
            CyApiErr err = CyApiErr.OK;

            deviceAddr = new CyBleBdAddress(address.Address, (CyBleBdAddressType)address.Type);

            bleMgrCb.ConnectionHandler = (result, status) =>
            {
                SetupCulture();
                if (status == CyStatus.BLE_STATUS_OK)
                {
                    peerDevice = result.Device;
                    deviceConnected = true;

                    RegisterDisconnectHandler();
                }
                else
                {
                    string msg = "Failed to connect to the peer device. Reason: " + status.ToString();
                    err = new CyApiErr(msg);
                    deviceConnected = false;
                }

                sync.Set();
            };

            err = communicator.BleMgr.Connect(
                new CyConnectInfo(deviceAddr,
                    new CyBleConnectionSettings(7, 8,
                        CyBleConnectionSettings.DEFAULT_MINIMUM_CE_LENGTH,
                        CyBleConnectionSettings.DEFAULT_MAXIMUM_CE_LENGTH,
                        CyBleConnectionSettings.DEFAULT_INITIATOR_FILTER_POLICY,
                        CyBleConnectionSettings.DEFAULT_INITIATOR_ADDRESS_TYPE,
                        CyBleConnectionSettings.DEFAULT_SLAVE_LATENCY,
                        CyBleConnectionSettings.DEFAULT_SUPERVISION_TIMEOUT,
                        CyBleConnectionSettings.DEFAULT_SCAN_INTERVAL,
                        CyBleConnectionSettings.DEFAULT_SCAN_WINDOW
                    )
                )
             );

            if (err.IsOK)
            {
                if (!sync.WaitOne(1000))
                {
                    communicator.BleMgr.CancelConnection(deviceAddr);
                    cyBleDevice = null;
                    return false; // Time out
                }
            }

            cyBleDevice = peerDevice;
            return deviceConnected;
        }

        /// <summary>
        /// Disconnect from CySmart device. This is only to support GUI's which did not originally use the BleWristband library. 
        /// Not recommended for use, since this exposes a CySmart API class.
        /// </summary>
        /// <param name="device">CyBleDevice</param>
        /// <returns><c>true</c> for success. <c>false</c> for failure.</returns>
        private bool DisconnectFromDevice(ICyBleDevice device)
        {
            AutoResetEvent sync = new AutoResetEvent(false);
            CyApiErr err = CyApiErr.OK;

            bleMgrCb.DisconnectHandler = (addresss, status) =>
            {
                if (status != CyStatus.BLE_STATUS_OK)
                {
                    err = new CyApiErr("Failed to disconnect from peer device. Reason: " + status.ToString());
                }
                else
                {
                    deviceConnected = false;
                }

                sync.Set();
            };

            err = communicator.BleMgr.Disconnect(device);
            if (err.IsOK)
            {
                if (!sync.WaitOne(1000))
                    return false;
            }

            RegisterDisconnectHandler(); // Restore asynchronous disconnect handler for out or range detection

            return err.IsOk;
        }


        private void SetupScanResultHelper()
        {
            scanCb.ScanResultHandler = (result) =>
            {
                string name = "Device";
                CyBleBdAddressType addressType = CyBleBdAddressType.PUBLIC_ADDRESS;

                if (result != null)
                {
                    foreach (var item in result.ScanRecords)
                    {
                        foreach (var bNames in item.AdvertisementData.Items)
                        {
                            if (bNames.Type == CyAdvertisementDataItem.COMPLETE_LOCAL_NAME)
                            {
                                name = System.Text.Encoding.UTF8.GetString(bNames.Data.ToArray(), 0, bNames.Length - 1);
                            }

                            addressType = item.PeerDeviceAddress.AddressType;
                        }

                        if (DeviceFound != null)
                        {
                            DeviceFound(this, new BleDeviceEventArgs()
                                              {
                                                  Address = item.PeerDeviceAddress.Address,
                                                  AddressType = (int)addressType,
                                                  Rssi = item.RSSI,
                                                  Name = name
                                              }
                            );
                        }
                    }
                }
            };
        }

        /// <summary>
        /// Setup CySmart callback threads to use the DefaultThreadCulture. The callback threads needs to respect the 
        /// default so any numeric value strings can be formatted correctly.
        /// </summary>
        private void SetupCulture()
        {
            if (CultureInfo.DefaultThreadCurrentCulture != null)
                Thread.CurrentThread.CurrentCulture = CultureInfo.DefaultThreadCurrentCulture;
        }

        private void RegisterDisconnectHandler()
        {
            // Call back when users request disconnect or when user removes power to evaluation kit
            bleMgrCb.DisconnectHandler = (deviceAddress, status) =>
            {
                if (Disconnected != null)
                {
                    CyBleBdAddressType addressType = deviceAddress.AddressType;
                    Disconnected(this, new BleDeviceEventArgs()
                                       {
                                            Address = deviceAddress.Address,
                                            AddressType = (int)addressType
                                       }
                    );
                }
            };
        }

        #region BleMgrCb

        /// <summary>
        /// BLE manager Callback class
        /// </summary>
        class BleMgrCb : CyBleMgrCallback
        {
            /// <summary>
            /// Gets/Sets the connection handler
            /// </summary>
            public Action<CyConnectResult, CyStatus> ConnectionHandler { get; set; }

            public Action<CyBleBdAddress, CyStatus> DisconnectHandler { get; set; }

            public Action<sbyte, CyStatus> GetRssiHandler { get; set; }

            public override void OnConnected(CyConnectResult result, CyStatus status)
            {
                if (ConnectionHandler != null)
                    ConnectionHandler(result, status);
            }

            public override void OnDisconnected(CyBleBdAddress deviceAddress, CyStatus status)
            {
                if (DisconnectHandler != null)
                    DisconnectHandler(deviceAddress, status);
            }

            public override void OnGetRssi(sbyte rssi, CyStatus status)
            {
                if (GetRssiHandler != null)
                    GetRssiHandler(rssi, status);
            }
        }

        #endregion

        #region ScanCb

        /// <summary>
        /// Scan callback class
        /// </summary>
        class ScanCb : CyScanCallback
        {
            #region props

            /// <summary>
            /// Gets/Sets the scan result handler
            /// </summary>
            public Action<CyScanResult> ScanResultHandler { get; set; }

            /// <summary>
            /// Gets/Sets the scan status changed handler
            /// </summary>
            public Action<CyScanStatus> ScanStatusChangedHandler { get; set; }

            #endregion

            #region overrides

            public override void OnScanResult(CyScanResult result)
            {
                if (ScanResultHandler != null)
                    ScanResultHandler(result);
            }

            public override void OnScanStatusChanged(CyScanStatus scanStatus)
            {
                if (ScanStatusChangedHandler != null)
                    ScanStatusChangedHandler(scanStatus);
            }

            #endregion
        }

        #endregion
    }

    #region DeviceCb

    /// <summary>
    /// Device callback class
    /// </summary>
    class DeviceCb : CyBleDeviceCallback
    {
        // override callback methods if you need to support pairing.
        // Refer to the CySmart API reference guide
    }

    #endregion

    #region GattClientCb

    /// <summary>
    /// GATT client callback class
    /// </summary>
    class GattClientCb : CyGattClientCallback
    {
        /// <summary>
        /// Gets/Sets the descriptor write handler
        /// </summary>
        public Action<CyGattWriteResult, CyStatus> DescriptorWriteHandler { get; set; }

        /// <summary>
        /// Gets/Sets the characteristic changed handler
        /// </summary>
        public Action<CyCharacteristicChangedInfo> CharacteristicChangedHandler { get; set; }

        /// <summary>
        /// Gets/Sets the characteristic write handler
        /// </summary>
        public Action<CyGattWriteResult, CyStatus> CharacteristicWriteHandler { get; set; }

        /// <summary>
        /// Gets/Sets the characteristic read handler
        /// </summary>
        public Action<CyReadCharacteristicByUUIDResult, CyStatus> CharacteristicReadByUUIDHandler { get; set; }
        public Action<CyGattReadResult, CyStatus> CharacteristicReadHandler { get; set; }

        /// <summary>
        /// Get/Sets the Gatt MTU exchange handler
        /// </summary>
        public Action<CyGattExchangeMtuResult, CyStatus> GattMtuExchangedHandler { get; set; }

        public Action<CyDiscoverAllServicesResult, CyStatus> ServiceDiscoveredHandler { get; set; }

        public override void OnDescriptorWrite(CyGattWriteResult result, CyStatus status)
        {
            if (DescriptorWriteHandler != null)
                DescriptorWriteHandler(result, status);
        }

        public override void OnCharacteristicChanged(CyCharacteristicChangedInfo info)
        {
            if (CharacteristicChangedHandler != null)
                CharacteristicChangedHandler(info);
        }

        public override void OnCharacteristicWrite(CyGattWriteResult result, CyStatus status)
        {
            if (CharacteristicWriteHandler != null)
                CharacteristicWriteHandler(result, status);
        }

        public override void OnCharacteristicReadByUUID(CyReadCharacteristicByUUIDResult result, CyStatus status)
        {
            if (CharacteristicReadByUUIDHandler != null)
                CharacteristicReadByUUIDHandler(result, status);
        }

        public override void OnCharacteristicRead(CyGattReadResult result, CyStatus status)
        {
            if (CharacteristicReadHandler != null)
                CharacteristicReadHandler(result, status);
        }

        public override void OnGattMtuExchanged(CyGattExchangeMtuResult result, CyStatus status)
        {
            if (GattMtuExchangedHandler != null)
                GattMtuExchangedHandler(result, status);
        }

        public override void OnServiceDiscovered(CyDiscoverAllServicesResult result, CyStatus status)
        {
            if (ServiceDiscoveredHandler != null)
                ServiceDiscoveredHandler(result, status);
        }

    }

    #endregion

    #region DescriptorCb
    class DescriptorCb : CyDiscoverDescriptorsCallback
    {
        public Action<CyDiscoverDescriptorsResult, CyStatus> DescriptorDiscoveredHandler { get; set; }
        public override void OnDescriptorDiscovered(CyDiscoverDescriptorsResult result, CyStatus status)
        {
            if (DescriptorDiscoveredHandler != null)
                DescriptorDiscoveredHandler(result, status);
        }
    }
    #endregion

    #region PrimaryServiceCb
    class PrimaryServiceCb : CyDiscoverPrimaryServiceCallback
    {
        public Action<List<CyGattService>, CyStatus> PrimaryServiceDiscoveredHandler { get; set; }

        public override void OnPrimaryServiceDiscovered(List<CyGattService> services, CyStatus status)
        {

            if (PrimaryServiceDiscoveredHandler != null)
                PrimaryServiceDiscoveredHandler(services, status);
        }
    }
    #endregion

    #region DiscoverCharacteristicCb
    class DiscoverCharacteristicCb : CyDiscoverCharacteristicsCallback
    {

        public Action<CyDiscoverCharacteristicsResult, CyStatus> CharacteristicDiscoveredHandler { get; set; }
        public override void OnCharacteristicsDiscovered(CyDiscoverCharacteristicsResult result, CyStatus status)
        {
            if (CharacteristicDiscoveredHandler != null)
                CharacteristicDiscoveredHandler(result, status);
        }


    }

    #endregion

}
