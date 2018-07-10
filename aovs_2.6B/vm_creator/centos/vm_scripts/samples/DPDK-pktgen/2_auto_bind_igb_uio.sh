#!/bin/bash

. /etc/dpdk.conf || exit -1

if [ ! -d "$RTE_SDK" ]; then
    echo "ERROR: DPDK was not properly installed"
    exit -1
fi

lspci | grep 01:
if [ $? = 1 ]; then
    BDF_LIST=$(lspci -d 19ee: | awk '{print $1}')
else
    BDF_LIST=$(lspci | grep 01: | awk '{print $1}')
fi

DPDK_DEVBIND="$RTE_SDK/tools/dpdk-devbind.py"

DRIVER=igb_uio
modprobe $DRIVER || exit -1

for bdf in ${BDF_LIST[@]} ; do
    $DPDK_DEVBIND --bind $DRIVER $bdf \
        || exit -1
done

exit 0
