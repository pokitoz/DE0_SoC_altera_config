#!/bin/bash

set -e

# make sure to be in the same directory as this script #########################
current_script_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd "${current_script_dir}"

source ../../setup_env.sh

pushd "$linux_folder_a"

abort()
{
	echoerr "An error occurred in `basename "$0"`. Exiting..."
	exit 1
}

trap 'abort' 0


set +e
exist_pkg=`multistrap 2>&1 | grep "multistrap: command not found"`
set -e

echo $exist_pkg
if [ ! "$exist_pkg" == "" ]; then
	echoinfo "Get multistrap"
	sudo apt-get install multistrap
fi

set +e
exist_pkg=`qemu 2>&1 | grep "qemu: command not found"`
set -e

if [ ! "$exist_pkg" == "" ]; then
	echoinfo "Get QEMU"
	sudo apt-get install qemu
	sudo apt-get install qemu-user-static
fi

set +e
exist_pkg=`binfmt-support 2>&1 | grep "binfmt-support: command not found"`
set -e

if [ "$exist_pkg" == "" ]; then
	echoinfo "Get binfmt-support "
	sudo apt-get install binfmt-support
fi

set +e
exist_pkg=`dpkg-cross 2>&1 | grep "dpkg-cross: command not found"`
set -e

if [ "$exist_pkg" == "" ]; then
	echoinfo "Get dpkg-cross "
	sudo apt-get install dpkg-cross
	
fi

echoinfo "Create directory ./rootfs-multistrap"

set +e
rm -f $linux_folder_a/rootfs-multistrap/target-rootfs/rootfs-multistrap.tgz
set -e

mkdir -p $linux_folder_a/rootfs-multistrap




cd $linux_folder_a/rootfs-multistrap

echoinfo "Generate config_multistrap"
cat <<EOF > config_multistrap

[General]
# Set the rootfs directory
directory=target-rootfs
# Exclude the downloaded packages
cleanup=false
noauth=true
unpack=true
debootstrap=Debian Net Utils Python Opencv OpencvMore
aptsources=Debian 


[Debian]
packages=apt kmod lsof
source=http://cdn.debian.net/debian/
keyring=debian-archive-keyring
suite=jessie
components=main contrib non-free

[Net]
#Basic packages to enable the networking
packages=ifupdown ssh
source=http://cdn.debian.net/debian/
#netbase net-tools ethtool udev iproute iputils-ping ifupdown isc-dhcp-client ssh

[Utils]
#General purpose utilities
source=http://cdn.debian.net/debian
packages=htop binutils

#locales adduser nano less wget dialog git procps evtest dash wpasupplicant usbutils htop binutils

#Python language
[Python]
packages=python python-serial python-dev python-numpy
source=http://cdn.debian.net/debian

#OpenCV
[Opencv]
packages=
source=http://cdn.debian.net/debian/
#cmake git pkg-config libavcodec-dev libavformat-dev libswscale-dev

#OpenCV2
[OpencvMore]
packages=libjpeg-dev libpng-dev libtiff-dev
source=http://cdn.debian.net/debian/
#libjpeg-dev libpng-dev libtiff-dev

EOF




#mkdir -p ./rootfs


#At this step, the base of the rootfs is ready. It is possible to boot on it but the rootfs is not configured..
# The nex step is to configure this rootfs for our system. the compilation of the binary must be done.
# We need to compile it on the board.
# To Avoid it, we use qemu

echoinfo "If this script display the following error:"
echowarn "Global symbol "\$forceyes" requires explicit package name at /usr/sbin/multistrap line 989."
echoinfo "Please remove \$forceyes of the command into the /usr/sbin/multistrap at the corresponding line:"
echoinfo "  system (\"\$str $env chroot \$dir apt-get --reinstall -y install \$forceyes \$reinst\");"

#sudo rm -rf ./target-rootfs

echoinfo "Use multistrap on rootfs (with sudo)"
multistrap -a armhf -d target-rootfs -f config_multistrap
echoinfo "Done multistrap on rootfs"





sudo cp /usr/bin/qemu-arm-static target-rootfs/usr/bin/
set +e

sudo cp /usr/bin/qemu-arm-static target-rootfs/usr/bin
sudo LC_ALL=C LANGUAGE=C LANG=C chroot target-rootfs dpkg --configure -a
#sudo chroot target-rootfs /bin/sh
#sudo mount -o bind /dev/ target-rootfs/dev/
#sudo LC_ALL=C LANGUAGE=C LANG=C chroot target-rootfs dpkg --configure -a
sudo chroot target-rootfs passwd
sudo chroot target-rootfs dpkg --get-selections
cat target-rootfs/etc/debian_version

#sudo LC_ALL=C LANGUAGE=C LANG=C chroot target-rootfs apt-get install packagename

#./rootfs_config.sh


sudo rm target-rootfs/usr/bin/qemu-arm-static

set -e

echoinfo "Create tar file"


cd $linux_folder_a/rootfs-multistrap/target-rootfs/
set +e
rm -f rootfs-multistrap.tgz
set -e

sudo chown -R $USER ./*
tar -czpf "rootfs-multistrap.tgz" ./*
mv rootfs-multistrap.tgz $rootfs_file


popd


trap : 0
echo -e "$c_good *** DONE `basename "$0"` *** $c_default"
