#!/bin/bash

script_dir="$(dirname $(readlink -f $0))"

if [ -z "$1" ]; then
    echo "ERROR: Please specify the VM name"
    exit -1
fi

VM_NAME=$1

BASE_IMAGE_NAME="CentOS-base"
BASE_IMAGE_FILE="/var/lib/libvirt/images/$BASE_IMAGE_NAME.qcow2"

if [ ! -f $BASE_IMAGE_FILE ]; then
    echo "ERROR: missing the CentOS backing file $BASE_IMAGE_FILE"
    exit -1
fi

# Shutdown all VMs
$IVG_dir/helper_scripts/delete-vms.sh --all --shutdown
# Undefine Netronome VMs
$IVG_dir/helper_scripts/delete-vms.sh --filter "netronome"

LIBVIRT_DIR=/var/lib/libvirt/images

# Check if VM name is passed
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
qemu-img create -b $BASE_IMAGE_FILE -f qcow2 $overlay \
    || exit -1

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
    --os-variant=rhel7 \
    --noautoconsole \
    --noreboot \
    --import \
    || exit -1

echo "VM has been created!"
exit 0
