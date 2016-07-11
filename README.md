# altera_condif_de0soc


= SD card boot image =

Platform: <platform>
Application: <elf>

1. Copy the contents of this directory to an SD card
2. Set boot mode to SD
   - All MSEL switches must be set to 0 
3. Insert SD card and turn board on

The Blue LED (LED9) means that the 3V3 convertor is activated
The Orange LED (LED10: CONF_DONE) means that the FPGA is configured

KEY4 (HPS_RESET_N) is the cold reset
Active low input which resets all HPS logics that can be reset. 
KEY3 (HPS_WARM_RST_N) is the warm reset.
Active low input affects the system reset domain for debug purpose.

ftp://ftp.altera.com/up/pub/Altera_Material/Boards/DE0-Nano-SoC/DE0_Nano_SoC_User_Manual.pdf


Those scripts generates a complete system for a **DE0 Nano SoC** board.
The system contains:
   - Linux Kernel
   - Config of the FPGA (bitstream)


*Please download:*

(sources) and put it to the begining of the folder hierarchy.

#Run *./create_hierarchy.sh*
- Creates all the folders
- Download (if not already) the "altera_source.tar.gz" archive
- Uncompress and send the source to the proper folders
- Make all the script executable (chmod)

#Source ./setup_env.sh
To have all the necessary commands/variables

#./part_sd_card.sh <SD CARD ABSOLUTE PATH> <1 or 0>
This script will create the partitions needed to run linux on the SD card
You need to specify the path of the SD card: /dev/sdc
- This script will create a partition vfat32 (named boot) and a partition ext4 (named rootfs)
- If the second argument is 1, it calls ./sd_write_image.sh <SD CARD ABSOLUTE PATH>

#./sd_write_image.sh <SD CARD ABSOLUTE PATH>
This script will copy the linux image located in ./filesystem/ to the SD card specified.
All files in the SD card will be removed and the default configuration will be set

#./clean_file.sh
Remove all the generated files

#./copy_to_sd_card.sh <SD CARD ABSOLUTE PATH>
Copy all necessary files to the SD card.

Kernel images (pick one, or use the one given in the dropbox link)
