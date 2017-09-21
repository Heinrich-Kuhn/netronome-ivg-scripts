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

check_list=( "intel_iommu=on" "iommu=pt" "intremap=on" "isolcpus=$nfp_cpulist" "intel_idle.max_cstate=0" "processor.max_cstate=0" "idle=mwait" "intel_pstate=disable" "nohz_full=$nfp_cpulist" "rcu_nocbs=$nfp_cpulist" "transparent_hugepage=never")
#pcie_asmp=off tsc=reliable 
export modification=0
for entry in ${check_list[@]};
do
  echo "$grub_setting" | grep -q $entry || { printCol 1 "$entry  - investigate host boot settings"; modification=1; }
  grub_setting=$(echo $grub_setting | sed "s/\"$/ ${entry}\"/")
done

echo "modification: $modification"
if [ $modification -eq 1 ]; then
  grub_setting="GRUB_CMDLINE_LINUX_DEFAULT=\"${check_list[0]}"
  for entry in ${check_list[@]:1};
  do
    grub_setting="$grub_setting $entry" 
  done
  grub_setting="$grub_setting\""
  echo "new GRUB: $grub_setting"

  while true; do
      read -p "Do you wish to install this \"GRUB_CMDLINE_LINUX_DEFAULT\"? [y/n]" yn
      case $yn in
          [Yy]* ) sed -i "/GRUB_CMDLINE_LINUX_DEFAULT/d" /etc/default/grub; sed "/^GRUB_CMDLINE_LINUX/a${grub_setting}" -i /etc/default/grub ; break;;
          [Nn]* ) exit;;
          * ) echo "Please answer yes or no.";;
      esac
  done
  printCol 5 "Remember to run platfrom-specific grub update"
  printCol 7 "Debian: update-grub update-grub2"
  printCol 7 "Fedora: grub2-mkconfig -o /boot/grub2/grub.cfg"
fi

