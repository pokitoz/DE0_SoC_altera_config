#!/bin/bash

set -e

abort() {
	echo -e "\e[91m Error in `basename "$0"`\e[39m"
	exit 1
}

trap 'abort' 0

if [ -z ${setup_env+x} ]; then
	echo -e "$c_info Sourcing setup_env.sh.. $c_default"

	# make sure to be in the same directory as this script #########################
	script_dir_abs=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
	cd "${script_dir_abs}"

	c_white="\e[39m"
	c_green="\e[92m"
	c_orange="\e[93m"
	c_blue="\e[94m"
	c_red="\e[91m"

	export c_error=$c_red
	export c_good=$c_green
	export c_default=$c_white
	export c_info=$c_blue
	export c_warning=$c_orange
	export done_string="$c_default [$c_good DONE$c_default ]"

	export PATH_TO_ALTERA_EMBEDDED="/home/fdepraz/altera/15.1/embedded"
	echo -e "\e[34m Sourcing $PATH_TO_ALTERA_EMBEDDED/env.sh.. \e[39m"
	source $PATH_TO_ALTERA_EMBEDDED/env.sh
	export OPTIONS_MENU="Make_all Clean_build Make_Quartus Make_Qsys Make_uboot Make_linux_kernel Make_applications Send_applications Make_Send_Exec_Get_SSH Push_to_sd_card Exec_applications Get_Results Quit"


	relative_kernel_dir="./sw/linux/linux-source/"

	export setup_env="1"

	# C compiler
	export cross_compile_linux="arm-linux-gnueabihf-"
	export cross_compile_preloader="arm-altera-eabi-"
	export cross_compile_arch="arm"

	export ARCH=arm
	echo -e "\e[34m Set ARCH=$ARCH\e[39m"
	export CROSS_COMPILE=$cross_compile_linux
	echo -e "\e[34m Set CROSS_COMPILE=$CROSS_COMPILE\e[39m"
	export KDIR=`readlink -f $relative_kernel_dir`
	echo -e "\e[34m Set KDIR=$KDIR\e[39m"

	#SSH
	export env_sshpassword="terasic"
	export sshaddress="10.42.0.3"
	export sshlogin="root"
	export sshcommand="$sshlogin@$sshaddress"


	hw_folder="hw"
	sw_folder="sw"

	application_folder=$sw_folder/application
	driver_folder=$sw_folder/driver
	result_folder=$sw_folder/ImageResults
	lib_tiff_source_folder=$sw_folder/libtiff
	linux_folder=$sw_folder/linux
	preloader_folder=$sw_folder/preloader
	scripts_folder=$sw_folder/scripts
	



	export sw_folder_a=`readlink -f $sw_folder`
	export application_folder_a=`readlink -f $application_folder`
	export scripts_folder_a=`readlink -f $scripts_folder`
	export driver_folder_a=`readlink -f $driver_folder`
	export result_folder_a=`readlink -f $result_folder`
	export lib_tiff_source_folder_a=`readlink -f $lib_tiff_source_folder`
	export linux_folder_a=`readlink -f $linux_folder`
	export preloader_folder_a=`readlink -f $preloader_folder`

	export indent_command_flags="-nbad -bap -nbc -bbo -hnl -br -brs -c33 -cd33 -ncdb -ce -ci4 -cli0 -d0 -di1 -nfc1 -i8 -ip0 -l80 -lp -npcs -nprs -npsl -sai -saf -saw -ncs -nsc -sob -nfca -cp33 -ss -ts8 -il1"

	export folder_drivers="convertor_yuv_rgb dummy_driver dma_memory_to_memory"
	#"nav_cam" "quark_interface" "user_input_driver"

	export folder_applications="convertor_yuv_rgb_app dma_memory_to_memory_app"
	#"nav_cam" "nav_cam_static" "quark_interface" 


	export sdcard_fat32_mount_point_abs="/media/sdcard_socfpga_fat32"
	export sdcard_ext3_mount_point_abs="/media/sdcard_socfpga_ext3"

	echoerr() {
	    echo -e "$c_error ${@} $c_default"
	}

	echowarn(){
	    echo -e "$c_warning ${@} $c_default"
	}

	echogood(){
	    echo -e "$c_good ${@} $c_default"
	}

	echoinfo(){
	    echo -e "$c_info ${@} $c_default"
	}

	echodef(){
	    echo -e "$c_default ${@} $c_default"
	}

	print_ssh_info(){

		echowarn "\n Please make sure the board is on and you have ssh access to it "
		echowarn " The IP used is $sshaddress "
		echowarn " The Login and password used are $sshlogin -- $env_sshpassword "
		echowarn " You should type: ifup eth0 in the UART-USB shell \n "
	
	}


	indent_c_code(){
	
		set +e
	
		if [ -z "*.c" ]; then
			echowarn "Formating c files"
			indent "$indent_command_flags" ./*.c 
		fi
	
		if [ -z "*.h" ]; then
			echowarn "Formating h files"
			indent "$indent_command_flags" ./*.h
		fi

		set -e

	}

	pushd_silent() {
		command pushd "$@" > /dev/null
	}

	popd_silent() {
		command popd "$@" > /dev/null
	}
	

	export -f print_ssh_info
	export -f echoerr
	export -f echowarn
	export -f echogood
	export -f echoinfo
	export -f echodef
	export -f pushd_silent
	export -f popd_silent
	export -f indent_c_code

fi


trap : 0
echo -e "\e[92m *** DONE `basename "$0"` *** \n\e[39m"
