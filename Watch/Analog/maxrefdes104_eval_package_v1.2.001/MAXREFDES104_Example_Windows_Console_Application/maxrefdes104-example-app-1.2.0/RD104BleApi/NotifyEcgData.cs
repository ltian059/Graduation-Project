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

namespace RD104BleApi
{
    public class NotifyEcgData
    {
        public EcgData[] EcgData { get; set; }
        public double[] AccelerometerX { get; set; }
        public double[] AccelerometerY { get; set; }
        public double[] AccelerometerZ { get; set; }

        public static int EcgRawConversion(int ecgRaw)
        {
            int shift = 32 - 18;
            return ((int)(ecgRaw << shift)) >> shift; // Two's complement conversion
        }

        public static int EcgTag(int ecgRaw)
        {
            return ecgRaw >> 18;
        }

        public static NotifyEcgData EcgParse(List<byte> notifyPayload, bool accelInPacket)
        {
            var ned = new NotifyEcgData();

            int samples = accelInPacket ? 2 : 6;
            int accelChannels = accelInPacket ? 3 : 6;

            int byteCount = 0;

            ned.EcgData = new EcgData[samples];
            for (int i = 0; i < samples; i++)
            {
                ned.EcgData[i] = new EcgData();
                int ecgRaw = notifyPayload[byteCount++] << 16 | notifyPayload[byteCount++] << 8 | notifyPayload[byteCount++];
                ned.EcgData[i].Ecg = EcgRawConversion(ecgRaw);
                ned.EcgData[i].EcgTag = EcgTag(ecgRaw);
            }

            if (accelInPacket)
            {
                ned.AccelerometerX = new double[samples];
                ned.AccelerometerY = new double[samples];
                ned.AccelerometerZ = new double[samples];

                for (int i = 0; i < samples; i++)
                {
                    // Two's complement conversion
                    ned.AccelerometerX[i] = ((short)(notifyPayload[byteCount++] << 8 | notifyPayload[byteCount++])) / 1000.0;
                    ned.AccelerometerY[i] = ((short)(notifyPayload[byteCount++] << 8 | notifyPayload[byteCount++])) / 1000.0;
                    ned.AccelerometerZ[i] = ((short)(notifyPayload[byteCount++] << 8 | notifyPayload[byteCount++])) / 1000.0;
                }
            }

            return ned;
        }
    }

    public class EcgData
    {
        public int Ecg { get; set; }
        public int EcgTag { get; set; }
    }
}
