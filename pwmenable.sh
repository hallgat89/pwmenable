#!/bin/bash
#
# This script is the result for removing many stuff from pwmconfig.
# It won't do anything besides activating the fans of my Tonga XT / Amethyst XT [Radeon R9 380X / R9 M295X]
# Pwmconfig does something which as a side effect turns my video card fans on, avoiding overheating.
#
# 1. Place the script in the /etc/init.d directory
# 2. chmod 755 myscript
# 3. Once that is done create a symbolic link in the run level directory you would like to use, 
# for example if you wanted to run a program in the graphical runlevel 2, the default runlevel for Ubuntu, you would place it in the /etc/rc2.d
# SXX-is the launch priority
# sudo ln -s /etc/init.d/pwmenable.sh /etc/rc2.d/S99pwmenable.sh
#


if [ "`id -u`" != "0" ]
then
	echo "You need to be root to run this script."
	exit 1
fi

echo 'We will attempt to briefly stop each fan using the pwm controls.'
echo 'The program will attempt to restore each fan to full speed'
echo 'after testing. However, it is ** very important ** that you'
echo 'physically verify that the fans have been to full speed'
echo 'after the program has completed.'
echo

DELAY=5 # 3 seconds delay is too short for large fans, thus I increased it to 5
MAX=255

if [ -d "/sys/class/hwmon" ]
then
	SYSFS=2
	DIR="/sys/class/hwmon"
	PREFIX='hwmon*'
elif [ -d "/sys/bus/i2c/devices" ]
then
	SYSFS=1
	DIR="/sys/bus/i2c/devices"
	PREFIX='*-*'
else
	echo $0: 'No sensors found! (modprobe sensor modules?)'
	exit 1
fi

cd $DIR
DEVICES=`echo $PREFIX`
if [ "$PREFIX" = "$DEVICES" ]
then
	echo $0: 'No sensors found! (modprobe sensor modules?)'
	exit 1
fi

# We may need to adjust the device path
if [ "$SYSFS" = "2" ]
then
	OLD_DEVICES="$DEVICES"
	DEVICES=""

	for device in $OLD_DEVICES
	do
		if [ ! -r "$device/name" ]
		then
			device="$device/device"
		fi
		
		DEVICES="$DEVICES $device"
	done
fi


for device in $DEVICES
do
	# Find available fan control outputs
	MATCH=$device/'pwm[1-9]'
	device_pwm=`echo $MATCH`
	if [ "$SYSFS" = "1" -a "$MATCH" = "$device_pwm" ]
	then
		# Deprecated naming scheme (used in kernels 2.6.5 to 2.6.9)
		MATCH=$device/'fan[1-9]_pwm'
		device_pwm=`echo $MATCH`
	fi
	if [ "$MATCH" != "$device_pwm" ]
	then
		PWM="$PWM $device_pwm"
	fi

	# Find available fan monitoring inputs
	MATCH=$device/'fan[1-9]_input'
	device_fan=`echo $MATCH`
	if [ "$MATCH" != "$device_fan" ]
	then
		FAN="$FAN $device_fan"
	fi
done

if [ -z "$PWM" ]
then
	echo $0: 'There are no pwm-capable sensor modules installed'
	exit 1
fi
if [ -z "$FAN" ]
then
	echo $0: 'There are no fan-capable sensor modules installed'
	exit 1
fi

# $1 = padding
function print_devices()
{
	local name device

	for device in $DEVICES
	do
		name=`cat $device/name 2> /dev/null`
		[ -z "$name" ] && name="unknown (no name attribute)"
		echo "$1$device is $name"
	done
}

# $1 = pwm file name
function is_pwm_auto()
{
	local ENABLE=${1}_enable

	if [ -f $ENABLE ]
	then
		if [ "`cat $ENABLE`" -gt 1 ]
		then
			return 0
		fi
	fi

	return 1
}

# $1 = pwm file name
function pwmdisable()
{
	local ENABLE=${1}_enable

	# No enable file? Just set to max
	if [ ! -f $ENABLE ]
	then
		echo $MAX > $1
		return 0
	fi

	# Try pwmN_enable=0
	echo 0 2>/dev/null > $ENABLE
	if [ "`cat $ENABLE`" -eq 0 ]
	then
		# Success
		return 0
	fi

	# It didn't work, try pwmN_enable=1 pwmN=255
	echo 1 2>/dev/null > $ENABLE
	if [ "`cat $ENABLE`" -ne 1 ]
	then
		echo "$ENABLE stuck to `cat $ENABLE`" >&2
		return 1
	fi

	echo $MAX > $1
	if [ "`cat $1`" -ge 190 ]
	then
		# Success
		return 0
	fi

	# Nothing worked
	echo "$1 stuck to `cat $1`" >&2
	return 1
}

# $1 = pwm file name
function pwmenable()
{
	local ENABLE=${1}_enable

	if [ -w $ENABLE ]
	then
		echo 1 2>/dev/null > $ENABLE
		if [ $? -ne 0 ]
		then
			return 1
		fi
	fi
	echo $MAX > $1
}

# $1 = pwm file name; $2 = pwm value 0-255
function pwmset()
{
	echo $2 > $1
}

echo 'Found the following devices:'
print_devices "   "
echo

echo 'Found the following PWM controls:'
for i in $PWM
do
	P=`cat $i`
	echo "   $i           current value: $P"
	if [ -w $i ]
	then
		# First check if PWM output is in automatic mode
		if is_pwm_auto $i
		then
			echo "$i is currently setup for automatic speed control."			
		fi

		pwmdisable $i  # THE SIDE EFFECT HAPPENS HERE
		if [ $? -ne 0 ]
		then
			echo "Manual control mode not supported, skipping $i."
		elif [ "$GOODPWM" = "" ]
		then
			GOODPWM=$i
		else
			GOODPWM="$GOODPWM $i"
		fi
	else
		echo "Can't write to $i, skipping."
	fi
done

