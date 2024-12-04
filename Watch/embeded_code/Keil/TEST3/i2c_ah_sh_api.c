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




#include "i2c_ah_sh_api.h"

#include <stdio.h>
#include <string.h>

/* Maxim Integrated Low Power SDK */
//#include "mxc_config.h"
#include "i2c.h"
#include "defs.h"


/***** Definitions *****/
#define I2C_MASTER	    		MXC_I2C2_BUS0
#define MXC_I2C_FAST_MODE 1

int I2C_MasterWrite(mxc_i2c_regs_t* i2c, uint8_t slave_addr, uint8_t* data, int length, int stop)
{
    int ret;
    
    unsigned int tx_len = length;
    
    // Send the I2C start condition
    ret = MXC_I2C_Start(i2c);
    if (ret != E_NO_ERROR) {
        return ret;  // Failed to send start condition
    }
    
    // Set the I2C slave address
    ret = MXC_I2C_SetSlaveAddr(i2c, slave_addr, 0);  // Address of the target slave device
    if (ret != E_NO_ERROR) {
        MXC_I2C_Stop(i2c);  // Stop the I2C bus in case of failure
        return ret;  //  Failed to set the slave address
    }
    
   
    
    // Write data to the I2C bus
    ret = MXC_I2C_Write(i2c, data, &tx_len);
    
    if (ret != E_NO_ERROR || tx_len != length) {
        MXC_I2C_Stop(i2c);
        return -1;  // Failed to write data or mismatch in data length
    }
    
    if(stop){
        ret = MXC_I2C_Stop(i2c);
        if (ret != E_NO_ERROR) {
            return ret;  // Failed to send stop condition
        }
    }
    
    // Return the number of bytes successfully written
    return tx_len;
}

int I2C_MasterRead(mxc_i2c_regs_t *i2c, uint8_t slave_addr, uint8_t *data, int length, int stop){
    int ret;
    unsigned int rx_len = length;
    
    // Send the I2C start condition
    ret = MXC_I2C_Start(i2c);
    if (ret != E_NO_ERROR) {
        return ret;  // Failed to send start condition
    }
    
    // Set the I2C slave address for a read operation 
    ret = MXC_I2C_SetSlaveAddr(i2c, slave_addr, 1);  // 1 as index
    if (ret != E_NO_ERROR) {
        MXC_I2C_Stop(i2c);  // Stop the I2C bus in case of failure
        return ret;  // Failed to set the slave address
    }
    
    // Read data from the I2C bus
    ret = MXC_I2C_Read(i2c, data, &rx_len, 0);
    if (ret != E_NO_ERROR || rx_len != length) {
        MXC_I2C_Stop(i2c);  // Stop the I2C bus in case of failure
        return -1;  // Failed to read data or mismatch in data length
    }
    
    // Send stop condition
    if (stop) {
        ret = MXC_I2C_Stop(i2c);
        if (ret != E_NO_ERROR) {
            return ret;  // Failed to send stop condition
        }
    }
    
    // Return the number of bytes successfully read
    return rx_len;

}
int i2c_init()
{
	int ret = 0;

    //Setup the I2CM
    ret = MXC_I2C_Shutdown(I2C_MASTER);
    pr_info("MXC_I2C_Shutdown %d \n", ret);

    if(0 == ret){
    	ret = MXC_I2C_Init(I2C_MASTER, MXC_I2C_FAST_MODE , NULL);
    	pr_info("MXC_I2C_Init %d \n", ret);
    }

    if(0 == ret)
    	NVIC_EnableIRQ(I2C2_IRQn);

    return ret;
}

int i2c_write(uint8_t addr, const char * p_data, int length, bool restart)
{
	int ret = 0;
    
	ret = I2C_MasterWrite(I2C_MASTER, addr, (uint8_t *)p_data, length, (int)restart);

  
    
	if(ret == length)
		return 0;
	else
		return -1;
    
}

int i2c_read(uint8_t addr, char * p_data, int length, bool restart)
{
	int ret = 0;

	ret =  I2C_MasterRead(I2C_MASTER, addr, (uint8_t *)p_data, length, (int)restart);

	if(ret == length)
		return 0;
	else
		return -1;
}

void i2c_close()
{
    MXC_I2C_Shutdown(I2C_MASTER);
}
