#!/bin/bash

script_dir="$(dirname $(readlink -f $0))"
IVG_dir="/root/IVG_folder"

# Shutdown all VMs
$IVG_dir/helper_scripts/delete-vms.sh --all --shutdown
# Undefine Netronome VMs
$IVG_dir/helper_scripts/delete-vms.sh --filter "netronome"

LIBVIRT_DIR=/var/lib/libvirt/images
basefile=$LIBVIRT_DIR/ubuntu-17.10-server-cloudimg-amd64.img

# Check if VM name is passed
if [ -z "$1" ]; then
   echo "ERROR: Please pass a VM name as the first parameter of this script..."
   exit -1
   else
   VM_NAME=$1
fi

cat <<- EOF > /tmp/ifcfg-eth0
DEVICE="eth0"
ONBOOT="yes"
IPV6INIT="no"
BOOTPROTO="dhcp"
TYPE="Ethernet"
EOF

# Check for and install 'libguestfs-tools'
$IVG_dir/helper_scripts/install-packages.sh \
    "guestfish@libguestfs-tools" \
    || exit -1

echo "create overlay image"
overlay="$LIBVIRT_DIR/$VM_NAME.qcow2"
qemu-img create -b $basefile -f qcow2 $overlay \
    || exit -1
sleep 5
guestfish --rw -i -a $overlay write /etc/hostname $VM_NAME \
    || exit -1

echo "create domain"

cpu_model=$(virsh capabilities \
    | grep -o '<model>.*</model>' \
    | head -1 \
    | sed 's/\(<model>\|<\/model>\)//g')

virt-install \
    --name "$VM_NAME" \
    --disk path=${overlay},format=qcow2,bus=virtio,cache=none \
    --ram 6144 \
    --vcpus 5 \
    --cpu $cpu_model \
    --network network=default \
    --nographics \
    --debug \
    --accelerate \
    --os-type=linux \
    --os-variant=ubuntu16.04 \
    --noautoconsole \
    --noreboot \
    --import \
    || exit -1

echo "VM has been created!"
exit 0
