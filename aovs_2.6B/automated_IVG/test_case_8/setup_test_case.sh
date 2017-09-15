#!/bin/bash

VM_NAME=$1
VM_CPU_COUNT=$2

scrdir="$(dirname $(readlink -f $0))"

$scrdir/1_bind_VFIO-PCI_driver.sh || exit -1
$scrdir/2_configure_AOVS.sh || exit -1
$scrdir/3_configure_AOVS_rules.sh $VM_NAME || exit -1
$scrdir/4_guest_xml_configure.sh $VM_NAME || exit -1
$scrdir/5_vm_pinning.sh $VM_NAME $VM_CPU_COUNT || exit -1
$scrdir/6_await_vm.sh $VM_NAME || exit -1

echo "DONE($(basename $0))"
exit 0
