#!/bin/bash

#!/bin/bash
#
# This script was designt to control the fans of my Tonga XT / Amethyst XT [Radeon R9 380X / R9 M295X]
# If you use it without thinking, and your computer melts, it is your own fault.
#
# 1. Place the script in the /etc/init.d directory
# 2. chmod 755 myscript
# 3. Once that is done create a symbolic link in the run level directory you would like to use, 
# for example if you wanted to run a program in the graphical runlevel 2, the default runlevel for Ubuntu, you would place it in the /etc/rc2.d
# SXX-is the launch priority
# sudo ln -s /etc/init.d/pwmenable.sh /etc/rc2.d/S99pwmenable.sh
#

### BEGIN INIT INFO
# Provides:          pwmenable.sh
# Required-Start:    $local_fs $syslog $remote_fs dbus
# Required-Stop:     $local_fs $syslog $remote_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Set pwm 137 for Radeon R9 380X
# Description:       Set pwm 137 for Radeon R9 380X
### END INIT INFO


# data update frequency (sec)
LOOP=4

# ideal temperature (celsius)
HTEMP=50

# low temperature (celsius)
LTEMP=35

# temperature name used by sensors
TEMPNAME='temp1'

# from command sensors
HARDWARENAME='amdgpu-pci-0100'

# hwmon root
HWMONROOT='/sys/class/hwmon'

# hwmonid you want to control
HWMON='hwmon0'

# pwmid
PWMID='pwm1'

# log (0,1,2)
LOG=1

if [ "`id -u`" != "0" ]
then
	echo "You need to be root to run this script."
	exit 1
fi

# pwm file, contains a number
PWMF=$HWMONROOT"/"$HWMON"/"$PWMID

# file, contains 0 or 1
PWMENABLEF=$HWMONROOT"/"$HWMON"/"$PWMID"_enable"

PWM=0; # will hold the curretn pwm value (0-255)
PWMENABLE=0; # will hold the current enable value  (0-1)
CTEMP=0; # will hold current temp


if [ -f $PWMF ]
then
	echo "Monitoring $PWMF"
else
	echo "$PWMF cannot be found"
	exit 1
fi

if [ -f $PWMENABLEF ]
then
	PWM=`cat $PWMF`
	PWMENABLE=`cat $PWMENABLEF`
	CTEMP=`sensors amdgpu-pci-0100 | grep $TEMPNAME | cut -d'+' -f2 | cut -d'.' -f1`
else
	echo "$PWMENABLEF cannot be found"
    exit 1
fi

# CONFIG READY
echo "Starting write tests"
echo 1 2>/dev/null > $PWMENABLEF
SUM=$?
echo 0 2>/dev/null > $PWMF
SUM=$(($SUM+$?))

if [ "$SUM" -ne "0" ]
then
	echo "Write tests failed."
	exit 1 
fi

PWMENABLE=`cat $PWMENABLEF`
echo "Write tests succesful."
echo "Loglevel: $LOG"
PWM=`cat $PWMF`
PWMENABLE=`cat $PWMENABLEF`
CTEMP=`sensors amdgpu-pci-0100 | grep $TEMPNAME | cut -d'+' -f2 | cut -d'.' -f1`
echo "INITIAL STATS:"
echo "$PWMID enable: $PWMENABLE"
echo "$PWMID: $PWM"
echo "$TEMPNAME: $CTEMP Celsius"
echo

TEMPSTATUS='unknown'
LASTTEMP=0
NEWPWM=0

while [ 1 -eq 1 ]
do

	PWM=`cat $PWMF`
	CTEMP=`sensors amdgpu-pci-0100 | grep $TEMPNAME | cut -d'+' -f2 | cut -d'.' -f1`
	
	if [ "$LASTTEMP" -eq "$CTEMP"  ]
	then
		TEMPSTATUS='stagn'
	fi
	
	if [ "$LASTTEMP" -lt "$CTEMP" ]
	then
		TEMPSTATUS='inc'
	fi
	
	if [ "$LASTTEMP" -gt "$CTEMP" ]
	then
		TEMPSTATUS='dec'
	fi
	
	LASTTEMP=$CTEMP
	
	if [ "$LOG" -gt "1" ]
	then
		echo
		echo "$PWMID: $PWM"
		echo "$TEMPNAME: $CTEMP Celsius $TEMPSTATUS"
	fi
	
	# if temp too high -> wents up
	if [ "$CTEMP" -gt "$HTEMP" ] && [ "$TEMPSTATUS" != "dec" ] 
	then
		if [ "$NEWPWM" -ne "255" ]
		then
			NEWPWM=255 #max
			echo $NEWPWM 2>/dev/null > $PWMF
			PWM=`cat $PWMF`		
			if [ "$LOG" -gt "0" ]
			then
				echo "temperature high ($CTEMP), $PWMID set to: $PWM"
			fi
		fi
	fi
	
	# if temp too low
	if [ "$CTEMP" -lt "$LTEMP" ] && [ "$TEMPSTATUS" != "inc" ]
	then
	
		if [ "$NEWPWM" -ne "0" ]
		then
			NEWPWM=0
			echo $NEWPWM 2>/dev/null > $PWMF
			PWM=`cat $PWMF`
			if [ "$LOG" -gt "0" ]
			then
				echo "temperature low ($CTEMP), $PWMID set to: $PWM"
			fi
		fi
	fi
	
sleep $LOOP
done


