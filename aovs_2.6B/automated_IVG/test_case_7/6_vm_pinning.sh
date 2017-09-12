#!/bin/bash

VM_NAME=$1
CPU_COUNT=$2
XVIO_CPU_COUNT=$3

card_node=$(cat /sys/bus/pci/drivers/nfp/0*/numa_node | head -n1 | cut -d " " -f1)
nfp_cpu_list=$(lscpu -a -p | awk -F',' -v var="$card_node" '$4 == var {printf "%s%s",sep,$1; sep=" "} END{print ""}')
nfp_cpu_list=( $nfp_cpu_list )

for counter in $(seq 0 $((XVIO_CPU_COUNT-1)))
  do
	nfp_cpu_list=( "${nfp_cpu_list[@]:1}" )
done


echo "nfp_cpu_list: ${nfp_cpu_list[@]}"
for counter in $(seq 0 $((CPU_COUNT)))
  do

    virsh --quiet vcpupin $VM_NAME $counter ${nfp_cpu_list[$counter+1]} --config
  done
virsh vcpupin $VM_NAME
