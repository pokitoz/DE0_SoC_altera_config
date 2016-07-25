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



preloader_source="${SOCEDS_DEST_ROOT}/host_tools/altera/preloader/uboot-socfpga.tar.gz"
preloader_settings_dir_abs="${quartus_project_dir_abs}/hps_isw_handoff/${qsys_file_name_no_extension}_${hps_module_name}"

# sdcard


#socfpga_de0_nano_soc






