#!/bin/bash

function printCol {
  # Usage: printCol <COLOR> <MESSAGE>
  # 0 Black. 1 Red.     2 Green. 3 Yellow.
  # 4 Blue.  5 Magenta. 6 Cyan.  7 White.
  echo "$(tput bold)$(tput setaf $1)$2$(tput sgr0)"
}

echo "START"

cat /proc/mounts | grep hugetlbfs

umount /mnt/aovs-huge-2M ## should we stick to default mount or create new?

printCol 7 "Setting 2M"
grep hugetlbfs /proc/mounts | grep -q "pagesize=2M" || \
( mkdir -p /mnt/huge && mount nodev -t hugetlbfs -o rw,pagesize=2M /mnt/huge/ )

printCol 7 "Setting 1G"
grep hugetlbfs /proc/mounts | grep -q "pagesize=1G" || \
( mkdir -p /mnt/huge-1G && mount nodev -t hugetlbfs -o rw,pagesize=1G /mnt/huge-1G/ )

printCol 7 "/proc/mounts | grep hugetlbfs"
cat /proc/mounts | grep hugetlbfs

printCol 7 "libvirt folders"
mkdir -p /mnt/huge-1G/libvirt
mkdir -p /mnt/huge/libvirt
chown libvirt-qemu:kvm -R /mnt/huge-1G/libvirt
chown libvirt-qemu:kvm -R /mnt/huge/libvirt

service libvirt-bin restart

echo 9096 > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages

echo "END"
