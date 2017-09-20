#!/bin/bash

script_dir="$(dirname $(readlink -f $0))"
IVG_dir="$(echo $script_dir | sed 's/\(IVG\).*/\1/g')"
$IVG_dir/helper_scripts/vm_shutdown.sh

./0_download_cloud_image.sh
if [ $? == 1 ]
then exit 1
fi
./1_cloud_init.sh
./2_install_vm.sh
./3_copy_vm_scripts.sh
./4_run_vm_scripts.sh
