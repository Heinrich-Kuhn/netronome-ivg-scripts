#!/bin/bash

###############
# OVS_TC ONLY #
###############


script_dir="$(dirname $(readlink -f $0))"
base_dir=$HOME/IVG

BRIDGE_NAME=br0

VM_CPUS=$1          # amount of cpus per vm
VM_COUNT=$2         # amount of vms on each host
VM_BASE_NAME=$3     # base name for vms
VM_OS=$4            # centos or ubuntu

#-------------------------------------------------------------

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
  ovs-appctl upcall/set-flow-limit 1000000

}

#--------------------------------------------------------------

$base_dir/helper_scripts/configure_hugepages.sh

sleep 1

$base_dir/helper_scripts/stop_ovs_tc.sh

sleep 1

$base_dir/helper_scripts/vm_shutdown_all.sh

sleep 1

$base_dir/helper_scripts/start_ovs_tc.sh

sleep 1

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


for (( c=1; c<=$VM_COUNT; c++ ))
do

    VM_NAME="$VM_BASE_NAME$c"
    echo $VM_NAME
    echo $i

    virsh undefine $VM_NAME || true

    let "VF_NUM_1 = $c * 2"
    let "VF_NUM_2 = ( $c * 2 ) + 1"

    VF_1="pf0vf$VF_NUM_1"
    VF_2="pf0vf$VF_NUM_2"

    VF_NAME_1="virtfn$VF_NUM_1"
    VF_NAME_2="virtfn$VF_NUM_2"

    echo -e "VF $VF_NUM_1 \t $VF_1 \t $VF_NAME_1"
    echo -e "VF $VF_NUM_2 \t $VF_2 \t $VF_NAME_2"

    # Create VM instance c
    $base_dir/aovs_2.6B/vm_creator/$VM_OS/y_create_vm_from_backing.sh  $VM_NAME



    # Bind VFs to be used by VMs
    temp_repr_vf1=$(find_repr $VF_1 | rev | cut -d '/' -f 1 | rev)
    temp_repr_vf2=$(find_repr $VF_2 | rev | cut -d '/' -f 1 | rev)

    echo "Add $temp_repr_vf1 & temp_repr_vf2 to $BRIDGE_NAME"
    ovs-vsctl add-port $BRIDGE_NAME $temp_repr_vf1 -- set interface $temp_repr_vf1 ofport_request=$VF_NUM_1
    ovs-vsctl add-port $BRIDGE_NAME $temp_repr_vf2 -- set interface $temp_repr_vf2 ofport_request=$VF_NUM_2

    ip link set $temp_repr_vf1 up
    ip link set $temp_repr_vf2 up

    VF1_PCI_ADDRESS=$(readlink -f /sys/bus/pci/devices/${PCI}/${VF_NAME_1} | rev | cut -d '/' -f1 | rev)
    VF2_PCI_ADDRESS=$(readlink -f /sys/bus/pci/devices/${PCI}/${VF_NAME_2} | rev | cut -d '/' -f1 | rev)

    echo "VF1_PCI_ADDRESS: $VF1_PCI_ADDRESS"
    echo "VF2_PCI_ADDRESS: $VF2_PCI_ADDRESS"

    bind_vfio ${VF1_PCI_ADDRESS}
    bind_vfio ${VF2_PCI_ADDRESS}

    sleep 5

    # XML EDIT

    max_memory=$(virsh dominfo $VM_NAME | grep 'Max memory:' | awk '{print $3}')
    # Remove vhostuser interface
    EDITOR='sed -i "/<interface type=.vhostuser.>/,/<\/interface>/d"' virsh edit $VM_NAME
    EDITOR='sed -i "/<hostdev mode=.subsystem. type=.pci./,/<\/hostdev>/d"' virsh edit $VM_NAME
    #
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
    EDITOR='sed -i "/<domain/a \<cpu mode=\"host-model\"><model fallback=\"allow\"\/><numa><cell id=\"0\" cpus=\"0-'$((VM_CPUS-1))'\" memory=\"'${max_memory}'\" unit=\"KiB\" memAccess=\"shared\"\/><\/numa><\/cpu>"' virsh edit $VM_NAME

    sleep 3

    virsh start $VM_NAME || exit -1

    /root/IVG/helper_scripts/await-vm-ipaddr_gui.sh $VM_NAME || exit -1

    ipaddr=$(/root/IVG/helper_scripts/get-vm-ipaddr.sh $VM_NAME)

    ssh -o StrictHostKeyChecking=no $ipaddr rm /etc/machine-id
    ssh -o StrictHostKeyChecking=no $ipaddr systemd-machine-id-setup

    ssh -o StrictHostKeyChecking=no $ipaddr poweroff

    while [[ -z $(virsh list --all | grep "$VM_NAME" | grep "shut off") ]]; do
        sleep 1
    done

    sleep 10

    virsh start $VM_NAME || exit -1

    /root/IVG/helper_scripts/await-vm-ipaddr_gui.sh $VM_NAME || exit -1

    ipaddr=$(/root/IVG/helper_scripts/get-vm-ipaddr.sh $VM_NAME)

    sleep 1

    sleep 1

    ssh -o StrictHostKeyChecking=no $ipaddr /root/vm_scripts/samples/DPDK-pktgen/1_configure_hugepages.sh
    ssh -o StrictHostKeyChecking=no $ipaddr /root/vm_scripts/samples/DPDK-pktgen/2_auto_bind_igb_uio.sh


    echo "VM $c setup done"


done

# Set PF up

repr_pf0=$(find_repr pf0 | rev | cut -d "/" -f 1 | rev)
echo "pf0 = $repr_pf0"
ip link set $repr_pf0 up

repr_p0=$(find_repr p0 | rev | cut -d "/" -f 1 | rev)
echo "p0 = $repr_p0"
ip link set $repr_p0 up

ovs-vsctl add-port $BRIDGE_NAME $repr_p0 -- set interface $repr_p0 ofport_request=1

ovs-ofctl del-flows $BRIDGE_NAME
ovs-ofctl -O OpenFlow13 add-flow $BRIDGE_NAME actions=NORMAL

ovs-vsctl show
ovs-ofctl show $BRIDGE_NAME
ovs-ofctl dump-flows $BRIDGE_NAME


echo "Custom Setup Done"




