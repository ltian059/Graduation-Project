/*******************************************************************************
* Copyright (C) 2018 Maxim Integrated Products, Inc., All rights Reserved.
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

#include <stdio.h>
#include <string.h>
#include <stdint.h>

#include "defs.h"

#include "algohub_api.h"
#include "algohub_config_api.h"

#include "sensorhub_api.h"
#include "sensorhub_config_api.h"

#define DUMMY_PPG_DATA      (8517u)
#define DUMMY_ACC_X_DATA    (100u)
#define DUMMY_ACC_Y_DATA    (150u)
#define DUMMY_ACC_Z_DATA    (-800)

int demoAlgohub()
{
    uint8_t afereqs[20];
    algohub_feed_data_t algohub_in;
    algohub_report_t algohub_out;
    int ret = 0;

    memset(&algohub_in, 0, sizeof(algohub_feed_data_t));
    memset(&algohub_out, 0, sizeof(algohub_report_t));
    memset(afereqs, 0, sizeof(afereqs));

    ret = algohub_init();
    pr_info("algohub_init ret %d \n", ret);

    ret = algohub_enable();
    pr_info("algohub_enable ret %d \n", ret);

    while(1)
    {
    	/* Wait for PPG Frame (PPG Frame Rate: 25Hz) */

        algohub_in.ppg_data_in.green1 = DUMMY_PPG_DATA;
		algohub_in.ppg_data_in.green2 = DUMMY_PPG_DATA;
		algohub_in.ppg_data_in.ir = DUMMY_PPG_DATA;
		algohub_in.ppg_data_in.red = DUMMY_PPG_DATA;

		algohub_in.acc_data_in.x = DUMMY_ACC_X_DATA;
		algohub_in.acc_data_in.y = DUMMY_ACC_Y_DATA;
		algohub_in.acc_data_in.z = DUMMY_ACC_Z_DATA;

        ret = algohub_feed_data(&algohub_in);
        pr_info("algohub_feed_data ret %d \n", ret);

        if(0 == ret)
        {   
            WAIT_MS(5);
            ret = algohub_read_outputfifo(&algohub_out, 1);
            pr_info("algohub_read_outputfifo ret %d \n", ret);
        }

        if(0 == ret)
        {
            /* Read if there is AFE request */
            if(algohub_out.algo.isAfeRequestExist)
			{
                ret = ah_get_cfg_wearablesuite_aferequest(afereqs);
                pr_info("ah_get_cfg_wearablesuite_aferequest ret %d \n", ret);

                /* Apply AFE Requests */


                /* Notify algohub that AFE requests has been applied */
                ret = ah_set_cfg_wearablesuite_clear_aferequest(1);
                pr_info("ah_set_cfg_wearablesuite_clear_aferequest ret %d \n", ret);

            }

            pr_info("HR %d SpO2 %d \n",  algohub_out.hr, algohub_out.spo2);
        }

    }
}

int demoSensorhub()
{
	int ret = 0;
	sensorhub_output sensorhub_out;

	memset(&sensorhub_out, 0, sizeof(sensorhub_output));

	ret = sensorhub_interface_init();
	pr_info("sensorhub_interface_init ret %d \n", ret);

	ret = sensorhub_enable_sensors();
	pr_info("sensorhub_enable_sensors ret %d \n", ret);

	ret = sensorhub_enable_algo(SENSORHUB_MODE_BASIC);
	pr_info("sensorhub_enable_algo ret %d \n", ret);

    while(1)
    {
    	ret = sensorhub_get_result(&sensorhub_out);
    	pr_info("sensorhub_get_result ret %d \n", ret);

    	if(0 == ret)
    	{
    		 pr_info("HR %d SpO2 %d \n",  sensorhub_out.algo_data.hr, sensorhub_out.algo_data.spo2);
    	}
    }
}
