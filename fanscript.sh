#!/bin/bash

#Fancontrol from lm-sensors doesn't work on my old Dell machine, so 
#I'm writing my own solution tailored to my hardware.
#
#All temperatures are in Celcius x 100, as per lm-sensors spec
#This script is dependent on lm-sensors

#Globals
DEBUG=0;
SELF_TEST_MODE=0;

CONTROL_CASE_FAN=0;

CPU_TEMP_FILE[0]="/sys/class/hwmon/hwmon1/temp2_input"
CPU_TEMP_FILE[1]="/sys/class/hwmon/hwmon1/temp3_input"
CPU_TEMP_FILE[2]="/sys/class/hwmon/hwmon1/temp4_input"
CPU_TEMP_FILE[3]="/sys/class/hwmon/hwmon1/temp5_input"

CPU_FAN_PWM_FILE="/sys/class/hwmon/hwmon0/pwm1"
CASE_FAN_PWM_FILE="/sys/class/hwmon/hwmon0/pwm2"

MIN_PWM=40
MAX_PWM=255

LOW_TEMP=40000
HIGH_TEMP=70000

FILE_RW_ATTEMPTS=5

#In seconds
REFRESH_RATE=1

#Data frame
CPU_TEMP=-9999
TARGET_FAN_PWM=255

function debugWrite {
	if [ $DEBUG -eq 1 ]; then
		echo $1
	fi
}

function readTemps {
	local highestTemp=-9999
	for i in `seq 0 3`; do
		local attempts=0
		local curCoreTemp=-9999
		while [ $attempts  -lt $FILE_RW_ATTEMPTS ]; do
			read -r curCoreTemp<${CPU_TEMP_FILE[${i}]}
			if [ $curCoreTemp -ne -9999 ]; then
				if [ $curCoreTemp -gt $highestTemp ]; then
					highestTemp=$curCoreTemp
				fi
				break
			fi
			attempts=$(($attempts + 1))
		done
	done

	CPU_TEMP=$highestTemp
	debugWrite "CPU Temp: ${CPU_TEMP}"
	#If CPU_TEMP == -9999, there's been a read error for all core temps
}

function calculatePWM {
	if [ $CPU_TEMP -eq -9999 ]; then
		TARGET_FAN_PWM=$MAX_PWM
		debugWrite "Temp read error! Maxing fan"
	else
		if [ $CPU_TEMP -le $LOW_TEMP ]; then
			TARGET_FAN_PWM=$MIN_PWM
			debugWrite "Minimum fan speed mode"
		else
			if [ $CPU_TEMP -ge $HIGH_TEMP ]; then
				TARGET_FAN_PWM=$MAX_PWM
				debugWrite "Maximum fan speed mode"
			else
				local tempAsPercent=$(((${CPU_TEMP} - ${LOW_TEMP}) / ((${HIGH_TEMP} - ${LOW_TEMP}) / 100)))
				#2nd order function for fan curve
				TARGET_FAN_PWM=$((((${tempAsPercent}**2) / ${SCALAR}) + $MIN_PWM))
			fi
		fi
	fi
}

function writePWMHelper {
	local attempts=0
	while [ $attempts -lt $FILE_RW_ATTEMPTS ]; do
		if echo $TARGET_FAN_PWM >> $1; then
			debugWrite "Wrote ${TARGET_FAN_PWM} to ${1}"
			break
		else
			debugWrite "Could not write to PWM file"
		fi
		attempts=$(($attempts + 1))
	done
}

function writePWM {
	writePWMHelper $CPU_FAN_PWM_FILE
	if [ $CONTROL_CASE_FAN -eq 1 ]; then
		writePWMHelper $CASE_FAN_PWM_FILE
	fi
}

function mainLoop {
	while true; do
		readTemps

		calculatePWM

		writePWM

		sleep $REFRESH_RATE
	done
}

function selfTest {
	for i in `seq 0 100`; do
		CPU_TEMP=$(($i *  1000))

		calculatePWM

		echo For temperature $CPU_TEMP
		echo PWM $TARGET_FAN_PWM
	done
}

SCALAR=$((10000/(MAX_PWM - MIN_PWM)))

if [ $SELF_TEST_MODE -eq 1 ]; then
	selfTest
else
	mainLoop
fi
