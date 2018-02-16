#!/bin/bash

VM_NAME=$1
VM_CPU_COUNT=$2

BONDBR_DEST_IP=$3 
BONDBR_SRC_IP=$4

VF_NAME_1="virtfn10"
VF_NAME_2="virtfn11"

VF1="pf0vf10"
VF2="pf0vf11"

BRIDGE_NAME=br0

##############################################################################################################

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

function bind_vfio()
{
  DRIVER=vfio-pci
  lsmod | grep --silent vfio_pci || modprobe vfio_pci
  INTERFACE_PCI=$1
  current=$(lspci -ks ${INTERFACE_PCI} | awk '/in use:/ {print $5}')
  echo "INTERFACE_PCI: $INTERFACE_PCI"
  echo "current driver: $current"
  echo "expected driver: $DRIVER"
  if [ "$current" != "$DRIVER" ]; then
    #DPDK_DEVBIND=$(find /opt/netronome -iname dpdk-devbind.py | head -1)
    #echo "DPDK_DEVBIND: $DPDK_DEVBIND"
    #$DPDK_DEVBIND --bind $DRIVER $INTERFACE_PCI
    if [ "$current" != "" ]; then
      echo "testing: unbind $current on ${INTERFACE_PCI}"
      echo ${INTERFACE_PCI} > /sys/bus/pci/devices/${INTERFACE_PCI}/driver/unbind
      echo ${DRIVER} > /sys/bus/pci/devices/${INTERFACE_PCI}/driver_override
      echo ${INTERFACE_PCI} > /sys/bus/pci/drivers/vfio-pci/bind
    fi
  fi
}

function clean-ovs-bridges()
{
  ovs-vsctl list-br | while read BRIDGE;
  do
    echo "Deleting: $BRIDGE"
    ovs-vsctl del-br $BRIDGE
  done
}

function general-ovs-config()
{
  ovs-vsctl --no-wait set Open_vSwitch . other_config:hw-offload=true
  ovs-vsctl --no-wait set Open_vSwitch . other_config:tc-policy=none
  ovs-vsctl --no-wait set Open_vSwitch . other_config:max-idle=60000
  ovs-vsctl set Open_vSwitch . other_config:flow-limit=1000000
}

##############################################################################################################

/root/IVG_folder/helper_scripts/start_ovs_tc.sh

general-ovs-config
clean-ovs-bridges

PCI=$(lspci -d 19ee: | grep 4000 | cut -d ' ' -f1)

if [[ "$PCI" == *":"*":"*"."* ]]; then
    echo "PCI correct format"
elif [[ "$PCI" == *":"*"."* ]]; then
    echo "PCI corrected"
    PCI="0000:$PCI"
fi

ovs-vsctl add-br $BRIDGE_NAME
sleep 1

#------------------------------------------------------------------------------------------------------

repr_vf1=$(find_repr $VF1 | rev | cut -d '/' -f 1 | rev)
echo "Add $repr_vf1 to $BRIDGE_NAME"
echo "ovs-vsctl add-port $BRIDGE_NAME $repr_vf1 -- set interface $repr_vf1 ofport_request=10"
ovs-vsctl add-port $BRIDGE_NAME $repr_vf1 -- set interface $repr_vf1 ofport_request=10
ip link set $repr_vf1 up
VF1_PCI_ADDRESS=$(readlink -f /sys/bus/pci/devices/${PCI}/${VF_NAME_1} | rev | cut -d '/' -f1 | rev)
echo "VF1_PCI_ADDRESS: $VF1_PCI_ADDRESS"
bind_vfio ${VF1_PCI_ADDRESS}

echo "FIRST VF DONE"

#------------------------------------------------------------------------------------------------------

repr_vf2=$(find_repr $VF2 | rev | cut -d '/' -f 1 | rev)
echo "Add $repr_vf2 to $BRIDGE_NAME"
echo "ovs-vsctl add-port $BRIDGE_NAME $repr_vf2 -- set interface $repr_vf2 ofport_request=11"
ovs-vsctl add-port $BRIDGE_NAME $repr_vf2 -- set interface $repr_vf2 ofport_request=11
ip link set $repr_vf2 up
VF2_PCI_ADDRESS=$(readlink -f /sys/bus/pci/devices/${PCI}/${VF_NAME_2} | rev | cut -d '/' -f1 | rev)
echo "VF2_PCI_ADDRESS: $VF2_PCI_ADDRESS"
bind_vfio ${VF2_PCI_ADDRESS}

echo "SECOND VF DONE"

#------------------------------------------------------------------------------------------------------

repr_pf0=$(find_repr pf0 | rev | cut -d "/" -f 1 | rev)
echo "pf0 = $repr_pf0"
ip link set $repr_pf0 up

repr_p0=$(find_repr p0 | rev | cut -d "/" -f 1 | rev)
echo "p0 = $repr_p0"
ip link set $repr_p0 up



ip link set $repr_p0 down
ip addr add $BONDBR_SRC_IP/24 dev $repr_p0
ip link set $repr_p0 up


ovs-vsctl add-port br0 vxlan01 -- set interface vxlan01 type=vxlan options:key=flow options:remote_ip=$BONDBR_DEST_IP ofport_request=1
#  options:local_ip=$BONDBR_SRC_IP ofport_request=1

ovs-ofctl del-flows $BRIDGE_NAME


#ADD OPENFLOW RULES
##############################################################################
script=$(find / -name of_rules.sh | grep IVG_folder)
num_flows=$(cat /root/IVG_folder/aovs_2.6B/flow_setting.txt)
sleep 1
$script $num_flows 10 11 br0
sleep 1
#############################################################################

ovs-vsctl set Open_vSwitch . other_config:n-handler-threads=1
ovs-vsctl set Open_vSwitch . other_config:n-revalidator-threads=1

ovs-vsctl show
ovs-ofctl show $BRIDGE_NAME
ovs-ofctl dump-flows $BRIDGE_NAME | wc -l


#### ----- XML EDIT ------ ####

max_memory=$(virsh dominfo $VM_NAME | grep 'Max memory:' | awk '{print $3}')

# Remove vhostuser interface
EDITOR='sed -i "/<interface type=.vhostuser.>/,/<\/interface>/d"' virsh edit $VM_NAME
EDITOR='sed -i "/<hostdev mode=.subsystem. type=.pci./,/<\/hostdev>/d"' virsh edit $VM_NAME

#
# VF 39
# VF 40

bus=$(echo $VF2_PCI_ADDRESS | cut -d ':' -f2 )
slot_1=$(echo $VF1_PCI_ADDRESS | cut -d ':' -f3 | cut -d '.' -f1 )
slot_2=$(echo $VF2_PCI_ADDRESS | cut -d ':' -f3 | cut -d '.' -f1 )
func_1=$(echo $VF1_PCI_ADDRESS | cut -d '.' -f2 )
func_2=$(echo $VF2_PCI_ADDRESS | cut -d '.' -f2 )


EDITOR='sed -i "/<devices/a \<hostdev mode=\"subsystem\" type=\"pci\" managed=\"yes\">  <source> <address domain=\"0x0000\" bus=\"0x'${bus}'\" slot=\"0x'$slot_1'\" function=\"0x'$func_1'\"\/> <\/source>  <address type=\"pci\" domain=\"0x0000\" bus=\"0x00\" slot=\"0x0a\" function=\"0x0\"\/> <\/hostdev>"' virsh edit $VM_NAME

EDITOR='sed -i "/<devices/a \<hostdev mode=\"subsystem\" type=\"pci\" managed=\"yes\">  <source> <address domain=\"0x0000\" bus=\"0x'${bus}'\" slot=\"0x'$slot_2'\" function=\"0x'$func_2'\"\/> <\/source>  <address type=\"pci\" domain=\"0x0000\" bus=\"0x00\" slot=\"0x0b\" function=\"0x0\"\/> <\/hostdev>"' virsh edit $VM_NAME

EDITOR='sed -i "/<cpu/,/<\/cpu>/d"' virsh edit $VM_NAME
EDITOR='sed -i "/<memoryBacking>/,/<\/memoryBacking>/d"' virsh edit $VM_NAME

# MemoryBacking
EDITOR='sed -i "/<domain/a \<memoryBacking><hugepages><page size=\"2048\" unit=\"KiB\" nodeset=\"0\"\/><\/hugepages><\/memoryBacking>"' virsh edit $VM_NAME
EDITOR='sed -i "/<domain/a \<cpu mode=\"host-model\"><model fallback=\"allow\"\/><numa><cell id=\"0\" cpus=\"0-'$((VM_CPU_COUNT-1))'\" memory=\"'${max_memory}'\" unit=\"KiB\" memAccess=\"shared\"\/><\/numa><\/cpu>"' virsh edit $VM_NAME


