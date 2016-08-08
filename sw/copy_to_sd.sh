#!/bin/bash

####### Trap all errors
set -e



abort()
{
	echoerr "An error occurred in `basename "$0"`. Exiting..."
	exit 1
}

trap 'abort' 0

echo -e "$c_good *** Start `basename "$0"` *** $c_default"

# make sure to be in the same directory as this script #########################
current_script_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )


if [ "$#" -ne 3 ]; then
    echoerr "Illegal number of parameters"
	echoerr "Need sdcard path, ext3 partition, fat32 partition"
	exit 1
fi

cd "${current_script_dir}"
source "../setup_env.sh"



sdcard_abs="$1"

check_sd_card_plug "${sdcard_abs}"


sdcard_ext3_abs="$2"
sdcard_fat32_abs="$3"

#Need to open the sd card
set +e
	echowarn "Trying to unmount ${sdcard_ext3_abs} (just to be sure its not already mounted)"
    sudo umount ${sdcard_ext3_abs}
set -e


sudo mkdir -p "$sdcard_ext3_mount_point_abs"
sudo mount -t ext3 "${sdcard_ext3_abs}" "$sdcard_ext3_mount_point_abs"


pushd "${current_script_dir}"

	echowarn "Copy libtiff to $sdcard_ext3_mount_point_abs/home/root/"
	sudo cp -r ./api/libtiff "$sdcard_ext3_mount_point_abs/home/root/"

	echowarn "Copy ffmpeg-3.1.1 to $sdcard_ext3_mount_point_abs/home/root/"
	#sudo cp -r ./api/ffmpeg-3.1.1 "$sdcard_ext3_mount_point_abs/home/root/"

	echowarn "Copy openCV to $sdcard_ext3_mount_point_abs/home/root/"
	#sudo cp -r ./api/opencv-2.4.13 "$sdcard_ext3_mount_point_abs/home/root/"

	echowarn "Copy slam to $sdcard_ext3_mount_point_abs/home/root/"
	sudo cp -r ./api/slam "$sdcard_ext3_mount_point_abs/home/root/"

	folder_drivers_array=($folder_drivers)
	folder_application_array=($folder_applications)

	for driver in "${folder_drivers_array[@]}"
	do
		echowarn "Copy $driver_folder_a/$driver to $sdcard_ext3_mount_point_abs/home/root/"
		sudo mkdir -p "$sdcard_ext3_mount_point_abs/home/root/$driver"

		pushd_silent $driver_folder_a/$driver/
		    sudo cp ./*.ko "$sdcard_ext3_mount_point_abs/home/root/$driver"
		popd_silent

	done

	for application in "${folder_application_array[@]}"
	do
		echowarn "Copy $application_folder_a/$application to $sdcard_ext3_mount_point_abs/home/root/ "
		sudo mkdir -p "$sdcard_ext3_mount_point_abs/home/root/$application"

		pushd_silent $application_folder_a/$application/

			if [ -f ./*.app ]; then
				sudo cp ./*_app "$sdcard_ext3_mount_point_abs/home/root/$application"
			else
				sudo cp * "$sdcard_ext3_mount_point_abs/home/root/$application"
			fi

			if [ -f *.y ]; then
				sudo cp ./*.y "$sdcard_ext3_mount_point_abs/home/root/$application"
			fi

			if [ -f run_*.sh ]; then
				sudo cp ./run_*.sh "$sdcard_ext3_mount_point_abs/home/root/$application"
			fi
		popd_silent
	done

	pushd_silent ${scripts_folder_a}
		echowarn "\n Copy $scripts_folder_a content to $sdcard_ext3_mount_point_abs/home/root/"
		sudo cp ./*.sh "$sdcard_ext3_mount_point_abs/home/root/"
	popd_silent

popd

echowarn "\n Synchronise the SD card"
sudo sync

sudo umount "${sdcard_ext3_abs}"
sudo rm -rf "$sdcard_ext3_mount_point_abs"

# If an error occurs abort is called
trap : 0
echo -e "$c_good *** DONE `basename "$0"` *** $c_default"
