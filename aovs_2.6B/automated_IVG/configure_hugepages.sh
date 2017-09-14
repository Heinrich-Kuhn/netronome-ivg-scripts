#!/bin/bash

function printCol {
  # Usage: printCol <COLOR> <MESSAGE>
  # 0 – Black. 1 – Red.     2 – Green. 3 – Yellow.
  # 4 – Blue.  5 – Magenta. 6 – Cyan.  7 – White.
  echo "$(tput bold)$(tput setaf $1)$2$(tput sgr0)"
}

# Collect list of existing mount-points
mntlist=( $( cat /proc/mounts \
  | cut -d ' ' -f 2 ) )

# If '/mnt/aovs-huge-2M' is mounted, umount it
if [[ "${mntlist[@]}" =~ "/mnt/aovs-huge-2M" ]]; then
    umount /mnt/aovs-huge-2M
fi

if ! [[ "${mntlist[@]}" =~ "/mnt/huge" ]]; then
    printCol 7 "Setting up 2M mount point (/mnt/huge)"
    mkdir -p /mnt/huge || exit -1
    mount nodev -t hugetlbfs -o "rw,pagesize=2M" /mnt/huge || exit -1
fi

if ! [[ "${mntlist[@]}" =~ "/mnt/huge-1G" ]]; then
    printCol 7 "Setting up 1G mount point (/mnt/huge-1G)"
    mkdir -p /mnt/huge-1G || exit -1
    mount nodev -t hugetlbfs -o "rw,pagesize=1G" /mnt/huge-1G || exit -1
fi

printCol 7 "libvirt folders"
mkdir -p /mnt/huge-1G/libvirt || exit -1
mkdir -p /mnt/huge/libvirt || exit -1
chown libvirt-qemu:kvm -R /mnt/huge-1G/libvirt || exit -1
chown libvirt-qemu:kvm -R /mnt/huge/libvirt || exit -1

service libvirt-bin restart || exit -1

echo 9096 > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages

echo "DONE($(basename $0))"
exit 0
