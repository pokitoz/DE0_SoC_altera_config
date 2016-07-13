#!/bin/bash




# make sure to be in the same directory as this script #########################
current_script_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

cd "${current_script_dir}"
source "../setup_env.sh"

pushd "${current_script_dir}"

print_ssh_info

# use sshpass -e 
# It will read the password in the $SSHPASS environment variable

mkdir -p $result_folder_a
folder_application_array=($folder_applications)
echo -e "\n*** Get the images back ***"

#for application in "${folder_application_array[@]}"
#do


	echo -e "Copy files to $result_folder_a from $sshcommand with password $env_sshpassword"
	#sshpass -p "$env_sshpassword" scp $sshcommand:"*/*.tiff" "$result_folder_a"
	#sshpass -p "$env_sshpassword" scp $sshcommand:"*/*.ppm" "$result_folder_a"
	sshpass -p "$env_sshpassword" scp $sshcommand:"*/*.bmp" "$result_folder_a"

	#sshpass -p "$env_sshpassword" scp $sshcommand:"*.bmp" "$result_folder_a"

#done


echo -e "*** Done `basename $0` ***"


popd


