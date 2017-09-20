#!/bin/bash

script_dir="$(dirname $(readlink -f $0))"
IVG_dir="$(echo $script_dir | sed 's/\(IVG\).*/\1/g')"
$IVG_dir/helper_scripts/y_vm_shutdown.sh

$script_dir/0_download_cloud_image.sh
if [ $? == 1 ]
then exit 1
fi
$script_dir/1_cloud_init.sh
$script_dir/2_install_vm.sh
$script_dir/3_copy_vm_scripts.sh
$script_dir/4_run_vm_scripts.sh
