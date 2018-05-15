#!/bin/bash

function printCol {
  # Usage: printCol <COLOR> <MESSAGE>
  # 0 – Black. 1 – Red.     2 – Green. 3 – Yellow.
  # 4 – Blue.  5 – Magenta. 6 – Cyan.  7 – White.
  echo "$(tput bold)$(tput setaf $1)$2$(tput sgr0)"
}
nfp_cpulist=$(cat /sys/bus/pci/devices/$(lspci -d 19ee: | head -1 | awk '{print "0000:"$1}')/local_cpulist)
echo "nfp_cpulist: $nfp_cpulist"


grub_setting=$(grep "^GRUB_CMDLINE_LINUX_DEFAULT" /etc/default/grub)
echo "START: $grub_setting"

sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT=.*/c\GRUB_CMDLINE_LINUX_DEFAULT="intel_iommu=on iommu=pt intremap=on intel_idle.max_cstate=0 processor.max_cstate=0 intel_pstate=disable nohz_full=$nfp_cpulist rcu_nocbs=$nfp_cpulist transparent_hugepage=never"' /etc/default/grub
sed -i '/^GRUB_CMDLINE_LINUX=.*/c\GRUB_CMDLINE_LINUX="intel_iommu=on iommu=pt intremap=on intel_idle.max_cstate=0 processor.max_cstate=0 intel_pstate=disable nohz_full=$nfp_cpulist rcu_nocbs=$nfp_cpulist transparent_hugepage=never"' /etc/default/grub


grub_setting=$(grep "^GRUB_CMDLINE_LINUX_DEFAULT" /etc/default/grub)
echo "NEW: $grub_setting"
  
# Ubuntu
grep ID_LIKE /etc/os-release | grep -q debian
if [[ $? -eq 0 ]]; then
  update-grub
fi

grep  ID_LIKE /etc/os-release | grep -q fedora
if [[ $? -eq 0 ]]; then
  grub2-mkconfig -o /boot/grub2/grub.cfg
fi



echo "Grub updated"
exit 0



