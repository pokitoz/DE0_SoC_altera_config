#!/bin/bash

# This script is preconfigured and run the compile.sh script with hardcoded parameters.
# a log is created in the folder ./log/


# make sure to be in the same directory as this script
script_dir_abs=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd "${script_dir_abs}"

./compile.sh hw/quartus/fpga_soc.qpf /dev/mmcblk0 2>&1 | tee ./log/"`date`"
