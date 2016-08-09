#!/bin/bash

####### Trap all errors
set -e


abort()
{
	echoerr "An error occurred in `basename "$0"`. Exiting..."
	exit 1
}

trap 'abort' 0

# make sure to be in the same directory as this script #########################
current_script_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd "${current_script_dir}"
source "../setup_env.sh"

echo -e "$c_good *** Start `basename "$0"` *** $c_default"
echoinfo "Make sure to have enought space on the SD card for the folders"


if [ "$#" -ne 3 ]; then
	echoerr "Illegal number of parameters"
	echoerr "Need sdcard path, ext3 partition, fat32 partition"
	exit 0
fi





pushd "${current_script_dir}"



sdcard_abs="$1"

check_sd_card_plug "${sdcard_abs}"


sdcard_ext3_abs="$2"
sdcard_fat32_abs="$3"

#Need to open the sd card

umount_all ${sdcard_ext3_abs} ${sdcard_fat32_abs}

sudo mkdir -p "$sdcard_ext3_mount_point_abs"
sudo mount -t ext3 "${sdcard_ext3_abs}" "$sdcard_ext3_mount_point_abs"



folder_api_sd="$sdcard_ext3_mount_point_abs/home/root/api"
folder_app_sd="$sdcard_ext3_mount_point_abs/home/root/application"
folder_dev_sd="$sdcard_ext3_mount_point_abs/home/root/driver"
folder_scr_sd="$sdcard_ext3_mount_point_abs/home/root/script"

mkdir -p "$folder_api_sd" 
mkdir -p "$folder_app_sd" 
mkdir -p "$folder_dev_sd" 
mkdir -p "$folder_scr_sd"

pushd "${sw_folder_a}"

	
	############## API

	echowarn "Copy libtiff to $folder_api_sd"
	sudo cp -r ./api/libtiff "$folder_api_sd"

	echowarn "Copy ffmpeg-3.1.1 to $folder_api_sd"
	#sudo cp -r ./api/ffmpeg-3.1.1 "$sdcard_ext3_mount_point_abs/home/root/"

	echowarn "Copy openCV to $folder_api_sd"
	#sudo cp -r ./api/opencv-2.4.13 "$sdcard_ext3_mount_point_abs/home/root/"

	echowarn "Copy slam to $folder_api_sd"
	sudo cp -r ./api/slam "$folder_api_sd"

	echowarn ""

	folder_drivers_array=($folder_drivers)
	############## DRIVERS
	for driver in "${folder_drivers_array[@]}"
	do
		echowarn "Copy $driver_folder_a/$driver to $folder_dev_sd"
		sudo mkdir -p "$folder_dev_sd/$driver"

		pushd_silent $driver_folder_a/$driver/
		    sudo cp ./*.ko "$folder_dev_sd/$driver"
		popd_silent

	done

	echowarn ""
	############## APPLICATIONS
	folder_application_array=($folder_applications)
	for application in "${folder_application_array[@]}"
	do
		echowarn "Copy $application_folder_a/$application to $folder_app_sd/ "
		sudo mkdir -p "$folder_app_sd/$application"

		pushd_silent $application_folder_a/$application/

			if [ -f ./*.app ]; then
				sudo cp ./*_app "$folder_app_sd/$application"
			else
				sudo cp * "$folder_app_sd/$application"
			fi

			if [ -f *.y ]; then
				sudo cp ./*.y "$folder_app_sd/$application"
			fi

			if [ -f run_*.sh ]; then
				sudo cp ./run_*.sh "$folder_app_sd/$application"
			fi
		popd_silent
	done

	pushd_silent ${scripts_folder_a}
		echowarn "\n Copy $scripts_folder_a content to $folder_scr_sd/"
		sudo cp ./*.sh "$folder_scr_sd"
	popd_silent

popd

echowarn "\n Synchronise the SD card"
sudo sync

sudo umount "${sdcard_ext3_abs}"
sudo rm -rf "$sdcard_ext3_mount_point_abs"

# If an error occurs abort is called
trap : 0
echo -e "$c_good *** DONE `basename "$0"` *** $c_default"
