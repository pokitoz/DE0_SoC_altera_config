#!/bin/bash

set -e

# make sure to be in the same directory as this script #########################
current_script_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )


source ../../setup_env.sh


pushd "${current_script_dir}"

abort()
{
	echoerr "An error occurred in `basename "$0"`. Exiting..."
	exit 1
}

trap 'abort' 0

echoinfo "Start change_image.sh"

folder_part1="./part1"
folder_part2="./part2"
folder_part3=""
image_file="$1"


if [ ! -f "$image_file" ]; then
	echoerr "Could not find the specified .img: $image_file"	
	exit 0
fi

fdisk -l -u $image_file

start_1=`fdisk -l -u $image_file | grep ".img1" | grep -E -o "\s[0-9]+\s"`
start_2=`fdisk -l -u $image_file | grep ".img2" | grep -E -o "\s[0-9]+\s"`
start_3=`fdisk -l -u $image_file | grep ".img3" | grep -E -o "\s[0-9]+\s"`
units=`fdisk -l -u $image_file | grep -E "^Units = sectors of "`

#Replace the * by x to avoid bash problems
start_1="${start_1/\*/x}"
start_2="${start_2/\*/x}"
start_3="${start_3/\*/x}"
units="${units/\*/x}"



# Number of bytes per sector
units_array=(${units})
units="${units_array[8]}"
echo "Number of byte per sector : $units"

start_1_array=(${start_1})
start_1="${start_1_array[0]}"
echo "start img1=$start_1"
start_2_array=(${start_2})
start_2="${start_2_array[0]}"
echo "start_img2=$start_2"
start_3_array=(${start_3})
start_3="${start_3_array[0]}"
echo "start_img3=$start_3"

echo ""



#Look for the size of the device in bytes and calculate the new number of cylinders 
#using the following formula, dropping all fractions:
# <size> = units * start_point
first_part=$(($start_1*$units))
echo "Start at $first_part for FAT32"
second_part=$(($start_2*$units))
echo "Start at $second_part for EXT4"
third_part=$(($start_3*$units))
echo "Start at $third_part for Unknown"

echo ""

set +e
echo "Unmount $folder_part1 $folder_part2 $folder_part3"
sudo umount $folder_part1 $folder_part2 $folder_part3
set -e

echo "Create folders $folder_part1 $folder_part2 $folder_part3"
mkdir -p $folder_part1 $folder_part2 $folder_part3


echo "Mount image parts"
sudo mount -o rw,offset=$first_part $image_file $folder_part1
sudo mount -o rw,offset=$second_part $image_file $folder_part2
#sudo mount -o rw,offset=$third_part $image_file $folder_part3

echo ""

read -p "Push [ENTER] when modifications are done..."

sync

echo "Unmount $folder_part1 $folder_part2 $folder_part3"
sudo umount $folder_part1 $folder_part2 $folder_part3

echo "Remove folders $folder_part1 $folder_part2 $folder_part3"
rm -rf $folder_part1 $folder_part2 $folder_part3

popd


trap : 0
echo -e "$c_good *** DONE `basename "$0"` *** $c_default"
