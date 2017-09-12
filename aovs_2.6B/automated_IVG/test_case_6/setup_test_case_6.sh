#!/bin/bash

VM_NAME=$1
VM_CPU_COUNT=$2
BONDBR_DEST_IP=$3 
BONDBR_SRC_IP=$4

script_dir="$(dirname $(readlink -f $0))"

./IVG_folder/test_case_2/1_bind_VFIO-PCI_driver.sh
./IVG_folder/test_case_2/2_configure_AOVS.sh
./IVG_folder/test_case_2/3_configure_AOVS_rules.sh $BONDBR_DEST_IP $BONDBR_SRC_IP
./IVG_folder/test_case_2/4_guest_xml_configure.sh $VM_NAME
./IVG_folder/test_case_2/5_vm_pinning.sh $VM_NAME $VM_CPU_COUNT
./IVG_folder/test_case_2/6_start_vm.sh $VM_NAME

