#!/bin/bash
D_BUS="01"
D_SLOT_1="a"
D_SLOT_2="b"
D_FUNCTION="0"
VM_NAME=$1
BRIDGE="br0"

#function print_usage {
#    echo "Script to add vhostnet interfaces to vm"
#    echo "Usage: "
#    echo "-b <bus>       --bus <bus>                Bus value of new interface"
#    echo "-s <slot>      --slot <slot>              Slot value of new interface"
#    echo "-f <function>  --function <function>      Function value of new interface"
#    echo "-vn <name>     --vmname <name>            Name of vm to add interface too"
#    echo "-sb <bridge>   --sourcebridge <bridge>    Source bridge of interface"
#    echo "-h             --help                     Prints this message and exits"
#}

#while [[ $# -gt 0 ]]
#do
#    argument="$1"
#    case $argument in
        # Help
#        -h|--help) print_usage; exit 1;;
#        -b|--bus) D_BUS="$2"; shift 2;;
#        -s|--slot) D_SLOT="$2"; shift 2;;
#        -f|--function) D_FUNCTION="$2"; shift 2;;
#        -vn|--vmname) VM_NAME="$2"; shift 2;;
#        -sb|--sourcebridge) BRIDGE="$2"; shift 2;;
#        *) echo "Unkown argument: \"$argument\""; print_usage; exit 1;;
#    esac
#done

#if [ -z "$D_BUS" ] ; then D_BUS=$DEFAULT_D_BUS ; fi
#if [ -z "$D_SLOT" ] ; then D_SLOT=$DEFAULT_D_SLOT ; fi
#if [ -z "$D_FUNCTION" ] ; then D_FUNCTION=$DEFAULT_D_FUNCTION ; fi
#if [ -z "$VM_NAME" ] ; then VM_NAME=$DEFAULT_VM_NAME ; fi
#if [ -z "$BRIDGE" ] ; then BRIDGE=$DEFAULT_BRIDGE ; fi

cat > /tmp/interface << EOL
<interface type='vhostuser'>
      <source type='unix' path='/usr/local/var/run/openvswitch/dpdkvhostuser0' mode='client'/>
      <model type='virtio'/>
      <address type='pci' domain='0x0000' bus='0x${D_BUS}' slot='0x${D_SLOT_1}' function='0x${D_FUNCTION}'/>
      <driver queues='2'>
        <host mrg_rxbuf='off'/>
      </driver>
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

# DEFAULT_SOURCE_INTERFACE="br0"

# function print_usage {
#     echo "Script to add bridge interfaces to vm"
#     echo "Usage: "
#     echo "-s <source> --source <source>        Source interface to add"
#     echo "-h          --help                   Prints this message and exits"
# }


# while [[ $# -gt 0 ]]
# do
#     argument="$1"
#     case $argument in
#         # Help
#         -h|--help) print_usage; exit 1;;
#         -s|--source) SOURCE_INTERFACE="$2"; shift 2;;
#         -*) echo "Unkown argument: \"$argument\""; print_usage; exit 1;;
#     esac
# done

# if [ -z "$SOURCE_INTERFACE" ] ; then SOURCE_INTERFACE=$DEFAULT_SOURCE_INTERFACE ; fi

# vm_interface="<interface type='bridge'><source bridge='"$SOURCE_INTERFACE"'\/><virtualport type='openvswitch'\/><model type='virtio'\/><\/interface>"
# epoch_time=$(date +%s)
# GUEST=perf-vm-02

# mkdir -p /root/vm_backup
# cd /root/vm_backup
# virsh dumpxml $GUEST > $GUEST.xml
# cp $GUEST.xml $GUEST"_backup_"$epoch_time".xml"
# echo sed -i \""s/<\/devices>/"$vm_interface"<\/devices>/"\" $GUEST.xml | sh
# virsh define $GUEST.xml
# rm -rf $GUEST.xml
