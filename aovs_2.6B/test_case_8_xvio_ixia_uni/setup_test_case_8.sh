#!/bin/bash

if [ -z "$1" ] && [ -z "$2" ] && [ -z "$3" ]; then
      echo "ERROR: Not enough arguments where passed"
      echo "Example: ./6_vm_pinning <vm_name> <number_of_vm_cpu's> <number_of_xvio_cpu's"
      exit -1
   else
      VM_NAME=$1
      VM_CPU_COUNT=$2
      XVIO_CPU_COUNT=$3
fi

ovs-ctl start

script_dir="$(dirname $(readlink -f $0))"

echo $VM_NAME
echo $VM_CPU_COUNT

$script_dir/0_configure_hugepages.sh
$script_dir/1_bind_IGB-UIO_driver.sh
$script_dir/2_configure_ovs.sh $XVIO_CPU_COUNT
$script_dir/3_configure_ovs_rules.sh
$script_dir/4_configure_apparmor.sh
$script_dir/5_configure_guest_xml.sh $VM_NAME
$script_dir/6_vm_pinning.sh $VM_NAME $VM_CPU_COUNT $XVIO_CPU_COUNT
