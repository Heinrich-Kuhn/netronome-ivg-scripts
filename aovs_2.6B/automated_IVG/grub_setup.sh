#!/bin/bash

cp /etc/default/grub /etc/default/grub.backup
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=""/GRUB_CMDLINE_LINUX_DEFAULT="intel_iommu=on iommu=pt intremap=on"/g'  /etc/default/grub
update-grub

echo "Grub updated"
