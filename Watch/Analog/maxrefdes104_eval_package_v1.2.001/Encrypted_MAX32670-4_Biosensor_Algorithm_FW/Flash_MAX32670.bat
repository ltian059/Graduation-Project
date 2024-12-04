@echo off
set /P id=Enter Port: 


download_fw_over_host.exe -f MAX32670_WHRM_AEC_SCD_WSPO2_devel_50.3.0.msbl -p COM%id% -e
@pause