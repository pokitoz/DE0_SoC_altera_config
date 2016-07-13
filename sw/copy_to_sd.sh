#!/bin/bash

####### Trap all errors
set -e



abort()
{
	echo "An error occurred in `basename "$0"`. Exiting..." >&2
	exit 1
}

trap 'abort' 0


# make sure to be in the same directory as this script #########################
current_script_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )


if [ "$#" -ne 2 ]; then
    echoerr "Illegal number of parameters"
	exit 1
fi

cd "${current_script_dir}"
source "../setup_env.sh"

sdcard_ext3_abs="$1"
sdcard_fat32_abs="$2"

#Need to open the sd card
set +e
    sudo umount ${sdcard_ext3_abs}
set -e


sudo mkdir -p "$sdcard_ext3_mount_point_abs"
sudo mount -t ext3 "${sdcard_ext3_abs}" "$sdcard_ext3_mount_point_abs"


pushd "${current_script_dir}"

	echowarn "Copy libtiff to $sdcard_ext3_mount_point_abs/home/root/"
	sudo cp -r ./libtiff "$sdcard_ext3_mount_point_abs/home/root/"

	folder_drivers_array=($folder_drivers)
	folder_application_array=($folder_applications)

	for driver in "${folder_drivers_array[@]}"
	do
		echowarn "Copy $driver_folder_a/$driver to $sdcard_ext3_mount_point_abs/home/root/"
		mkdir -p "$sdcard_ext3_mount_point_abs/home/root/$driver"

		pushd_silent $driver_folder_a/$driver/
		    sudo cp ./*.ko "$sdcard_ext3_mount_point_abs/home/root/$driver"
		popd_silent

	done

	for application in "${folder_application_array[@]}"
	do
		echowarn "Copy $application_folder_a/$application to $sdcard_ext3_mount_point_abs/home/root/ "
		mkdir -p "$sdcard_ext3_mount_point_abs/home/root/$application"

		pushd_silent $application_folder_a/$application/
			sudo cp ./*_app ./run_*.sh "$sdcard_ext3_mount_point_abs/home/root/$application"
		popd_silent

	done

	pushd_silent ${scripts_folder_a}
		echowarn "\n Copy $scripts_folder_a content to $sdcard_ext3_mount_point_abs/home/root/"
		sudo cp ./*.sh "$sdcard_ext3_mount_point_abs/home/root/"
	popd_silent

popd


sudo sync
sudo umount "${sdcard_ext3_abs}"
sudo rm -rf "$sdcard_ext3_mount_point_abs"

# If an error occurs abort is called

trap : 0
echo -e "$c_good *** DONE `basename "$0"` *** $c_default"
