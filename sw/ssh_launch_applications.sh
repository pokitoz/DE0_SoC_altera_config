#!/bin/bash

####### Trap all errors
set -e

# use sshpass -e 
# It will read the password in the $SSHPASS environment variable

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







# Some images may have not been created yet..
set +e

#########################################


echo -e "Launching $folder_convertor/run.sh"
sshpass -p "$env_sshpassword" ssh $sshcommand bash "$folder_convertor"/run.sh "$convertor_yuv_rgb"
echo -e "---------------------------------------"


popd

# If an error occurs abort is called

trap : 0
echo -e "$c_good *** DONE `basename "$0"` *** $c_default"
