#!/bin/bash

./0_download_cloud_image.sh
if [ $? == 1 ]
then exit 1
fi
./1_cloud_init.sh
./2_install_vm.sh
./3_copy_vm_scripts.sh
./4_run_vm_scripts.sh
