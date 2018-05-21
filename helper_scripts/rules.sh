#!/bin/bash

VM_COUNT=3
DUT_NUM=$1
BRIDGE_NAME=br0

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

ovs-vsctl --no-wait set Open_vSwitch . other_config:hw-offload=true
ovs-vsctl --no-wait set Open_vSwitch . other_config:tc-policy=none
ovs-vsctl --no-wait set Open_vSwitch . other_config:max-idle=60000
ovs-vsctl set Open_vSwitch . other_config:flow-limit=1000000
ovs-appctl upcall/set-flow-limit 1000000

repr_pf0=$(find_repr pf0 | rev | cut -d "/" -f 1 | rev)
echo "pf0 = $repr_pf0"
ip link set $repr_pf0 up

repr_p0=$(find_repr p0 | rev | cut -d "/" -f 1 | rev)
echo "p0 = $repr_p0"
ip link set $repr_p0 up

ovs-vsctl del-br $BRIDGE_NAME
ovs-vsctl add-br $BRIDGE_NAME

ovs-vsctl add-port $BRIDGE_NAME $repr_p0 -- set interface $repr_p0 ofport_request=1
ovs-ofctl del-flows $BRIDGE_NAME
#ovs-ofctl -O Openflow13 add-flow $BRIDGE_NAME dl_type=0x0806,actions=NORMAL

for (( c=1; c<=$VM_COUNT; c++ ))
do
  let "VF_NUM_1 = $c * 2"
  let "VF_NUM_2 = ( $c * 2 ) + 1"

  VF_1="pf0vf$VF_NUM_1"
  VF_2="pf0vf$VF_NUM_2"

  temp_repr_vf1=$(find_repr $VF_1 | rev | cut -d '/' -f 1 | rev)
  echo "VM $VM_COUNT    VF 1    $temp_repr_vf1"
  temp_repr_vf2=$(find_repr $VF_2 | rev | cut -d '/' -f 1 | rev)
  echo "VM $VM_COUNT    VF 2    $temp_repr_vf2"

  ovs-vsctl add-port $BRIDGE_NAME $temp_repr_vf1 -- set interface $temp_repr_vf1 ofport_request=$VF_NUM_1
  ovs-vsctl add-port $BRIDGE_NAME $temp_repr_vf2 -- set interface $temp_repr_vf2 ofport_request=$VF_NUM_2

  echo ""
  echo "IP RULES"
  if [[ $DUT_NUM == 0 ]]; then
   
    ovs-ofctl add-flow $BRIDGE_NAME in_port=1,dl_type=0x0800,nw_dst=10.10.$c.1,actions=$VF_NUM_1
    ovs-ofctl add-flow $BRIDGE_NAME in_port=1,dl_type=0x0806,nw_dst=10.10.$c.1,actions=$VF_NUM_1
    
    ovs-ofctl add-flow $BRIDGE_NAME in_port=1,dl_type=0x0800,nw_dst=10.10.$c.2,actions=$VF_NUM_2
    ovs-ofctl add-flow $BRIDGE_NAME in_port=1,dl_type=0x0806,nw_dst=10.10.$c.2,actions=$VF_NUM_2
  

  elif [[ $DUT_NUM == 1 ]]; then
    
    ovs-ofctl add-flow $BRIDGE_NAME in_port=1,dl_type=0x0800,nw_dst=10.10.$c.1,actions=$VF_NUM_1
    ovs-ofctl add-flow $BRIDGE_NAME in_port=1,dl_type=0x0806,nw_dst=10.10.$c.1,actions=$VF_NUM_1
    
    ovs-ofctl add-flow $BRIDGE_NAME in_port=1,dl_type=0x0800,nw_dst=10.10.$c.2,actions=$VF_NUM_2
    ovs-ofctl add-flow $BRIDGE_NAME in_port=1,dl_type=0x0806,nw_dst=10.10.$c.2,actions=$VF_NUM_2
  fi

  ovs-ofctl add-flow $BRIDGE_NAME in_port=$VF_NUM_1,actions=1
  ovs-ofctl add-flow $BRIDGE_NAME in_port=$VF_NUM_2,actions=1

  ip link set $temp_repr_vf1 up
  ip link set $temp_repr_vf2 up

done

ovs-vsctl show
ovs-ofctl show $BRIDGE_NAME
ovs-ofctl dump-flows $BRIDGE_NAME
