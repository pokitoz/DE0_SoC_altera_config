#!/bin/bash

####### Trap all errors
set -e


# use sshpass -e 
# It will read the password in the $env_sshpassword environment variable

# make sure to be in the same directory as this script #########################
current_script_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )


cd "${current_script_dir}"
source "../setup_env.sh"




abort()
{
	print_ssh_info
    echoerr "An error occurred in `basename "$0"`. Exiting..."
    exit 1
}

trap 'abort' 0




pushd "${current_script_dir}"

	#Check if libtiff is present
	set +e
	isLibtiff=`sshpass -p "$env_sshpassword" ssh $sshcommand ls | grep libtiff`
	set -e

	if [ -z $isLibtiff  ]; then
		echowarn "\nSending libtiff"
		sshpass -p "$env_sshpassword" scp -r ./libtiff $sshcommand:
	else
		echowarn "\nLibTiff exists"
	fi

	folder_drivers_array=($folder_drivers)
	folder_application_array=($folder_applications)

	for driver in "${folder_drivers_array[@]}"
	do
		echowarn "\nCreating driver folder: $driver"
		sshpass -p "$env_sshpassword" ssh $sshcommand mkdir -p "$driver"

		pushd_silent $driver_folder_a/$driver/
			echowarn "Sending files from $drivers_location/$driver/"
			sshpass -p "$env_sshpassword" scp *.ko $sshcommand:"$driver"
		popd_silent

	done

	echo -e ""

	for application in "${folder_application_array[@]}"
	do
		echowarn "\nCreating application folder: $application"
		sshpass -p "$env_sshpassword" ssh $sshcommand mkdir -p "$application"

		pushd_silent $application_folder_a/$application/
			echowarn "Sending $application"
			
			sshpass -p "$env_sshpassword" scp *_app  $sshcommand:"$application"
		
			if [ -f *.y ]; then
				sshpass -p "$env_sshpassword" scp ./*.y $sshcommand:"$application"
			fi


			if [ -f run_*.sh ]; then
				sshpass -p "$env_sshpassword" scp run_*.sh $sshcommand:"$application"
			fi

		popd_silent

	done

	pushd_silent ${scripts_folder_a}
		echowarn "\nSending scripts folder"
		sshpass -p "$env_sshpassword" scp *.sh $sshcommand:
	popd_silent


popd


# If an error occurs abort is called

trap : 0
echo -e "$c_good  DONE `basename "$0"`  $c_default"
