#!/bin/bash
#5_configure_guest_xml.sh

if [ -z "$1" ]; then
   echo "ERROR: No VM name was passed to this script."
   echo "Example: ./4_guest_xml_configure.sh <vm_name>"
   exit -1
   else
   VM_NAME=$1
fi

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


PCI=$(lspci -d 19ee: | grep 4000 | cut -d ' ' -f1)

if [[ "$PCI" == *":"*":"*"."* ]]; then
    echo "PCI correct format"
elif [[ "$PCI" == *":"*"."* ]]; then
    echo "PCI corrected"
    PCI="0000:$PCI"
fi

VM_CPU=4
max_memory=$(virsh dominfo $VM_NAME | grep 'Max memory:' | awk '{print $3}')

# Remove vhostuser interface
EDITOR='sed -i "/<interface type=.vhostuser.>/,/<\/interface>/d"' virsh edit $VM_NAME
EDITOR='sed -i "/<hostdev mode=.subsystem. type=.pci./,/<\/hostdev>/d"' virsh edit $VM_NAME

#----------------------------------------------------------------------------------------------
repr_vf1=$(find_repr $VF1 | rev | cut -d '/' -f 1 | rev)
echo "vf1 = $repr_vf1"

bus=$(readlink -f /sys/bus/pci/devices/${PCI}/${VF_NAME_1} | rev | cut -d '/' -f1 | rev | awk -F ':' '{print $2}')
#-----------------------------------------------------------------------------------------------

# Add vhostuser interfaces
EDITOR='sed -i "/<devices/a \<interface type=\"vhostuser\">  <source type=\"unix\" path=\"/tmp/virtio-forwarder/virtio-forwarder25.sock\" mode=\"client\"\/>  <model type=\"virtio\"/>  <driver name=\"vhost\" queues=\"1\"\/>  <address type=\"pci\" domain=\"0x0000\" bus=\"0x01\" slot=\"0x0a\" function=\"0x0\"\/><\/interface>"' virsh edit $VM_NAME
EDITOR='sed -i "/<devices/a \<interface type=\"vhostuser\">  <source type=\"unix\" path=\"/tmp/virtio-forwarder/virtio-forwarder26.sock\" mode=\"client\"\/>  <model type=\"virtio\"/>  <driver name=\"vhost\" queues=\"1\"\/>  <address type=\"pci\" domain=\"0x0000\" bus=\"0x01\" slot=\"0x0b\" function=\"0x0\"\/><\/interface>"' virsh edit $VM_NAME

# Configuring default settings for VM
VM_CPU=$(virsh dominfo $VM_NAME | grep 'CPU(s):' | cut -d ':' -f2 | cut -d ' ' -f10)
max_memory=$(virsh dominfo $VM_NAME | grep 'Max memory:' | awk '{print $3}')
EDITOR='sed -i "/<numa>/,/<\/numa>/d"' virsh edit $VM_NAME
EDITOR='sed -i "/vcpu/d"' virsh edit $VM_NAME
EDITOR='sed -i "/<cpu/,/<\/cpu>/d"' virsh edit $VM_NAME
EDITOR='sed -i "/<memoryBacking>/,/<\/memoryBacking>/d"' virsh edit $VM_NAME
virsh setvcpus $VM_NAME $VM_CPU --config --maximum
virsh setvcpus $VM_NAME $VM_CPU --config
# MemoryBacking
EDITOR='sed -i "/<domain/a \<memoryBacking><hugepages><page size=\"2048\" unit=\"KiB\" nodeset=\"0\"\/><\/hugepages><\/memoryBacking>"' virsh edit $VM_NAME
# CPU
echo VM_CPU: $VM_CPU
EDITOR='sed -i "/<domain/a \<cpu mode=\"host-model\"><model fallback=\"allow\"\/><numa><cell id=\"0\" cpus=\"0-'$((VM_CPU-1))'\" memory=\"'${max_memory}'\" unit=\"KiB\" memAccess=\"shared\"\/><\/numa><\/cpu>"' virsh edit $VM_NAME
