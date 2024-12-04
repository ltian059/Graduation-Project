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

namespace RD104BleApi.Ble
{
    /// <summary>
    /// BLE helper methods
    /// </summary>
    public class BleUtility
    {
        /// <summary>
        /// Convert address in byte array format to ulong
        /// </summary>
        /// <param name="address">array</param>
        /// <returns>address in ulong</returns>
        public static ulong AddressFromByteArray(byte[] address)
        {
            ulong addr = 0;
            if (address.Length == 6)
            {
                for (int i = 0; i < 6; i++)
                {
                    addr = (addr << 8) | address[i];
                }
            }

            return addr;
        }

        /// <summary>
        /// Convert byte array uuid to string
        /// </summary>
        /// <param name="uuid128">byte array</param>
        /// <returns>string</returns>
        public static string ConvertUuid(byte[] uuid128)
        {
            //Simple testing utility to make UUIDs more readable 

            string uuid = "";

            for (int i = 0; i < 16; i++)
            {
                uuid += uuid128[15 - i].ToString("X2");
            }

            return uuid;
        }

        /// <summary>
        /// Convert uuid string to byte array
        /// </summary>
        /// <param name="uuid">string</param>
        /// <returns>byte array</returns>
        public static byte[] UuidConvert(string uuid)
        {
            Stack<byte> uuidList = new Stack<byte>();


            //Original code
            //string id = uuid.Trim(new char[] {'-', ' '});
            string id = uuid.Replace("-", "");
            id = id.Replace(" ", "");

            for (int i = 0; i < id.Length; i += 2)
            {
                string subString = id.Substring(i, 2);
                byte value = Byte.Parse(subString, System.Globalization.NumberStyles.HexNumber);
                uuidList.Push(value);
            }

            byte[] bytes = new byte[uuidList.Count];

            //Original code kept shrinking uuidList by using the pop operation, need a fixed size
            //Fix below
            int uuidListSize = uuidList.Count;

            for (int i = 0; i < uuidListSize; i++)
            {
                bytes[i] = uuidList.Pop();
            }

            return bytes;
        }
    }
}
