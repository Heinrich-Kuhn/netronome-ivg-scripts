#!/bin/bash

if [ -z "$1" ] && [ -z "$2" ] && [ -z "$3" ] && [ -z "$4" ]; then
    echo "ERROR: Not enough parameters where passed to this script"
    echo "Example: ./setup_test_case_6.sh <vm_name> <number_of_vm_cpu's> <local_bridge_ip> <remote_bridge_ip>"
    exit -1
else
    VM_NAME=$1
    VM_CPU_COUNT=$2
    BONDBR_DEST_IP=$3 
    BONDBR_SRC_IP=$4    
fi 

ovs-ctl start

script_dir="$(dirname $(readlink -f $0))"

#When running manually
IVG_dir="$(echo $script_dir | sed 's/\(IVG\).*/\1/g')"
$IVG_dir/helper_scripts/vm_shutdown_all.sh > /dev/null

#When running in auto mode
/root/IVG_folder/helper_scripts/vm_shutdown_all.sh > /dev/null

$script_dir/1_bind_VFIO-PCI_driver.sh
$script_dir/2_configure_AOVS.sh
$script_dir/3_configure_AOVS_rules.sh $BONDBR_DEST_IP $BONDBR_SRC_IP
$script_dir/4_guest_xml_configure.sh $VM_NAME
$script_dir/5_vm_pinning.sh $VM_NAME $VM_CPU_COUNT

echo "DONE($(basename $0))"
exit 0
