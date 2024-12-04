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

using RD104BleApi.Ble;

namespace RD104BleApi
{
    /// <summary>
    /// MAXREFDES104 Host BLE API Commands Class
    ///
    /// See API documentation for byte and value definitions
    /// </summary>
    public class RD104Api
    {
        object charLock = new object();

        IGattCharacteristic readWriteChar;

        public RD104Api(IGattCharacteristic readWriteChar)
        {
            this.readWriteChar = readWriteChar;
        }

        public RD104ApiFWVersion McuVersionRead()
        {
            var readData = WriteCommandReadResponse(0x00, 0x00);
            ValidateMessageByte(readData[0], 0x00);

            var version = new RD104ApiFWVersion();
            version.Major = readData[1];
            version.Minor = readData[2];
            version.Date = new DateTime(readData[3] << 8 | readData[4], readData[5], readData[6]);
            version.Patch = readData[7];
            version.Released = readData[8];
            version.AlgorithmMajor = readData[9];
            version.AlgorithmMinor = readData[10];
            version.AlgorithmPatch = readData[11];

            return version;
        }

        public void McuEnableSensors(bool enable)
        {
            WriteCommand(0x00, 0x01, 0x00, (byte)(enable ? 1 : 0), 0, 0);
        }

        public bool McuEnableSensorsRead()
        {
            var readData = WriteCommandReadResponse(0x00, 0x01, 0x01);
            ValidateMessageByte(readData[0], 0x02);

            return readData[1] == 1;
        }

        public void McuEnableAccelerometer(bool enable)
        {
            WriteCommand(0x00, 0x05, 0x00, (byte)(enable ? 1 : 0));
        }

        public bool McuEnableAccelerometerRead()
        {
            var readData = WriteCommandReadResponse(0x00, 0x05, 0x01);
            ValidateMessageByte(readData[0], 0x08);
            return readData[1] == 1;
        }

        public RD104ApiBattery McuBatteryRead()
        {
            var readData = WriteCommandReadResponse(0x00, 0x08);
            ValidateMessageByte(readData[0], 0x0D);

            return new RD104ApiBattery()
            {
                Charging = ((readData[1] >> 7) & 1) == 1,
                Percent = readData[1] & 0x7F
            };
        }

        public void McuStatusLed(bool enable)
        {
            WriteCommand(0x00, 0x20, 0x00, (byte)(enable ? 1 : 0));
        }

        public bool McuStatusLedRead()
        {
            var readData = WriteCommandReadResponse(0x00, 0x20, 0x01);
            ValidateMessageByte(readData[0], 0x40);
            return readData[1] == 1;
        }

        public byte AfeReadRegister(byte regAddr)
        {
            return TargetDeviceReadRegister(0x03, regAddr);
        }

        public void AfeReadModifyWriteRegister(byte regAddr, byte stop, byte start, byte value)
        {
            TargetDeviceReadModifyWriteRegister(0x03, regAddr, stop, start, value);
        }

        public byte[] AfeReadRegisterBlock(byte regAddr, byte count)
        {
            return TargetDeviceReadRegisterBlock(0x03, regAddr, count);
        }

        public byte AccelerometerReadRegister(byte regAddr)
        {
            return TargetDeviceReadRegister(0x04, regAddr);
        }

        public void AccelerometerReadModifyWriteRegister(byte regAddr, byte stop, byte start, byte value)
        {
            TargetDeviceReadModifyWriteRegister(0x04, regAddr, stop, start, value);
        }

        public byte[] AccelerometerReadRegisterBlock(byte regAddr, byte count)
        {
            return TargetDeviceReadRegisterBlock(0x04, regAddr, count);
        }

        public byte TemperatureReadRegister(byte regAddr)
        {
            return TargetDeviceReadRegister(0x28, regAddr);
        }

        public void TemperatureReadModifyWriteRegister(byte regAddr, byte stop, byte start, byte value)
        {
            TargetDeviceReadModifyWriteRegister(0x28, regAddr, stop, start, value);
        }

        public byte[] TemperatureReadRegisterBlock(byte regAddr, byte count)
        {
            return TargetDeviceReadRegisterBlock(0x28, regAddr, count);
        }

        public void AlgorithmMode(byte mode)
        {
            WriteCommand(0x27, 0x01, 0xFF, 1, mode);
        }

        public byte AlgorithmModeRead()
        {
            var readData = WriteCommandReadResponse(0x27, 0x01, 0xFF, 0);
            return readData[4];
        }

        public void AlgorithmAfeControl(byte control)
        {
            WriteCommand(0x27, 0x02, 0xFF, 1, control);
        }

        public byte AlgorithmAfeControlRead()
        {
            var readData = WriteCommandReadResponse(0x27, 0x02, 0xFF, 0);
            return readData[4];
        }

        public void AlgorithmAecIntegrationTime(byte subCommand, byte value)
        {
            WriteCommand(0x27, 0x03, subCommand, 1, value);
        }

        public byte AlgorithmAecIntegrationTimeRead(byte subCommand)
        {
            var readData = WriteCommandReadResponse(0x27, 0x03, subCommand, 0);
            return readData[4];
        }

        public void AlgorithmAecSamplingFramerateAveraging(byte subCommand, byte value)
        {
            WriteCommand(0x27, 0x03, subCommand, 1, value);
        }

        public byte AlgorithmAecSamplingFrameRateAveragingRead(byte subCommand)
        {
            var readData = WriteCommandReadResponse(0x27, 0x03, subCommand, 0);
            return readData[4];
        }

        public void AlgorithmAecPDCurrent(byte subCommand, byte value)
        {
            WriteCommand(0x27, 0x03, subCommand, 1, 0xFF, value);
        }

        public byte AlgorithmAecPDCurrentRead(byte subCommand)
        {
            var readData = WriteCommandReadResponse(0x27, 0x03, subCommand, 0, 0xFF);
            return readData[5];
        }

        public void AlgorithmAecTargetPDCurrent(byte subCommand, byte value)
        {
            WriteCommand(0x27, 0x03, subCommand, 1, 0xFF, value);
        }

        public byte AlgorithmAecTargetPDCurrentRead(byte subCommand)
        {
            var readData = WriteCommandReadResponse(0x27, 0x03, subCommand, 0, 0xFF);
            return readData[5];
        }

        public void AlgorithmAecTargetPDCurrentPeriod(byte value)
        {
            WriteCommand(0x27, 0x03, 0x08, 1, 0xFF, value);
        }

        public byte AlgorithmAecTargetPDCurrentPeriodRead()
        {
            var readData = WriteCommandReadResponse(0x27, 0x03, 0x08, 0, 0xFF);
            return readData[5];
        }

        public void AlgorithmAecMotionDectionThreshold(byte value)
        {
            WriteCommand(0x27, 0x03, 0x09, 1, 0xFF, value);
        }

        public byte AlgorithmAecMotionDetectionThresholdRead()
        {
            var readData = WriteCommandReadResponse(0x27, 0x03, 0x09, 0, 0xFF);
            return readData[5];
        }

        public void AlgorithmAecDacOffset(byte channel, byte ppg1Offset, byte ppg2Offset)
        {
            WriteCommand(0x27, 0x03, 0x0A, 1, channel, ppg1Offset, ppg2Offset);
        }

        public void AlgortihmAecDacOffset(RD104ApiDacOffset dacOffset)
        {
            AlgorithmAecDacOffset((byte)dacOffset.Channel, (byte)dacOffset.Ppg1DacOffset, (byte)dacOffset.Ppg2DacOffset);
        }

        public RD104ApiDacOffset AlgorithmAecDacOffsetRead(byte channel, byte ppg1Offset, byte ppg2Offset)
        {
            var readData = WriteCommandReadResponse(0x27, 0x03, 0x0A, 0);
            return new RD104ApiDacOffset()
            {
                Channel = readData[4],
                Ppg1DacOffset = readData[5],
                Ppg2DacOffset = readData[6],
            };
        }

        public void AlgorithmAgcHRTargetPDCurrent(byte value)
        {
            WriteCommandReadResponse(0x27, 0x04, 0x0B, 1, 0xFF, value);
        }

        public byte AlgorithmAgcHRTargetPDCurrentRead()
        {
            var readData = WriteCommandReadResponse(0x27, 0x04, 0x0B, 0, 0xFF);
            return readData[5];
        }

        public void AlgorithmScdEnable(bool enable)
        {
            WriteCommandReadResponse(0x27, 0x06, 0x00, 1, (byte)(enable ? 1 : 0));
        }

        public bool AlgorithmScdEnableRead()
        {
            var readData = WriteCommandReadResponse(0x27, 0x06, 0x00, 0);
            return readData[4] == 1;
        }

        public void AlgorithmSpO2Averaging(byte subCommand, byte value)
        {
            WriteCommand(0x27, 0x07, subCommand, 1, value);
        }

        public byte AlgorithmSpO2AveargingRead(byte subCommand)
        {
            var readData = WriteCommandReadResponse(0x27, 0x07, subCommand, 0);
            return readData[4];
        }

        public void AlgorithmOperationMode(byte mode)
        {
            WriteCommandReadResponse(0x27, 0xFE, 0xFF, 1, mode);
        }

        public byte AlgorithmOperationModeRead()
        {
            var readData = WriteCommandReadResponse(0x27, 0xFE, 0xFF, 0);
            return readData[4];
        }

        public void WriteCommand(params byte[] command)
        {
            readWriteChar.Write(command);
        }

        public byte[] WriteCommandReadResponse(params byte[] command)
        {
            byte[] response;

            lock (charLock)
            {
                readWriteChar.Write(command);
                response = readWriteChar.Read();
            }

            return response;
        }

        private byte TargetDeviceReadRegister(byte targetDevice, byte regAddr)
        {
            var readData = WriteCommandReadResponse(targetDevice, 0x00, regAddr, 1);
            ValidateMessageByte(readData[0], 0x04);

            return readData[4];
        }

        private void TargetDeviceReadModifyWriteRegister(byte targetDevice, byte regAddr, byte stop, byte start, byte value)
        {
            WriteCommand(targetDevice, 0x01, regAddr, stop, start, value);
        }

        private byte[] TargetDeviceReadRegisterBlock(byte targetDevice, byte regAddr, byte count)
        {
            if (count > 17)
                throw new BleException("Read register block limited to 17 or less.");

            var readData = WriteCommandReadResponse(targetDevice, 0x02, regAddr, count);
            ValidateMessageByte(readData[0], 0x12);

            byte[] data = new byte[count];
            for (int i = 0; i < count; i++)
            {
                data[i] = readData[i + 3];
            }

            return data;
        }

        private static void ValidateMessageByte(byte actual, byte expected)
        {
            if (actual != expected)
                throw new BleException("Response byte is " + actual.ToString("X02") + ", expected " + expected.ToString("X02"));
        }
    }
}
