#!/bin/bash

VM_NAME=netronome-l2fwd

./1_bind_VFIO-PCI_driver.sh
./2_configure_AOVS.sh
./3_configure_OVS_rules.sh
./4_create_l2fwd_vm.sh
./5_configure_guest_xml.sh

#Start VM
virsh start $VM_NAME

#Wait for VM to boot up
echo "Adding 60 second sleep while VM boots up"
counter=0
while [ $counter -lt 12 ];
do
  sleep 5
  counter=$((counter+1))
  echo "counter: $counter"
  ip=$(arp -an | grep $(virsh dumpxml $VM_NAME | awk -F\' '/mac address/ {print $2}')| egrep -o '([0-9]{1,3}\.){3}[0-9]{1,3}')
  echo "ip: $ip"
  if [ ! -z "$ip" ]; then
      nc -w 2 -v $ip 22 </dev/null
      if [ $? -eq 0 ]; then
      counter=$((counter+12))
      echo "end"
    fi
  fi
done
sleep 2


#Get VM IP
ip=$(arp -an | grep $(virsh dumpxml $VM_NAME | awk -F\' '/mac address/ {print $2}')| egrep -o '([0-9]{1,3}\.){3}[0-9]{1,3}')

#Remove VM IP from known Hosts if present
ssh-keygen -R $ip

ssh root@"$(arp -an | grep $(virsh dumpxml $VM_NAME  | awk -F\' '/mac address/ {print $2}')| egrep -o '([0-9]{1,3}\.){3}[0-9]{1,3}')" "/root/vm_scripts/samples_DPDK-l2fwd/3_run_l2fwd.sh"




