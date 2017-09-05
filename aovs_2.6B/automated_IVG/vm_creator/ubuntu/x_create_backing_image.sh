#!/bin/bash
script_dir="$(dirname $(readlink -f $0))"

./IVG_folder/vm_creator/ubuntu/1_cloud_init.sh
./IVG_folder/vm_creator/ubuntu/2_install_vm.sh
./IVG_folder/vm_creator/ubuntu/3_copy_vm_scripts.sh
./IVG_folder/vm_creator/ubuntu/4_run_vm_scripts.sh
