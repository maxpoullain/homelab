#!/bin/bash
# Script: my-pi-temp.sh
# Purpose: Display the ARM CPU and GPU  temperature of Raspberry Pi 2/3
# Author: Vivek Gite <www.cyberciti.biz> under GPL v2.x+
# -------------------------------------------------------
cpu=$(</sys/class/thermal/thermal_zone0/temp)
echo "$(date) @ $(hostname)"
echo "-------------------------------------------"
echo "CPU Freq => $(vcgencmd measure_clock arm | sed -e 's/frequency(48)=//g')"
echo "CPU Temp => $((cpu/1000))'C"
echo "GPU Temp => $(vcgencmd measure_temp | sed -e 's/temp=//g')"
