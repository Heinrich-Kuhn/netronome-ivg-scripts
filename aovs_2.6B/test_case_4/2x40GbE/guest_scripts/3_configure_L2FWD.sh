#!/bin/bash
#2_configure_L2FWD.sh


#allocate hugepages
echo 512 > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages

export DPDK_BASE_DIR=/root

#run l2fwd
$DPDK_BASE_DIR/dpdk-l2fwd -c 0x06 -n 4 --socket-mem 1024 --proc-type auto -- -p 0x3 --no-mac-updating
