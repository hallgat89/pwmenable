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

### BEGIN INIT INFO
# Provides:          pwmenable.sh
# Required-Start:    $local_fs $syslog $remote_fs dbus
# Required-Stop:     $local_fs $syslog $remote_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Set pwm 137 for Radeon R9 380X
# Description:       Set pwm 137 for Radeon R9 380X
### END INIT INFO

if [ "`id -u`" != "0" ]
then
	echo "You need to be root to run this script."
	exit 1
fi

cd /sys/class/hwmon
echo 1 2>/dev/null > hwmon0/pwm1_enable
echo 255 2>/dev/null > hwmon0/pwm1 
exit 0

