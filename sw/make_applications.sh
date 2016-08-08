#!/bin/bash

####### Trap all errors
set -e


# make sure to be in the same directory as this script #########################
current_script_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

cd "${current_script_dir}"
source "../setup_env.sh"

pushd "${current_script_dir}"



abort()
{
	echoerr "An error occurred in `basename "$0"`. Exiting..."
	exit 1
}

trap 'abort' 0




folder_drivers_array=($folder_drivers)
folder_application_array=($folder_applications)

echo ${folder_drivers}

for driver in "${folder_drivers_array[@]}"
do

	echo -e "$c_info \nCompile $driver\n$c_default"
	pushd $driver_folder_a/$driver/

		indent_c_code
		make clean
		make

	popd

done

for application in "${folder_application_array[@]}"
do
	echo -e "$c_info \nCompile $application\n$c_default"
	pushd $application_folder_a/$application/

		indent_c_code
		if [ -f  ./compile.sh ]; then
			./compile.sh run_$application
		fi
	popd


done

popd

# If an error occurs abort is called

trap : 0
echo -e "$c_good *** DONE `basename "$0"` *** $c_default"
