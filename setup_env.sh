#!/bin/bash

set -e

abort()
{
	echoerr "An error occurred in `basename "$0"`. Exiting..."
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
	export OPTIONS_MENU="Make_all Clean_build Make_Quartus Make_Qsys Make_uboot Make_linux_kernel Generate_dtb Make_applications Send_applications Make_Send_Exec_Get_SSH Push_to_sd_card Exec_applications Get_Results Generate_sd_partitions Quit"


	# Preloader
	export preloader_target_dir_abs="${script_dir_abs}/sw/preloader"
	export preloader_settings_file_abs="${preloader_target_dir_abs}/settings.bsp"
	export preloader_mkimage_bin_file_abs="${preloader_target_dir_abs}/preloader-mkpimage.bin"

	




	hw_folder="hw"
	sw_folder="sw"

	application_folder=$sw_folder/application
	driver_folder=$sw_folder/driver
	result_folder=$sw_folder/ImageResults
	lib_tiff_source_folder=$sw_folder/libtiff
	linux_folder=$sw_folder/linux
	preloader_folder=$sw_folder/preloader
	scripts_folder=$sw_folder/scripts
	presets_folder=$sw_folder/presets
	configs_folder=$presets_folder/configs


	export sw_folder_a=`readlink -f $sw_folder`
	export application_folder_a=`readlink -f $application_folder`
	export scripts_folder_a=`readlink -f $scripts_folder`
	export driver_folder_a=`readlink -f $driver_folder`
	export result_folder_a=`readlink -f $result_folder`
	export lib_tiff_source_folder_a=`readlink -f $lib_tiff_source_folder`
	export linux_folder_a=`readlink -f $linux_folder`
	export preloader_folder_a=`readlink -f $preloader_folder`
	export presets_folder_a=`readlink -f $presets_folder`
	export configs_folder_a=`readlink -f $configs_folder`


	# Linux
	export linux_src_dir="${linux_folder_a}/linux-source"
	#linux_src_dir="${linux_folder_a}/linux-socfpga"


	# uboot
	export uboot_source_dir_abs="${linux_folder_a}/uboot-socfpga-git"
	export uboot_img_file_abs="${uboot_source_dir_abs}/u-boot.img"
	export uboot_script_file_src_abs="${uboot_source_dir_abs}/boot.script"
	export uboot_script_file_bin_abs="${uboot_source_dir_abs}/u-boot.scr"
	export uboot_git_repo="git://git.denx.de/u-boot.git"

	export uboot_make_parameter="socfpga_de0_nano_soc_defconfig"


	export linux_zImage_file="$(readlink -m "${linux_src_dir}/arch/arm/boot/zImage")"

	# Device Tree	
	export device_tree_source_name="socfpga_project"
	export device_tree_blob_file_name="$device_tree_source_name.dtb"


	export custom_device_tree_source_abs="$presets_folder_a/$device_tree_source_name.dts";
	
	export linux_dts_file="${linux_src_dir}/arch/arm/boot/dts/$device_tree_source_name.dts"
	export linux_dtb_file="${linux_src_dir}/arch/arm/boot/dts/$device_tree_blob_file_name"
	export device_tree_output_source_file_name="output_$device_tree_source_name.dts"


	#mem=nn[KMG]	[KNL,BOOT] Force usage of a specific amount of memory
	#		Amount of memory to be used when the kernel is not able
	#		to see the whole system memory or for test.
	export linux_kernel_mem_bootarg='1018M'

	#linux_checkout_revision_linux="9735a22799b9214d17d3c231fe377fc852f042e9"
	export linux_checkout_revision_linux="null"

	export linux_src_git_repo="https://github.com/torvalds/linux.git"
	#linux_src_git_repo="https://github.com/altera-opensource/linux-socfpga.git"
	export linux_menuconfig="0"

	export sdcard_image_file_abs="$linux_folder/DE0-Nano-SoC_Linux_Console.img"


	export setup_env="1"

	# C compiler
	export cross_compile_linux="arm-linux-gnueabihf-"
	export cross_compile_preloader="arm-altera-eabi-"
	export cross_compile_arch="arm"

	export ARCH=arm
	echo -e "\e[34m Set ARCH=$ARCH\e[39m"
	export CROSS_COMPILE=$cross_compile_linux
	echo -e "\e[34m Set CROSS_COMPILE=$CROSS_COMPILE\e[39m"
	export KDIR=$linux_src_dir
	echo -e "\e[34m Set KDIR=$KDIR\e[39m"

	#SSH
	export env_sshpassword="terasic"
	export sshaddress="10.42.0.3"
	export sshlogin="root"
	export sshcommand="$sshlogin@$sshaddress"






	#Force blank lines after declarations.
	#Forces a blank line after every procedure body.
	#Do not force newline after the comma separating the arguments of a function declaration
	#No newline after each comma in a declaration
	#Put braces on line with if, etc.
	#Put braces on struct declaration line.
	#Put comments to the right of code in column 33
	#Put comments to the right of the declarations in column 33
	#else in an if-then-else construct to cuddle up to the immediately preceding `}'
	
	export indent_command_flags=" -bad -br -ce -l200"

 	#-bbo -hnl -br -brs -c33 -cd33 -ncdb -ce -ci4 -cli0 -d0 -di1 -nfc1 -i8 -ip0 -lp -npcs -nprs -npsl -sai -saf -saw -ncs -nsc -sob -nfca -cp33 -ss -ts8 -il1"

	export folders_hps_lookup="driver application"
	export folder_drivers="dma_memory_to_memory user_input_driver"
	#"nav_cam" "quark_interface" "user_input_driver convertor_yuv_rgb dummy_driver"

	export folder_applications="dma_memory_to_memory_app gsensor_hps_app"
	#"nav_cam" "nav_cam_static" "quark_interface convertor_yuv_rgb_app " 


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
	
		for source_c_name in *.c; do
			echowarn "Formating c file $source_c_name"
			#indent "$indent_command_flags" ./$source_c_name
		done
	
		for header_c_name in *.h; do
			echowarn "Formating h file $header_c_name"
			#indent "$indent_command_flags" ./$header_c_name
		done

		set -e

	}

	pushd_silent() {
		command pushd "$@" > /dev/null
	}

	popd_silent() {
		command popd "$@" > /dev/null
	}



	check_sd_card_plug(){

		if [ ! -b "$1" ]; then
		    
		    while [ ! -b "$1" ]; do

		        echoerr "Error: could not find \"$1\""
		        echoinfo "You can plug the SD card or quit the script with CTRL + C"
		        
		        read -p "Press [Enter] key to restart..."

		    done
		fi


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
	export -f check_sd_card_plug

fi


trap : 0
echo -e "\e[92m *** DONE set_env.sh *** \n\e[39m"
