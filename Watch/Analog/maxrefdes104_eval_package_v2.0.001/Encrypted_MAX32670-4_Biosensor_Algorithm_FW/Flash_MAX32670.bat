@echo off
set /P id=Enter Port: 


download_fw_over_host.exe -f MAX32670_WHRM_AEC_SCD_WSPO2_devel_50.4.2.msbl -p COM%id% -e
@pause