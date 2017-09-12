#!/bin/bash

VM_NAME=$1
VM_CPU_COUNT=$2
XVIO_CPU_COUNT=$3

script_dir="$(dirname $(readlink -f $0))"

echo $VM_NAME
echo $VM_CPU_COUNT

./IVG_folder/test_case_7/1_bind_IGB-UIO_driver.sh
./IVG_folder/test_case_7/2_configure_ovs.sh $XVIO_CPU_COUNT
./IVG_folder/test_case_7/3_configure_ovs_rules.sh
./IVG_folder/test_case_7/4_configure_apparmor.sh
./IVG_folder/test_case_7/5_configure_guest_xml.sh $VM_NAME
./IVG_folder/test_case_7/6_vm_pinning.sh $VM_NAME $VM_CPU_COUNT $XVIO_CPU_COUNT
./IVG_folder/test_case_7/7_start_vm.sh $VM_NAME
