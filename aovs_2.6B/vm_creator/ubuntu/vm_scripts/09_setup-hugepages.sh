#!/bin/bash

#umount /dev/hugepages
#mkdir -p /mnt/hugepages
#echo 2048 > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
#grep -q hugetlbfs /proc/mounts || mount -t hugetlbfs nodev /mnt/hugepages

grep vm.nr_hugepages /etc/sysctl.conf || echo vm.nr_hugepages=2048 >> /etc/sysctl.conf
grep /mnt/huge /etc/fstab || ( mkdir -p /mnt/huge ; chmod 777 /mnt/huge ; echo "huge /mnt/huge hugetlbfs defaults 0 0" >> /etc/fstab )
