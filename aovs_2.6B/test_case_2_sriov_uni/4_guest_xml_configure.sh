#!/bin/bash

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "ERROR: No VM name was passed to this script."
    echo "Example: ./4_guest_xml_configure.sh <vm_name> <vm_cpu_count>"
    exit -1
fi

VM_NAME=$1
VM_CPU_COUNT=$2

max_memory=$(virsh dominfo $VM_NAME | grep 'Max memory:' | awk '{print $3}')
s_bus=$(ethtool -i nfp_v0.42 | grep bus-info | awk '{print $5}' | awk -F ':' '{print $2}')

# Remove vhostuser interface
EDITOR='sed -i "/<interface type=.vhostuser.>/,/<\/interface>/d"' virsh edit $VM_NAME
EDITOR='sed -i "/<hostdev mode=.subsystem. type=.pci./,/<\/hostdev>/d"' virsh edit $VM_NAME

# Add vhostuser interfaces
# nfp_v0.41 --> 0000:81:0d.1
# nfp_v0.42 --> 0000:81:0d.2

cat > /tmp/interface << EOL
      <interface type='hostdev' managed='yes'>
          <source>
              <address type='pci' domain='0x0000' bus='0x${s_bus}' slot='0x0d' function='0x01'/>
          </source>
          <address type='pci' domain='0x0000' bus='0x00' slot='0x0a' function='0x00'/>
      </interface>
EOL
  virsh attach-device $VM_NAME /tmp/interface --config

sleep 1
echo "Device attached"

cat > /tmp/interface << EOL
      <interface type='hostdev' managed='yes'>
          <source>
              <address type='pci' domain='0x0000' bus='0x${s_bus}' slot='0x0d' function='0x02'/>
          </source>
          <address type='pci' domain='0x0000' bus='0x00' slot='0x0b' function='0x00'/>
      </interface>
EOL
  virsh attach-device $VM_NAME /tmp/interface --config


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


echo "Device attached"

EDITOR='sed -i "/<cpu/,/<\/cpu>/d"' virsh edit $VM_NAME
EDITOR='sed -i "/<memoryBacking>/,/<\/memoryBacking>/d"' virsh edit $VM_NAME

# MemoryBacking
EDITOR='sed -i "/<domain/a \<memoryBacking><hugepages><page size=\"2048\" unit=\"KiB\" nodeset=\"0\"\/><\/hugepages><\/memoryBacking>"' virsh edit $VM_NAME
EDITOR='sed -i "/<domain/a \<cpu mode=\"host-model\"><model fallback=\"allow\"\/><numa><cell id=\"0\" cpus=\"0-'$((VM_CPU_COUNT-1))'\" memory=\"'${max_memory}'\" unit=\"KiB\" memAccess=\"shared\"\/><\/numa><\/cpu>"' virsh edit $VM_NAME

exit 0
