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
    public class NotifyAlgorithmData
    {
        public int AlgoMode { get; private set; }
        public double HeartRate { get; private set; }
        public int HeartRateConfidence { get; private set; }
        public double RRInterval { get; private set; }
        public int RRConfidence { get; private set; }
        public int SpO2 { get; private set; }
        public int SpO2Confidence { get; private set; }
        public double RValue { get; private set; }
        public int SpO2Complete { get; private set; }
        public int SpO2State { get; private set; }
        public int Activity { get; private set; }
        public int ScdState { get; private set; }
        public int Flags { get; private set; }

        public bool LowSnr { get { return (Flags & 1) == 1; } }
        public bool Motion { get { return ((Flags >> 1) & 1) == 1; } }
        public bool LowPI { get { return ((Flags >> 2) & 1) == 1; } }
        public bool UnreliableR { get { return ((Flags >> 3) & 1) == 1; } }

        public static NotifyAlgorithmData Parse(List<byte> payLoadData)
        {
            var nad = new NotifyAlgorithmData();

            int i = 0;
            nad.AlgoMode = payLoadData[i++];
            nad.HeartRate = payLoadData[i++];
            nad.HeartRateConfidence = payLoadData[i++];
            nad.RRInterval = payLoadData[i++] << 8 | payLoadData[i++];
            nad.RRConfidence = payLoadData[i++];
            nad.SpO2 = payLoadData[i++];
            nad.SpO2Confidence = payLoadData[i++];
            nad.RValue = payLoadData[i++] << 8 | payLoadData[i++];
            nad.SpO2Complete = payLoadData[i++];
            nad.SpO2State = payLoadData[i++];
            nad.Activity = payLoadData[i++];
            nad.ScdState = payLoadData[i++];
            nad.Flags = payLoadData[i++];

            return nad;
        }
    }
}
