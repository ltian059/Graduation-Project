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
    public class NotifyPpgData
    {
        public MeasData[] MeasData { get; set; }
        public double[] AccelerometerX { get; set; }
        public double[] AccelerometerY { get; set; }
        public double[] AccelerometerZ { get; set; }

        public static NotifyPpgData PpgParse(List<byte> notifyPayload, int frames, int measCount, int pdCount, bool accelInPacket)
        {
            var npd = new NotifyPpgData();
            npd.MeasData = new MeasData[measCount];

            int byteCount = 0;

            for (int m = 0; m < measCount; m++)
            {
                npd.MeasData[m] = new MeasData(frames);
                for (int f = 0; f < frames; f++)
                {
                    int ppgRaw1 = notifyPayload[byteCount++] << 16 | notifyPayload[byteCount++] << 8 | notifyPayload[byteCount++];
                    npd.MeasData[m].PD1[f] = PpgRawConversion(ppgRaw1);
                    npd.MeasData[m].PD1Tag[f] = PpgTag(ppgRaw1);

                    if (pdCount == 2)
                    {
                        int ppgRaw2 = notifyPayload[byteCount++] << 16 | notifyPayload[byteCount++] << 8 | notifyPayload[byteCount++];
                        npd.MeasData[m].PD2[f] = PpgRawConversion(ppgRaw2);
                        npd.MeasData[m].PD2Tag[f] = PpgTag(ppgRaw2);
                    }
                }
            }

            if (pdCount == 1 && measCount == 5)
            {
                byteCount += 3; // Special case, 3 byte offset between PPG and Accel data
            }

            if (accelInPacket)
            {
                npd.AccelerometerX = new double[frames];
                npd.AccelerometerY = new double[frames];
                npd.AccelerometerZ = new double[frames];

                for (int f = 0; f < frames; f++)
                {
                    npd.AccelerometerX[f] = ((short)(notifyPayload[byteCount++] << 8 | notifyPayload[byteCount++])) / 1000.0;
                    npd.AccelerometerY[f] = ((short)(notifyPayload[byteCount++] << 8 | notifyPayload[byteCount++])) / 1000.0;
                    npd.AccelerometerZ[f] = ((short)(notifyPayload[byteCount++] << 8 | notifyPayload[byteCount++])) / 1000.0;
                }
            }

            return npd;
        }

        /// <summary>
        /// PPG raw code from FIFO to PPG count conversion
        /// </summary>
        /// <param name="opticalRaw">PPG raw code from AFE FIFO</param>
        /// <returns>PPG count</returns>
        public static int PpgRawConversion(int opticalRaw)
        {
            int shift = 32 - 20;
            return (opticalRaw << shift) >> shift; // Two's complement conversion
        }

        /// <summary>
        /// PPG tag field from PPG raw code
        /// </summary>
        /// <param name="opticalRaw">PPG raw code from AFE FIFO</param>
        /// <returns></returns>
        public static int PpgTag(int opticalRaw)
        {
            return opticalRaw >> 20;
        }
    }

    /// <summary>
    /// MeasData class stores multiple frames of PPG data
    /// </summary>
    public class MeasData
    {
        public MeasData(int frameCount)
        {
            PD1 = new int[frameCount];
            PD1Tag = new int[frameCount];
            PD2 = new int[frameCount];
            PD2Tag = new int[frameCount];
        }

        public int[] PD1 { get; set; }
        public int[] PD1Tag { get; set; }
        public int[] PD2 { get; set; }
        public int[] PD2Tag { get; set; }
    }
}
