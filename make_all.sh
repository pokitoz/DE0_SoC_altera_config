#!/bin/bash


# inputs #######################################################################
qpf_file_abs="$(readlink -m "${1}")"
sdcard_abs="$(readlink -m "${2}")"
upload_linux_image="$(readlink -m "${3}")"
################################################################################



# make sure to be in the same directory as this script #########################
script_dir_abs=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd "${script_dir_abs}"

source ./setup_env.sh
. "${script_dir_abs}/constants.sh"

################################################################################


# Trap all the errors and stop the script execution if any #####################
set -e


# Functions definitions ########################################################



# trap ctrl-c and call ctrl_c()
trap ctrl_c INT


# Functions definitions ########################################################
print_useful_info(){

    echoinfo "\n*** MAKE SURE MSEL IS 00000 *** "
    echoinfo "*** The zImage is copied *** "
	echoinfo "*** You can type ssh $sshcommand (password terasic) Check the static ip in etc_network_interface ***"
    echoinfo "*** The command \`ifup eth0\` will be executed on the FPGA *** "
    echoinfo "*** If hps_0.h changed  you need to recompile all files using it *** "    
    echoinfo "*** Open quartus project to see the details of the block size *** "
	echoinfo "*** Use minicom or miniterm.py to communicate by USB-UART (baud 115200) *** "
    echoinfo "*** Go to sw/ and launch the script once the board is on or use the menu ***\n"
	echoinfo "*** If you get \"fatload - load binary file from a dos filesystem \"***\n"
	echoinfo "       Stop the execution of uboot by pressing any key\n"
	echoinfo "       Execute \"env default -a\"\n"
	echoinfo "       Execute \"saveenv\"\n"
	echoinfo "       Check the documentation for more details\n"
}

ctrl_c() {


	print_useful_info
  	echogood " \nExited by user with CTRL+C "
	echogood " *** DONE `basename "$0"` *** "
	trap : 0
	exit 0
}


hcenter() {

  text="$1"

  cols=`tput cols`

  IFS=$'\n'$'\r'
  for line in $(echo -e $text); do

    line_length=`echo $line| wc -c`
    half_of_line_length=`expr $line_length / 2`
    center=`expr \( $cols / 2 \) - $half_of_line_length`

    spaces=""
    for ((i=0; i < $center; i++)) {
      spaces="$spaces "
    }

    echowarn "$spaces$line"

  done

}


asking_to_do() {
	ACTION=$1
	COMMAND=$2
	echodef "\e[0;33m"
  read -r -s -n 1 -p "Do $ACTION ? [y,n] : " doit
  case $doit in
    y|Y) echowarn "doing $ACTION " && $COMMAND;;
    n|N) echowarn "passing $ACTION " ;;
    *) echowarn "bad option " && asking_to_do $ACTION $COMMAND ;;
  esac
}



abort() {


	
    #Reset color to default 
    tput sgr0  

	call_menu_make_all
#	echoerr "An error occurred in `basename "$0"`. Exiting..."
	

	#exit 1
}

trap 'abort' 0


usage() {
    cat <<EOF
usage: compile.sh quartus_qpf_file [sdcard_target_device_file]

positional arguments:
    quartus_qpf_file             path to quartus qpf file               [ex: "hw/quartus/my_qpf_project.qpf"]
    sdcard_target_device_file    path to sdcard device file to write    [ex: "/dev/mmcblk0"]

required files in hierarchy:
    quartus_dir/*.qpf : Quartus project file
    quartus_dir/${qsys_file_name_no_extension}.qsys : Qsys file containing a HPS component
    quartus_dir/setup_project.tcl : Script to setup Quartus project
    quartus_dir/pin_assignment_*.tcl : Script to setup device pin assignments
EOF
}


copy_hps_to_folders(){
    echoinfo "\n *** Copy the HPS_0.h file where needed *** "

	for folders_hps in $folders_hps_lookup; do
		for i in $( find "./sw/$folders_hps" -name 'hps_0.h' ); do
			echoinfo "     Copy hps_0.h to $i   "	
			cp "./hw/quartus/hps_0.h" "$i"
		done
	done

    echowarn "\n *** If one path was ommited, please copy hps0.h to it *** "

}


validate_required_files() {

	echoinfo "Validate required files"

    # Check if there is a quartus project file
    if [ ! -f "${qpf_file_abs}" ]; then
        echoerr "Error: could not find \"${qpf_file_abs}\"\n"

        echowarn "Here are some .qpf that could be valid.. "
		find ./ -name *.qpf
        exit 1
    fi

    # Check for qsys file
    if [ ! -f "${qsys_file_abs}" ]; then
        echoerr "Error: no Qsys system found in \"${quartus_project_dir_abs}/\""
        exit 1
    fi

    if [ -z ${hps_module_name} ]; then
        echoerr "Error: no HPS module found in \"${qsys_file_abs}\""
        exit 1
    fi

    if [ ! -f "${quartus_project_setup_tcl_file_abs}" ]; then
        echoerr "Error: could not find \"${quartus_project_setup_tcl_file_abs}\""
        exit 1
    fi

    if [ ! -f "${fpga_device_pin_assignment_tcl_file_abs}" ]; then
        echoerr "Error: no \"pin_assignment_*.tcl\" file found in \"${quartus_project_dir_abs}/\""
        exit 1
    fi

    if [ -z "${fpga_device_part_number}" ]; then
        echoerr "Error: no FPGA device part number found in \"${fpga_device_pin_assignment_tcl_file_abs}\""
        exit 1
    fi

    if [ ! -f "${sdcard_image_file_abs}" ]; then
        echoerr "Error: could not find \"${sdcard_image_file_abs}/\""
        exit 1
    fi


	if [ "$(echo "${sdcard_abs}" | grep -P "/dev/sd\w.*$")" ]; then
		sdcard_fat32_partition_number="1"
		sdcard_dev_ext3_id="2"
		sdcard_preloader_partition_number="3"
	elif [ "$(echo "${sdcard_abs}" | grep -P "/dev/mmcblk\w.*$")" ]; then
		sdcard_fat32_partition_number="p1"
		sdcard_dev_ext3_id="p2"
		sdcard_preloader_partition_number="p3"
	else 
		echoerr "Error: could not find \"${sdcard_image_file_abs}/\" partitions"
		exit 1
	fi

	sdcard_ext3_abs="${sdcard_abs}${sdcard_dev_ext3_id}"
	sdcard_fat32_abs="${sdcard_abs}${sdcard_fat32_partition_number}"
	sdcard_preloader_abs="${sdcard_abs}${sdcard_preloader_partition_number}"


	echoinfo "Sd card ${sdcard_abs}"
	echoinfo "  Fat32 ${sdcard_fat32_abs}"
	echoinfo "  ext3  ${sdcard_ext3_abs}"
	echoinfo "  Preloader ${sdcard_preloader_abs}"

}

generate_qsys_system() {
    echo "Generating Qsys system [START]"

    shopt -s globstar
    for i in **/*.qsys; do # Whitespace-safe and recursive
        local random_qsys_file="$(readlink -e "${i}")"
        local random_qsys_file_no_extension="${random_qsys_file%.*}"
        rm -rf "${random_qsys_file_no_extension}"
    done

    rm -rf "${quartus_project_dir_abs}/.qsys_edit"
    rm -rf "${sopcinfo_file_abs}"

    qsys-generate "${qsys_file_abs}" --synthesis=VHDL --output-directory="${qsys_output_dir_abs}" --part="${fpga_device_part_number}"
    #pushd "./hw/quartus"
    #make qsys_compile
    #popd
    echodef "Generating Qsys system $done_string"
}

compile_quartus_project() {
    echodef "Compiling Quartus project [START]"


    pushd "${quartus_project_dir_abs}"

    rm -rf "c5_pin_model_dump.txt"
    rm -rf "db"
    rm -rf "hps_isw_handoff"
    rm -rf "hps_sdram_p0_all_pins.txt"
    rm -rf "hps_sdram_p0_summary.csv"
    rm -rf "incremental_db"
    rm -rf "output_files"
    rm -rf "PLLJ_PLLSPE_INFO.txt"
    rm -rf "${quartus_project_name_no_extension}.qsf"
    rm -rf "${quartus_project_name_no_extension}.qws"


    quartus_sh -t "${quartus_project_setup_tcl_file_abs}" "${quartus_project_name_no_extension}" "${qsys_file_name_no_extension}"
    quartus_map --read_settings_files=on --write_settings_files=off "${quartus_project_name_no_extension}" -c "${quartus_project_name_no_extension}"

    # it is normal for the following script to report an error, but it was sucessfully executed


    quartus_sh -t "${quartus_project_setup_tcl_file_abs}" "${quartus_project_name_no_extension}" "${qsys_file_name_no_extension}"

    set +e
    echogood " \n\n *** It is normal that the script fails. The execution is correct. Don't worry ;) *** 
             \n   ************************************************************************************\n "
    
	ddr3_pin_assignment_script="$(find . -name "hps_sdram_p0_pin_assignments.tcl")"
    quartus_sta -t "${ddr3_pin_assignment_script}" "${quartus_project_name}"
#    quartus_fit -t "${hps_sdram_pin_assignment_tcl_file_abs}" "${quartus_project_name_no_extension}"


	# Fitter
    quartus_fit "${quartus_project_name}"

    # Assembler
    quartus_asm "${quartus_project_name}"

	quartus_sh --flow compile "${quartus_project_name_no_extension}"

 	echoinfo "Report summary copied to ./result/"
    mv ./hw/quartus/output_files/"${quartus_project_name_no_extension}".summary "./results/`date`"

    popd
    set -e

    echodef "Compiling Quartus project $done_string"
   


}

convert_sof_to_rbf() {
    echodef "Converting sof to rbf [START]"
    quartus_cpf -c "${sof_file_abs}" "${rbf_file_abs}"
    echodef "Converting sof to rbf $done_string"
}

generate_hps_qsys_header() {
    echodef "Generating HPS header file [START]"

    sopc-create-header-files \
    "${sopcinfo_file_abs}" \
    --single "${hps_header_file_abs}" \
    --module "${hps_module_name}"

    echodef "Generating HPS header file $done_string"
}

generate_preloader() {
    echodef "Generating preloader [START]"

    rm -rf "${preloader_target_dir_abs}"
    mkdir -p "${preloader_target_dir_abs}"

    bsp-create-settings \
    --bsp-dir "${preloader_target_dir_abs}" \
    --preloader-settings-dir "${preloader_settings_dir_abs}" \
    --settings "${preloader_settings_file_abs}" \
    --type spl \
    --set spl.CROSS_COMPILE "${cross_compile_preloader}" \
    --set spl.PRELOADER_TGZ "${preloader_source}" \
    --set spl.boot.BOOTROM_HANDSHAKE_CFGIO "1" \
    --set spl.boot.BOOT_FROM_NAND "0" \
    --set spl.boot.BOOT_FROM_QSPI "0" \
    --set spl.boot.BOOT_FROM_RAM "0" \
    --set spl.boot.BOOT_FROM_SDMMC "1" \
    --set spl.boot.CHECKSUM_NEXT_IMAGE "1" \
    --set spl.boot.EXE_ON_FPGA "0" \
    --set spl.boot.FAT_BOOT_PARTITION "1" \
    --set spl.boot.FAT_LOAD_PAYLOAD_NAME "$(basename ${uboot_img_file_abs})" \
    --set spl.boot.FAT_SUPPORT "1" \
    --set spl.boot.FPGA_DATA_BASE "0xffff0000" \
    --set spl.boot.FPGA_DATA_MAX_SIZE "0x10000" \
    --set spl.boot.FPGA_MAX_SIZE "0x10000" \
    --set spl.boot.NAND_NEXT_BOOT_IMAGE "0xc0000" \
    --set spl.boot.QSPI_NEXT_BOOT_IMAGE "0x60000" \
    --set spl.boot.RAMBOOT_PLLRESET "1" \
    --set spl.boot.SDMMC_NEXT_BOOT_IMAGE "0x40000" \
    --set spl.boot.SDRAM_SCRUBBING "0" \
    --set spl.boot.SDRAM_SCRUB_BOOT_REGION_END "0x2000000" \
    --set spl.boot.SDRAM_SCRUB_BOOT_REGION_START "0x1000000" \
    --set spl.boot.SDRAM_SCRUB_REMAIN_REGION "1" \
    --set spl.boot.STATE_REG_ENABLE "1" \
    --set spl.boot.WARMRST_SKIP_CFGIO "1" \
    --set spl.boot.WATCHDOG_ENABLE "1" \
    --set spl.debug.DEBUG_MEMORY_ADDR "0xfffffd00" \
    --set spl.debug.DEBUG_MEMORY_SIZE "0x200" \
    --set spl.debug.DEBUG_MEMORY_WRITE "0" \
    --set spl.debug.HARDWARE_DIAGNOSTIC "0" \
    --set spl.debug.SEMIHOSTING "0" \
    --set spl.debug.SKIP_SDRAM "0" \
    --set spl.performance.SERIAL_SUPPORT "1" \
    --set spl.reset_assert.DMA "0" \
    --set spl.reset_assert.GPIO0 "0" \
    --set spl.reset_assert.GPIO1 "0" \
    --set spl.reset_assert.GPIO2 "0" \
    --set spl.reset_assert.L4WD1 "0" \
    --set spl.reset_assert.OSC1TIMER1 "0" \
    --set spl.reset_assert.SDR "0" \
    --set spl.reset_assert.SPTIMER0 "0" \
    --set spl.reset_assert.SPTIMER1 "0" \
    --set spl.warm_reset_handshake.ETR "1" \
    --set spl.warm_reset_handshake.FPGA "1" \
    --set spl.warm_reset_handshake.SDRAM "0"

    bsp-generate-files \
    --bsp-dir "${preloader_target_dir_abs}" \
    --settings "${preloader_settings_file_abs}"

    pushd "${preloader_target_dir_abs}"
    make -j4
	rm -rf ./uboot-socfpga
    popd



    echodef "Generating preloader $done_string"
}


clone_repo_uboot() {

	echoinfo "Clone Uboot repository"

	checkout_revision_uboot="b104b3dc1dd90cdbf67ccf3c51b06e4f1592fe91"
	#checkout_revision_uboot="4ed6ed3c27a069a00c8a557d606a05276cc4653e"


	git_revision_uboot=""

	if [ ! -d "$uboot_source_dir_abs" ]; then
		mkdir -p $uboot_source_dir_abs
	fi

	pushd $uboot_source_dir_abs

set +e
	git_revision_uboot=`git log | grep "commit $checkout_revision_uboot"`
	echoinfo "Uboot GIT revisions:  $git_revision_uboot"
set -e

	# Need to compile for ARM
	export CROSS_COMPILE=$cross_compile_linux

	if [ "$git_revision_uboot" != "commit $checkout_revision_uboot" ]; then
		echodef "Not valid revision. Cloning from repo"
		git clone $uboot_git_repo $uboot_source_dir_abs
		make distclean
		git checkout $checkout_revision_uboot
		
	fi


	
	make mrproper
	make -j4 $uboot_make_parameter

	cp $presets_folder_a/socfpga_cyclone5_socdk.h $uboot_source_dir_abs/include/configs/
	cp $presets_folder_a/socfpga_de0_nano_soc.h $uboot_source_dir_abs/include/configs/
	
	
	make -j4

	popd

}


generate_uboot_script() {


	clone_repo_uboot
    
	echodef "Generating uboot script [START]"


    cat <<EOF > "${uboot_script_file_src_abs}"

# When booting a Linux kernel, U-Boot passes a string command line as kernel parameter
# U-Boot uses its bootargs environment variable as parameter.
echo --- Uboot start ---

echo --- Reseting default commands ---
env default -a

echo "--- Setting Env variables ---"
# Set the devicetree image to be used
setenv fdtimage ${device_tree_blob_file_name};

# Set the kernel image to be used
setenv bootimage zImage;

# address to which the device tree will be loaded
setenv fdtaddr 0x00000100

#1018M
setenv mmcboot 'setenv bootargs mem=${linux_kernel_mem_bootarg} console=ttyS0,115200 root=\${mmcroot} rw rootwait;bootz \${loadaddr} - \${fdtaddr}'

# load linux kernel image and device tree to memory
setenv mmcload 'mmc rescan; \
fatload mmc 0:1 \${loadaddr} \${bootimage}; \
fatload mmc 0:1 \${fdtaddr} \${fdtimage}'
#1 part for fat32

# sdcard ext3 identifier
setenv mmcroot /dev/mmcblk0${sdcard_dev_ext3_id}

# standard input/output
setenv stderr serial
setenv stdin serial
setenv stdout serial

saveenv

# When booting a Linux kernel, U-Boot passes a string command line as kernel parameter
# U-Boot uses its bootargs environment variable as parameter.
# Load rbf from FAT partition into memory
fatload mmc 0:1 \$fpgadata $(basename ${rbf_file_abs});
# Program FPGA
fpga load 0 \$fpgadata \$filesize;
# enable the FPGA 2 HPS and HPS 2 FPGA bridges
#run bridge_enable_handoff; does not exist anymor e:D
bridge enable;
echo "--- Booting Linux ---"
# mmcload & mmcboot are scripts included in the default socfpga uboot environment
# it loads the devicetree image and kernel to memory
run mmcload;
# mmcboot sets the bootargs and boots the kernel with the dtb specified above
run mmcboot;



EOF
	
	echodef "Make script image [START]"
    mkimage -A arm -O linux -T script -C none -a 0 -e 0 -n "${quartus_project_name_no_extension}" -d "${uboot_script_file_src_abs}" "${uboot_script_file_bin_abs}"
	ls -l ${uboot_script_file_bin_abs}
    echodef "Generating uboot script $done_string"
}


generate_sd_card_partitions(){

	echoinfo "Partition the SD cards"


	check_sd_card_plug "${sdcard_abs}"


    set +e
    sudo umount ${sdcard_ext3_abs}
    sudo umount ${sdcard_fat32_abs}
    set -e
    
    echoinfo "Writing sdcard image [START]"
	number_of_byte=`du -k "${sdcard_image_file_abs}" | cut -f1`
	echoinfo "Trying to transfer $number_of_byte bytes"	
	sudo dd if="${sdcard_image_file_abs}" of="${sdcard_abs}" bs="1M"&
    sudo sh -c "while pkill -10 ^dd$; do sleep 10; done"
	
	sudo sync
    echoinfo "Writing sdcard image $done_string"


}

write_config_to_sd() {

	echoinfo "Write configurations files to SD card"

    check_sd_card_plug "${sdcard_abs}"



    set +e
    sudo umount ${sdcard_ext3_abs}
    sudo umount ${sdcard_fat32_abs}
    set -e
    
    sudo mkdir -p "$sdcard_ext3_mount_point_abs"
    sudo mount -t ext3 "${sdcard_ext3_abs}" "$sdcard_ext3_mount_point_abs"

    #Copy interfaces configurations
    echowarn "Set the ip to static : /etc/network/interfaces"    
	sudo cp "$configs_folder_a/etc_network_interfaces" "$sdcard_ext3_mount_point_abs/etc/network/interfaces"

    #Add command ifup eth0 to /etc/profile    
    echowarn "Add command ifup eth0 to /etc/profile"
    sudo cp "$configs_folder_a/etc_profile" "$sdcard_ext3_mount_point_abs/etc/profile"

	if [ -f "rc.local" ]; then
		sudo cp "$configs_folder_a/rc.local" "$sdcard_ext3_mount_point_abs/etc/rc.local"
	fi

    #Change the date
    echowarn "Changing the date"
    sudo cp "$configs_folder_a/timestamp" "$sdcard_ext3_mount_point_abs/etc/timestamp"

    echowarn "Changing messages"
    sudo cp "$configs_folder_a/issue.net" "$sdcard_ext3_mount_point_abs/etc/issue.net"
    sudo cp "$configs_folder_a/issue" "$sdcard_ext3_mount_point_abs/etc/issue"

	sudo sync
    sudo umount "${sdcard_ext3_mount_point_abs}"
    sudo rm -rf "$sdcard_ext3_mount_point_abs"

    sudo mkdir -p "${sdcard_fat32_mount_point_abs}"
    sudo mount -t vfat "${sdcard_fat32_abs}" "${sdcard_fat32_mount_point_abs}"


    sudo dd if="${preloader_mkimage_bin_file_abs}" of="${sdcard_preloader_abs}"
# bs="64k" seek=0
    sudo sync
    echodef "Writing preloader $done_string"


	sudo rm -f ${sdcard_fat32_mount_point_abs}/*

    sudo cp "${uboot_img_file_abs}" "${sdcard_fat32_mount_point_abs}"
    echodef "Writing uboot $done_string"

    sudo cp "${uboot_script_file_bin_abs}" "${sdcard_fat32_mount_point_abs}"
    echodef "Writing uboot script $done_string"

    sudo rm -rf "${sdcard_fat32_mount_point_abs}/"*".rbf" 
	echodef "Remove pre-installed rbf file"
    sudo cp "${rbf_file_abs}" "${sdcard_fat32_mount_point_abs}"
    echodef "Writing FPGA raw binary file $done_string"

    sudo cp "$linux_folder_a/zImage" "${sdcard_fat32_mount_point_abs}/zImage"
    echodef "Copy zImage $done_string"

    sudo cp "$linux_folder_a/$device_tree_blob_file_name" "${sdcard_fat32_mount_point_abs}/$device_tree_blob_file_name"
    echodef "Copy Device Tree Binary $done_string"

	dtc -I dtb -O dts -o "$linux_folder_a/$device_tree_output_source_file_name" "$linux_folder_a/$device_tree_blob_file_name"
    echodef "Copy DTS generated from DTB $done_string"

	ls -l ${sdcard_fat32_mount_point_abs}

    sudo sync

    sudo umount "${sdcard_fat32_mount_point_abs}"
    sudo rm -rf "${sdcard_fat32_mount_point_abs}"


    set +e
    sudo umount ${sdcard_fat32_abs}
    sudo umount ${sdcard_ext3_abs}
    set -e


	print_useful_info
}



clone_repo_linux() {

	echoinfo "Clone Linux Repository"
	git_revision_linux=""

	if [ ! -d "$linux_src_dir" ]; then
		mkdir -p $linux_src_dir
		echodef "No previous linux version found in folder $linux_src_dir"
		echodef "Try cloning one (it might take a while (~4GB) :o)"
		git clone $linux_src_git_repo $linux_src_dir
	fi

	echodef "Jump into linux source: "
	echodef "    $linux_src_dir"

	# Need to compile for ARM
	export ARCH=$cross_compile_arch
	export CROSS_COMPILE=$cross_compile_linux

	pushd $linux_src_dir

#set +e
#	echodef "Print current version of kernel"
#	git_revision_linux=`git log | grep "commit" -m 1`
#	linux_version=`git log | grep "Linux" -m 1`
#	echodef $git_revision_linux
#	echodef $linux_version
#set -e

#	#If you need a specific kernel version, change the commit
#	if [ "$linux_checkout_revision_linux" != "null" ]; then
#		echodef "Get commit $git_revision_linux"
#		if [ "$linux_checkout_revision_linux" == "master" ]; then
#			make distclean
#			git checkout master
#		elif [ "$git_revision_linux" != "commit $linux_checkout_revision_linux" ]; then
#			make distclean
#			git checkout $linux_checkout_revision_linux
#		fi
#	fi

	popd

}

build_linux_kernel(){


	echoinfo "Build linux kernel"

	clone_repo_linux
	echodef "Get correct kernel version $done_string"

	#Generate the device tree source: $1 in arch/arm/boot/dts/
	#Generate the kernel: zImage in arch/arm/boot/
	pushd $linux_src_dir

	export ARCH=$cross_compile_arch
	export CROSS_COMPILE=$cross_compile_linux

	if [ "$linux_menuconfig" == "1" ]; then
		make menuconfig
	fi	

	echowarn "\nBuild the kernel \n "
	echowarn "Copy $custom_device_tree_source_abs to $linux_dts_file"
	cp $custom_device_tree_source_abs $linux_dts_file
	make socfpga_defconfig

	echowarn "\nBuild zImage\n"
	make -j4 zImage
	ls -l $linux_zImage_file
	echo ""

	echowarn "\nBuild the device tree\n "
	make -j4 $device_tree_blob_file_name
	ls -l $linux_dtb_file
	echo ""


	#Both should be copied into the SD card
	echowarn "Copy zImage and $device_tree_blob_file_name to $linux_folder_a"
	cp $linux_zImage_file $linux_folder_a/
	cp $linux_dtb_file $linux_folder_a/

	popd

}


generate_dtb(){

	echoinfo "Generate Device tree Binary"
	sopc2dts_github="https://github.com/altera-opensource/sopc2dts.git"
	dtb_folder_a=`readlink -f ./sw/linux/dtb`

	presets_folder_a=`readlink -f ./sw/presets`
	sopc2dts_folder_a=`readlink -f ./sw/linux/dtb/sopc2dts`
	quartus_folder_a=`readlink -f ./hw/quartus`

	pushd $dtb_folder_a

		if [ ! -d ./sopc2dts ]; then
			git clone $sopc2dts_github
			make
		fi

		cp $presets_folder_a/*.xml $sopc2dts_folder_a/
		cp $quartus_folder_a/soc_system.sopcinfo $sopc2dts_folder_a/soc_system.sopcinfo
		
		$sopc2dts_folder_a/make_dtb.sh $device_tree_source_name
		
		cp $sopc2dts_folder_a/$device_tree_source_name.dtb $linux_folder_a/

	popd

}


call_menu_make_all(){

	old_IFS=$IFS
	echodef ""
	hcenter " --------------------- "
	hcenter " Menu_MakeAll"
	hcenter " --------------------- "
	echodef ""
	echodef ""


	PS3="Menu #?> "
	IFS=$old_IFS


	select opt in $OPTIONS_MENU; do

		echoinfo "\n $opt\n"
		
		if [ "$opt" = "Quit" ]; then
			print_useful_info
			break
		elif [ "$opt" = "Make_all" ]; then


			#generate_qsys_system
			#compile_quartus_project

			convert_sof_to_rbf
			generate_hps_qsys_header
			
			generate_preloader

			##Generate the device tree source: $1 in arch/arm/boot/dts/
			##Generate the kernel: zImage in arch/arm/boot/generate_preloader
			generate_uboot_script

			build_linux_kernel
			copy_hps_to_folders

			#generate_dtb $device_tree_source_name
			$sw_folder_a/make_applications.sh
	
			if [ -n "$upload_linux_image" ]; then
				generate_sd_card_partitions
			fi
			write_config_to_sd
			$sw_folder_a/copy_to_sd.sh $sdcard_abs $sdcard_ext3_abs $sdcard_fat32_abs
	
		elif [ "$opt" = "Clean_build" ]; then
			echo "Clean"
		elif [ "$opt" = "Make_Quartus" ]; then
			compile_quartus_project
		elif [ "$opt" = "Make_Qsys" ]; then
			generate_qsys_system
		elif [ "$opt" = "Make_uboot" ]; then
			generate_uboot_script
		elif [ "$opt" = "Make_linux_kernel" ]; then
			build_linux_kernel
		elif [ "$opt" = "Generate_dtb" ]; then
			generate_dtb $device_tree_source_name
		elif [ "$opt" = "Make_Send_Exec_Get_SSH" ]; then
			$sw_folder_a/make_applications.sh
			$sw_folder_a/ssh_send_folders.sh
			$sw_folder_a/ssh_launch_applications.sh
			$sw_folder_a/get_images.sh
		elif [ "$opt" = "Make_applications" ]; then
			$sw_folder_a/make_applications.sh
		elif [ "$opt" = "Send_applications" ]; then
			$sw_folder_a/ssh_send_folders.sh
		elif [ "$opt" = "Exec_applications" ]; then
			$sw_folder_a/ssh_launch_applications.sh
		elif [ "$opt" = "Push_to_sd_card" ]; then
			write_config_to_sd
			$sw_folder_a/copy_to_sd.sh $sdcard_abs $sdcard_ext3_abs $sdcard_fat32_abs

		elif [ "$opt" = "Get_Results" ]; then
			set +e
			$sw_folder_a/get_images.sh
			set -e

		elif [ "$opt" = "Generate_sd_partitions" ]; then

			generate_sd_card_partitions
		else
		 	echowarn "Bad option"
		fi

		echodef ""
	done


}

generate_presets(){
	pushd $presets_folder_a
		./make_preset.sh
	popd
}

# main program #################################################################
# check argument count
# sdcard is optional -> -ge 1 instead of -eq 2
if [ "${#}" -lt 1 ]; then
    usage
    exit 1
fi


clear


validate_required_files
generate_presets


call_menu_make_all



################################################################################



trap : 0
echogood " *** DONE `basename "$0"` *** "


# in order to write modules for this kernel, compile it like this:
# export CROSS_COMPILE=arm-linux-gnueabihf-
# make ARCH=arm socfpga_defconfig
# copy and extract terasic /proc/.config.gz to your kernel source directory
# make ARCH=arm
# copy newly built zImage to fat32 partition
