#!/bin/bash

script_dir="$(dirname $(readlink -f $0))"

$script_dir/0_download_cloud_image.sh || exit -1
$script_dir/1_cloud_init.sh || exit -1
$script_dir/2_install_vm.sh || exit -1
$script_dir/3_copy_vm_scripts.sh || exit -1
$script_dir/4_run_vm_scripts.sh

exit 0
