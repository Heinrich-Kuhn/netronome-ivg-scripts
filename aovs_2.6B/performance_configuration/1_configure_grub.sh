#!/bin/bash

OUT="$(grep -n "GRUB_CMDLINE_LINUX_DEFAULT" /etc/default/grub | cut -d: -f1)"
sed -i "$OUT s/^/#/" /etc/default/grub

sed -i "$OUT a GRUB_CMDLINE_LINUX_DEFAULT=\"intel_iommu=on iommu=pt intremap=on isolcpus=1-10 intel_idle.max_cstate=0 processor.max_cstate=0 idle=mwait intel_pstate=disable\"" /etc/default/grub
