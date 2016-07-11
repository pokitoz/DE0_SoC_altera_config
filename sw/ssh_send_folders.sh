#!/bin/bash

####### Trap all errors
set -e


# use sshpass -e 
# It will read the password in the $env_sshpassword environment variable

# make sure to be in the same directory as this script #########################
current_script_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )


cd "${current_script_dir}"
source "../setup_env.sh"

pushd "${current_script_dir}"


abort()
{

	print_ssh_info
    echo "An error occurred. Exiting..." >&2
    echo "Are you using the Embedded System Shell ?..." >&2
    exit 1
}

trap 'abort' 0





#Check if libtiff is present
set +e
isLibtiff=`sshpass -p "$env_sshpassword" ssh $sshcommand ls | grep libtiff`
set -e

if [ -z $isLibtiff  ]; then
	echo -e "\n*** Sending libtiff ***"
	sshpass -p "$env_sshpassword" scp -r ./libtiff $sshcommand:
else
	echo -e "\n*** LibTiff exists ***"
fi

folder_drivers_array=($folder_drivers)
folder_application_array=($folder_applications)

for driver in "${folder_drivers_array[@]}"
do
	echo -e "*** Creating driver folder: $driver***"
	sshpass -p "$env_sshpassword" ssh $sshcommand mkdir -p "$driver"

	pushd $driver_folder_a/$driver/
	echo -e "*** Sending files from $drivers_location/$driver/"
	sshpass -p "$env_sshpassword" scp *.ko $sshcommand:"$driver"
	popd

done

for application in "${folder_application_array[@]}"
do
	echo -e "*** Creating application folder: $application***"
	sshpass -p "$env_sshpassword" ssh $sshcommand mkdir -p "$application"

	pushd $application_folder_a/$application/
	echo -e "\n*** Sending $application***"
	sshpass -p "$env_sshpassword" scp *_app run_*.sh $sshcommand:"$application"
	popd

done

pushd $sw_folder_a/scripts/
	echo -e "\n*** Sending $scripts folder***"
	sshpass -p "$env_sshpassword" scp *.sh $sshcommand:
popd


popd


# If an error occurs abort is called

trap : 0
echo -e "$c_good *** DONE `basename "$0"` *** $c_default"
