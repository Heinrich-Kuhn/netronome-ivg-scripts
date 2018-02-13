#!/bin/bash

VM_NAME=$1

function find_repr()
{
  local REPR=$1
  for i in /sys/class/net/*;
  do
    phys_port_name=$(cat $i/phys_port_name 2>&1 /dev/null)
    #echo "test: ${phys_port_name}"
    #echo "REPR: $REPR"
    if [ "$phys_port_name" == "$REPR" ];
    then
      echo "$i"
    fi
  done
}

sed "s#^VIRTIOFWD_STATIC_VFS=.*#VIRTIOFWD_STATIC_VFS=#g" -i /etc/default/virtioforwarder

VF1="pf0vf21"
VF2="pf0vf22"

repr_vf1=$(find_repr $VF1 | rev | cut -d '/' -f 1 | rev)
echo "vf1 = $repr_vf1"
ip link set $repr_vf1 down

repr_vf2=$(find_repr $VF2 | rev | cut -d '/' -f 1 | rev)
echo "vf2 = $repr_vf2"
ip link set $repr_vf2 down


