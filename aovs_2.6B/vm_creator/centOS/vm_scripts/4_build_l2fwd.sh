#!/bin/bash

. /etc/dpdk.conf || exit -1

cd $RTE_SDK/examples/l2fwd \
    || exit -1

ss=""
ss="${ss}s/^(#define RTE_TEST_RX_DESC_DEFAULT)\s.*$/\1 1024/;"
ss="${ss}s/^(#define RTE_TEST_RTX_DESC_DEFAULT)\s.*$/\1 1024/;"
ss="${ss}s/^(#define NB_MBUF)\s.*$/\1 16384/;"

sed -r "$ss" -i $RTE_SDK/examples/l2fwd/main.c \
    || exit -1

make || exit -1

if [ -f $RTE_SDK/dpdk-l2fwd ]; then
    rm -f $RTE_SDK/dpdk-l2fwd
fi

ln -s $RTE_SDK/examples/l2fwd/build/app/l2fwd $RTE_SDK/dpdk-l2fwd \
    || exit -1

exit 0
