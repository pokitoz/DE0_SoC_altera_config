#!/bin/bash

# derived values ###############################################################
# Quartus
quartus_project_dir_abs="$(dirname "${qpf_file_abs}")"
quartus_project_name_with_extension="$(basename "${qpf_file_abs}")"
quartus_project_extension="${quartus_project_name_with_extension##*.}"
quartus_project_name_no_extension="${quartus_project_name_with_extension%.*}"
quartus_project_setup_tcl_file_abs="${quartus_project_dir_abs}/setup_project.tcl"

# FPGA
fpga_device_pin_assignment_tcl_file_abs="$(find "${quartus_project_dir_abs}" -maxdepth 1 -name "pin_assignment_*.tcl")"
fpga_device_part_number=""
if [ -f "${fpga_device_pin_assignment_tcl_file_abs}" ]; then
    fpga_device_part_number="$(cat "${fpga_device_pin_assignment_tcl_file_abs}" | grep -P "set_global_assignment\s+-name\s+DEVICE\s+.*" | perl -pe 's/set_global_assignment\s+-name\s+DEVICE\s+(\w+).*/\1/')"
fi
sof_file_abs="${quartus_project_dir_abs}/output_files/${quartus_project_name_no_extension}.sof"
rbf_file_abs="${quartus_project_dir_abs}/output_files/${quartus_project_name_no_extension}.rbf"

# Qsys
# search all .qsys files for the one that contains the hps module
qsys_file_abs=""
shopt -s globstar
for i in **/*.qsys; do # Whitespace-safe and recursive
    if [ "$(cat "${i}" | grep "altera_hps")" ]; then
        qsys_file_abs="$(readlink -e "${i}")"
    fi
done
qsys_file_name_with_extension="$(basename "${qsys_file_abs}")"
qsys_file_name_no_extension="${qsys_file_name_with_extension%.*}"
qsys_output_dir_abs="${quartus_project_dir_abs}/${qsys_file_name_no_extension}"
sopcinfo_file_abs="${quartus_project_dir_abs}/${qsys_file_name_no_extension}.sopcinfo"

# HPS
hps_module_name=""
if [ -f "${qsys_file_abs}" ]; then
    hps_module_name="$(cat "${qsys_file_abs}" | grep "altera_hps" | perl -pe 's/\s*<module name="(.*?)".*>.*/\1/')"
fi
hps_header_file_abs="${quartus_project_dir_abs}/${hps_module_name}.h"
hps_sdram_pin_assignment_tcl_file_abs="${qsys_file_name_no_extension}/synthesis/submodules/hps_sdram_p0_pin_assignments.tcl"



# Preloader
preloader_target_dir_abs="${script_dir_abs}/sw/preloader"
preloader_source="${SOCEDS_DEST_ROOT}/host_tools/altera/preloader/uboot-socfpga.tar.gz"
preloader_settings_dir_abs="${quartus_project_dir_abs}/hps_isw_handoff/${qsys_file_name_no_extension}_${hps_module_name}"
preloader_settings_file_abs="${preloader_target_dir_abs}/settings.bsp"
preloader_mkimage_bin_file_abs="${preloader_target_dir_abs}/preloader-mkpimage.bin"

# uboot
uboot_source_dir_abs="${preloader_target_dir_abs}/uboot-socfpga"
uboot_img_file_abs="${uboot_source_dir_abs}/u-boot.img"
uboot_script_file_src_abs="${uboot_source_dir_abs}/boot.script"
uboot_script_file_bin_abs="${uboot_source_dir_abs}/u-boot.scr"
uboot_git_repo="git://git.denx.de/u-boot.git"
uboot_make_parameter="socfpga_cyclone5_config"
# sdcard



sdcard_image_file_abs="${script_dir_abs}/sw/linux/DE0-Nano-SoC_Linux_Console.img"


# Device Tree
device_tree_blob_file_name_no_extention="socfpga_project"
device_tree_blob_file_name="$device_tree_blob_file_name_no_extention.dtb"

# Linux
#mem=nn[KMG]	[KNL,BOOT] Force usage of a specific amount of memory
#		Amount of memory to be used when the kernel is not able
#		to see the whole system memory or for test.
linux_dir="$(readlink -m "sw/linux")"
linux_src_dir="${linux_dir}/linux-source"
linux_zImage_file="$(readlink -m "${linux_src_dir}/arch/arm/boot/zImage")"
device_tree_source_name="socfpga_project"
linux_dts_file="$(readlink -m "${linux_src_dir}/arch/arm/boot/dts/$device_tree_source_name.dts")"
linux_dtb_file="$(readlink -m "${linux_src_dir}/arch/arm/boot/dts/$device_tree_source_name.dtb")"
linux_kernel_mem_bootarg='1018M'
#linux_checkout_revision_linux="9735a22799b9214d17d3c231fe377fc852f042e9"
linux_checkout_revision_linux="null"
linux_src_git_repo="https://github.com/torvalds/linux.git"
linux_menuconfig="0"
