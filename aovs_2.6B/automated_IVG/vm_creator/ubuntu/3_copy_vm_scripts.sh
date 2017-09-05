#!/bin/bash

#Start VM
VM_NAME=ubuntu_backing
script_dir="$(dirname $(readlink -f $0))"
virsh start $VM_NAME
echo -e "${GREEN}VM is starting...${NC}"

echo "Adding 60 second sleep while VM boots up"
counter=0
while [ $counter -lt 12 ];
do
  sleep 5
  counter=$((counter+1))
  echo "counter: $counter"
  ip=$(arp -an | grep $(virsh dumpxml $VM_NAME | awk -F\' '/mac address/ {print $2}')| egrep -o '([0-9]{1,3}\.){3}[0-9]{1,3}')
  if [ ! -z "$ip" ]; then
      nc -w 2 -v $ip 22 </dev/null
      if [ $? -eq 0 ]; then
      counter=$((counter+12))
      echo "end"
    fi
  fi
done
sleep 2

echo "Copying setup scripts to VM..."

#Get VM IP
ip=$(arp -an | grep $(virsh dumpxml $VM_NAME | awk -F\' '/mac address/ {print $2}')| egrep -o '([0-9]{1,3}\.){3}[0-9]{1,3}')

#Remove VM IP from known Hosts if present
ssh-keygen -R $ip

#Copy Setup scripts to VM
scp -o StrictHostKeyChecking=no -r $script_dir/vm_scripts root@$ip:/root/

