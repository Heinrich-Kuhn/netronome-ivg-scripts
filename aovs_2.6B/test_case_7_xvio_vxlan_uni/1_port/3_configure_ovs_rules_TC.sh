#!/bin/bash
#configure_ovs_rules.sh

BRIDGE=br0

BONDBR_DEST_IP=$1
BONDBR_SRC_IP=$2

VF_NAME_1="virtfn25"
VF_NAME_2="virtfn26"

VF1="pf0vf25"
VF2="pf0vf26"

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

# Delete all bridges
for br in $(ovs-vsctl list-br);
do
  ovs-vsctl --if-exists del-br $br
done

repr_vf1=$(find_repr $VF1 | rev | cut -d '/' -f 1 | rev)
echo "vf1 = $repr_vf1"
ip link set $repr_vf1 up

repr_vf2=$(find_repr $VF2 | rev | cut -d '/' -f 1 | rev)
echo "vf2 = $repr_vf2"
ip link set $repr_vf2 up

repr_vf3=$(find_repr $VF3 | rev | cut -d '/' -f 1 | rev)
echo "vf3 = $repr_vf3"
ip link set $repr_vf3 up

repr_vf4=$(find_repr $VF4 | rev | cut -d '/' -f 1 | rev)
echo "vf4 = $repr_vf4"
ip link set $repr_vf4 up

repr_pf0=$(find_repr pf0 | rev | cut -d "/" -f 1 | rev)
echo "pf0 = $repr_pf0"
ip link set $repr_pf0 up

repr_p0=$(find_repr p0 | rev | cut -d "/" -f 1 | rev)
echo "p0 = $repr_p0"
ip link set $repr_p0 up

ip link set $repr_p0 down
ip addr add $BONDBR_SRC_IP/24 dev $repr_p0
ip link set $repr_p0 up


# Create a new bridge
ovs-vsctl add-br $BRIDGE

ovs-vsctl add-port $BRIDGE vxlan_01 -- set interface vxlan_01 type=vxlan options:remote_ip=$BONDBR_DEST_IP  options:local_ip=$BONDBR_SRC_IP ofport_request=1
#ovs-vsctl add-port br0 vxlan01 -- set interface vxlan01 type=vxlan options:remote_ip=$BONDBR_DEST_IP  options:local_ip=$BONDBR_SRC_IP
#Add VF's
ovs-vsctl add-port $BRIDGE $repr_vf1 -- set interface $repr_vf1 ofport_request=25 external_ids:virtio_forwarder=25
ovs-vsctl add-port $BRIDGE $repr_vf2 -- set interface $repr_vf2 ofport_request=26 external_ids:virtio_forwarder=26
ovs-vsctl add-port $BRIDGE $repr_vf3 -- set interface $repr_vf3 ofport_request=27 external_ids:virtio_forwarder=27
ovs-vsctl add-port $BRIDGE $repr_vf4 -- set interface $repr_vf4 ofport_request=28 external_ids:virtio_forwarder=28

ovs-ofctl del-flows $BRIDGE

ovs-vsctl set Open_vSwitch . other_config:n-handler-threads=1
ovs-vsctl set Open_vSwitch . other_config:n-revalidator-threads=1

#ovs-ofctl -O OpenFlow13 add-flow $BRIDGE actions=NORMAL
ovs-ofctl add-flow $BRIDGE actions=NORMAL

# Implement flow via OF rules
# #-----------------------------------------------------------------
#script=$(find / -name of_rules.sh | grep IVG_folder)
#num_flows=$(cat /root/IVG_folder/aovs_2.6B/flow_setting.txt)
#sleep 1
#$script $num_flows 25 26 $BRIDGE
#sleep 1
#------------------------------------------------------------------

ovs-vsctl set Open_vSwitch . other_config:flow-limit=1000000
ovs-appctl upcall/set-flow-limit 1000000
ovs-vsctl --no-wait set Open_vSwitch . other_config:hw-offload=true
ovs-vsctl --no-wait set Open_vSwitch . other_config:tc-policy=none 
ovs-vsctl --no-wait set Open_vSwitch . other_config:max-idle=60000


ovs-vsctl show
ovs-ofctl show $BRIDGE
ovs-ofctl dump-flows $BRIDGE | wc -l
