#!/bin/bash

set -e


source ./setup_env.sh


# make sure to be in the same directory as this script #########################
script_dir_abs=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd "${script_dir_abs}"



# Functions definitions ########################################################

abort() {
	echo -e "$c_error Error in `basename "$0"`$c_default"
    exit 1
}

trap 'abort' 0


echo -e "$c_good *** START `basename "$0"` *** $c_default"

set +e
echo -e "$c_info Install tree package /not needed, CTRL+C if you don't want) $c_default"
sudo apt-get install tree
set -e


pushd $linux_dir_r

popd

pushd $tools_dir_r

popd


pushd $dev_dir_r

popd

pushd $preset_dir_r

popd

echo -e "$c_info Final hierarchy (if tree package is installed)$c_default"
set +e
tree -d --filelimit 10000 -L 2 ./
set -e



echo -e "$c_info Make all the scripts executable using chmod $c_default"


trap : 0
echo -e "$c_good *** DONE `basename "$0"` *** $c_default"
