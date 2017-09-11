#!/bin/bash
#2_configure_L2FWD.sh

./1_configure_hugepages.sh
./2_auto_bind_igb_uio.sh

export DPDK_BASE_DIR=/root

#run l2fwd
$DPDK_BASE_DIR/dpdk-l2fwd -c 0x06 -n 4 --socket-mem 1024 --proc-type auto -- -p 0x3 --no-mac-updating
