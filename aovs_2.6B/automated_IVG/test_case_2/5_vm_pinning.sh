#!/bin/bash

card_node=$(cat /sys/bus/pci/drivers/nfp/0*/numa_node | head -n1 | cut -d " " -f1)
nfp_cpu_list=$(lscpu -a -p | awk -F',' -v var="$card_node" '$4 == var {printf "%s%s",sep,$1; sep=" "} END{print ""}')

#Check if VM name is passed
if [ -z "$1" ]; then
   echo "Please pass a VM name that you whish to pin as the first parameter of this script..."
   exit 1
   else
   VM_NAME=$1
fi

if [ -z "$2" ]; then
   echo "Using default 4 CPU's for VM"
   else
   CPU_COUNT=$2
fi

CPU_COUNT=$2

echo $VM_NAME

nfp_cpu_list=($nfp_cpu_list)
echo "nfp_cpu_list: ${nfp_cpu_list[@]}"
sleep 5

for counter in $(seq 0 $((CPU_COUNT-1)))
  do
    virsh --quiet vcpupin $VM_NAME $counter ${nfp_cpu_list[$counter+1]} --config
  done
virsh vcpupin $VM_NAME
