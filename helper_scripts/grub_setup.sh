#!/bin/bash

card_node=$(cat /sys/bus/pci/drivers/nfp/0*/numa_node | head -n1 | cut -d " " -f1)
nfp_cpu_list=$(lscpu -a -p | awk -F',' -v var="$card_node" '$4 == var {printf "%s%s",sep,$1; sep=" "} END{print ","}')

cp /etc/default/grub /etc/default/grub.backup
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=""/GRUB_CMDLINE_LINUX_DEFAULT="intel_iommu=on iommu=pt intremap=on isolcpus="$nfp_cpu_list""/g'  /etc/default/grub
update-grub

echo "Grub updated"
