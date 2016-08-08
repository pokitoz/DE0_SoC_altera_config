#!/bin/bash

abort()
{
	echoerr "An error occurred in `basename "$0"`. Exiting..."
	exit 1
}

trap 'abort' 0

set -e

# make sure to be in the same directory as this script #########################
current_script_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )


source ../../setup_env.sh



pushd "${current_script_dir}"

mkdir -p ./configs

cat <<EOF > ./configs/etc_network_interfaces
# /etc/network/interfaces -- configuration file for ifup(8), ifdown(8)

# The loopback interface
auto lo
iface lo inet loopback

iface atml0 inet dhcp

# Wired or wireless interfaces
iface eth0 inet static
address $sshaddress
netmask 255.255.255.0
network 10.42.0.0
broadcast 10.42.0.255
gateway 10.42.0.1


EOF


cat <<EOF > ./configs/etc_profile

# /etc/profile: system-wide .profile file for the Bourne shell (sh(1))
# and Bourne compatible shells (bash(1), ksh(1), ash(1), ...).

PATH="/usr/local/bin:/usr/bin:/bin"
EDITOR="/bin/vi"			# needed for packages like cron
test -z "$TERM" && TERM="vt100"	# Basic terminal capab. For screen etc.

if [ ! -e /etc/localtime ]; then
	TZ="UTC"		# Time Zone. Look at http://theory.uwinnipeg.ca/gnu/glibc/libc_303.html 
				# for an explanation of how to set this to your local timezone.
	export TZ
fi

if [ "$HOME" = "/home/root" ]; then
   PATH=$PATH:/usr/local/sbin:/usr/sbin:/sbin
fi
if [ "$PS1" ]; then
# works for bash and ash (no other shells known to be in use here)
   PS1='\u@\h:\w\$ '
fi

if [ -d /etc/profile.d ]; then
  for i in /etc/profile.d/* ; do
    . $i
  done
  unset i
fi

export PATH PS1 OPIEDIR QPEDIR QTDIR EDITOR TERM

umask 022

ifup eth0

export LD_LIBRARY_PATH=/home/root/ffmpeg-3.1.1/lib:${LD_LIBRARY_PATH}
export C_INCLUDE_PATH=/home/root/ffmpeg-3.1.1/include:${C_INCLUDE_PATH}
export CPLUS_INCLUDE_PATH=/home/root/ffmpeg-3.1.1/include:${CPLUS_INCLUDE_PATH}
export LD_LIBRARY_PATH=/home/root/opencv-2.4.13/lib/:{LD_LIBRARY_PATH}
EOF






cat <<EOF > ./configs/rc.local
#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "exit 0" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.

ifup eth0


sudo date --set "25 Sep 2020 15:00:00"

exit 0

EOF



echo "date +%Y%m%d%H%M" > "./configs/timestamp"
echo "Welcome to Sensefly SoC!" > "./configs/issue.net"
echo "FPGA SoC Sensefly" > "./configs/issue"


popd



trap : 0
echo -e "$c_good *** DONE `basename "$0"` *** $c_default"
