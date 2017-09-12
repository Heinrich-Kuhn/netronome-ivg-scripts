#!/bin/bash

VM_NAME=$1

echo "Adding 60 second sleep while VM boots up"
counter=0
virsh start $VM_NAME

while [ $counter -lt 12 ];
do
  sleep 5
  counter=$((counter+1))
  echo "counter: $counter"
 ip=$(virsh net-dhcp-leases default | awk -v var="$VM_NAME" '$6 == var {print $5}' | cut -d"/" -f1) 
  echo "ip: $ip"
  if [ ! -z "$ip" ]; then
      nc -w 2 -v $ip 22 </dev/null
      if [ $? -eq 0 ]; then
      counter=$((counter+12))
      echo "end"
    fi
  fi
done

ssh -o StrictHostKeyChecking=no root@$ip

