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


#include "algohub_api.h"

#include <string.h>
#include "algohub_config_api.h"
#include "sh_comm.h"

/* Maxim Integrated Low Power SDK  */
#include "mxc_delay.h"
#include "mxc_errors.h"



#define ALGOHUB_REPORT_SIZE_IN_MODE_1		(24u)
#define ALGOHUB_REPORT_SIZE_IN_MODE_2		(24u)

typedef enum {
	ALGOHUB_OPERATING_MODE_1 = 0,
	ALGOHUB_OPERATING_MODE_2,
	ALGOHUB_OPERATING_MODE_MAX,
} algohub_operating_mode_t;

static const uint8_t algohub_reporting_size[ALGOHUB_OPERATING_MODE_MAX] = {ALGOHUB_REPORT_SIZE_IN_MODE_1, ALGOHUB_REPORT_SIZE_IN_MODE_2};

static volatile algohub_operating_mode_t algohub_curr_mode = ALGOHUB_OPERATING_MODE_1;
static uint8_t algohub_soft_ver[3];

static const uint8_t PPG_SIGNAL_CH_PD_TABLE[ALGOHUB_PPG_MAX][2] = {{0,0},{0,1},{1,0},{2,0}};

int algohub_init()
{
	int ret = 0;

	sh_init_hwcomm_interface();

	mxc_delay(MXC_DELAY_SEC(1));

	ret = sh_set_data_type(SS_DATATYPE_BOTH, false);


	if(0 == ret){
		ret = sh_set_fifo_thresh(1);
	}

	if(0 == ret){
		uint8_t algohub_soft_ver_len;
		ret = sh_get_ss_fw_version(algohub_soft_ver, &algohub_soft_ver_len);
	}

	return ret;
}

int algohub_enable()
{
	int ret = 0;

	ret = sh_sensor_enable_(SH_SENSORIDX_ALGOHUB, 1, SH_INPUT_DATA_FROM_HOST);

	return ret;
}

int algohub_disable()
{
	int ret = 0;

	ret = sh_sensor_enable_(SH_SENSORIDX_ALGOHUB, 0, SH_INPUT_DATA_FROM_HOST);

	return ret;
}

int algohub_feed_data(const algohub_feed_data_t * const p_data)
{
	int ret = 0;
	int i = 2;
	int num_wr_bytes;
	uint8_t tx_buf_feed[2 + 24];

	if(NULL == p_data)
	{
		ret = E_BAD_PARAM;
	}

	if(E_NO_ERROR == ret)
	{
		tx_buf_feed[i++] = (p_data->ppg_data_in.green1 >> 16);
		tx_buf_feed[i++] = (p_data->ppg_data_in.green1 >> 8);
		tx_buf_feed[i++] = (p_data->ppg_data_in.green1);

		tx_buf_feed[i++] = (p_data->ppg_data_in.green2 >> 16);
		tx_buf_feed[i++] = (p_data->ppg_data_in.green2 >> 8);
		tx_buf_feed[i++] = (p_data->ppg_data_in.green2);

		tx_buf_feed[i++] = (p_data->ppg_data_in.ir >> 16);
		tx_buf_feed[i++] = (p_data->ppg_data_in.ir >> 8);
		tx_buf_feed[i++] = (p_data->ppg_data_in.ir);

		tx_buf_feed[i++] = (p_data->ppg_data_in.red >> 16);
		tx_buf_feed[i++] = (p_data->ppg_data_in.red >> 8);
		tx_buf_feed[i++] = (p_data->ppg_data_in.red);

		tx_buf_feed[i++] = 0;
		tx_buf_feed[i++] = 0;
		tx_buf_feed[i++] = 0;

		tx_buf_feed[i++] = 0;
		tx_buf_feed[i++] = 0;
		tx_buf_feed[i++] = 0;

		tx_buf_feed[i++] = (p_data->acc_data_in.x >> 8);
		tx_buf_feed[i++] = (p_data->acc_data_in.x);

		tx_buf_feed[i++] = (p_data->acc_data_in.y >> 8);
		tx_buf_feed[i++] = (p_data->acc_data_in.y);

		tx_buf_feed[i++] = (p_data->acc_data_in.z >> 8);
		tx_buf_feed[i++] = (p_data->acc_data_in.z);

		ret = sh_feed_to_input_fifo(tx_buf_feed, sizeof(tx_buf_feed), &num_wr_bytes);
	}

	return ret;
}

int algohub_read_outputfifo(const algohub_report_t * p_result, const int numberResultToBeRead)
{
	int ret = 0;
	int index = 0;
	uint8_t hubStatus;
	uint8_t databuf[256];
	volatile int algo_report_size = 0;

	if(algohub_curr_mode >= ALGOHUB_OPERATING_MODE_MAX)
		ret = E_BAD_STATE;

	if(E_NO_ERROR == ret)
		ret = sh_get_sensorhub_status(&hubStatus);

	if(hubStatus & SS_MASK_STATUS_DATA_RDY)
		ret = 0;
	else
		ret = E_NONE_AVAIL;


	if(E_NO_ERROR == ret)
	{
		algo_report_size = algohub_reporting_size[algohub_curr_mode];

		for(index = 0; index < numberResultToBeRead; index++)
		{
			memset(databuf, 0, sizeof(databuf));
			ret |= sh_read_fifo_data(1, algo_report_size, databuf, sizeof(databuf));

			((algohub_report_t *)(p_result + index))->test_led = (databuf[1] << 16) + (databuf[2] << 8) + (databuf[3]);

			((algohub_report_t *)(p_result + index))->algo.isAfeRequestExist = (databuf[4] & 0x80) >> 7u;
			((algohub_report_t *)(p_result + index))->algo.algoMode = (databuf[4] & 0x7F);

			((algohub_report_t *)(p_result + index))->hr = (databuf[5] << 8) | (databuf[6]);
			((algohub_report_t *)(p_result + index))->hrConfidence = databuf[7];

			((algohub_report_t *)(p_result + index))->rr = (databuf[8] << 8 ) | (databuf[9]);
			((algohub_report_t *)(p_result + index))->rrConfidence = databuf[10];
			((algohub_report_t *)(p_result + index))->activityClass = databuf[11];
			((algohub_report_t *)(p_result + index))->r = (databuf[12] << 8) | (databuf[13]);
			((algohub_report_t *)(p_result + index))->spo2Confidence = databuf[14];
			((algohub_report_t *)(p_result + index))->spo2 = (databuf[15] << 8) | databuf[16];
			((algohub_report_t *)(p_result + index))->spo2PercentComplete = databuf[17];
			((algohub_report_t *)(p_result + index))->spo2LowSignalQualityFlag = databuf[18];
			((algohub_report_t *)(p_result + index))->spo2MotionFlag = databuf[19];
			((algohub_report_t *)(p_result + index))->spo2LowPiFlag = databuf[20];
			((algohub_report_t *)(p_result + index))->spo2UnreliableRFlag = databuf[21];
			((algohub_report_t *)(p_result + index))->spo2State = databuf[22];
			((algohub_report_t *)(p_result + index))->scdSontactState = databuf[23];
			((algohub_report_t *)(p_result + index))->algoRet = databuf[24];

		}
	}

	return ret;
}

int algohub_reset_configs()
{
	int ret = 0;

	ret = ah_set_cfg_wearablesuite_reset_algo_config();

	mxc_delay(MXC_DELAY_MSEC(20));

	return ret;
}

int algohub_notify_afe_request_applied()
{
	return ah_set_cfg_wearablesuite_clear_aferequest(1);
}

int algohub_read_software_version(uint8_t version[3])
{
	memcpy(version, algohub_soft_ver, sizeof(algohub_soft_ver));

	return 0;
}

int algohub_get_aferequest(uint8_t afe_reqs[20])
{
	return ah_get_cfg_wearablesuite_aferequest(afe_reqs);
}

void algohub_parse_aferequest(uint8_t afe_reqs[20], algohub_afe_reqs_t afe[ALGOHUB_PPG_MAX])
{
	int index = 0;

	uint8_t int_req = 0;
	uint8_t avg_req = 0;
	uint8_t dac_req = 0;
	uint16_t led_req = 0;

	memset(afe, 0, sizeof(algohub_afe_reqs_t) * ALGOHUB_PPG_MAX);

	for(index = 0; index < ALGOHUB_PPG_MAX; index++)
	{
		led_req = ((uint16_t)afe_reqs[(index * 5) + 0] << 8) + (uint16_t)afe_reqs[(index * 5) + 1];
		int_req = afe_reqs[(index * 5) + 2];
		avg_req = afe_reqs[(index * 5) + 3];
		dac_req = afe_reqs[(index * 5) + 4];

		((algohub_afe_reqs_t *)(afe + index))->led_curr_adjustment.is_led_curr_update_requested = led_req >> 15;
		((algohub_afe_reqs_t *)(afe + index))->led_curr_adjustment.curr = (led_req & 0x7FFF) / 10;

		((algohub_afe_reqs_t *)(afe + index))->int_time_adjustment.is_int_time_update_requested = int_req >> 7;
		((algohub_afe_reqs_t *)(afe + index))->int_time_adjustment.integration_time = int_req & 0x7F;

		((algohub_afe_reqs_t *)(afe + index))->avg_smp_adjustment.is_avg_smp_update_requested = avg_req >> 7;
		((algohub_afe_reqs_t *)(afe + index))->avg_smp_adjustment.avg_smp = avg_req & 0x7F;

		((algohub_afe_reqs_t *)(afe + index))->dac_offset_adjustment.is_dac_offset_update_requested = dac_req >> 7;
		((algohub_afe_reqs_t *)(afe + index))->dac_offset_adjustment.dac_offset = dac_req & 0x7F;
	}

	return;
}

int algohub_ppg_signal_meas_ch_no(algohub_ppg_singal_type_t ppg_signal)
{
	int ret = 0;
	if(ppg_signal >= ALGOHUB_PPG_MAX)
		ret = -1;

	ret = PPG_SIGNAL_CH_PD_TABLE[ppg_signal][0];
	return ret;
}

int algohub_ppg_signal_pd_no(algohub_ppg_singal_type_t ppg_signal)
{
	int ret = 0;
	if(ppg_signal >= ALGOHUB_PPG_MAX)
		ret = -1;

	ret = PPG_SIGNAL_CH_PD_TABLE[ppg_signal][1];
	return ret;
}

int algohub_send_spi_release_request()
{
	return sh_spi_release();
}

int algohub_notify_spi_released()
{
	return sh_spi_use();
}
