#!/bin/bash

export DPDK_BASE_DIR=/root/
export DPDK_VERSION=dpdk-16.11

cd $DPDK_BASE_DIR/$DPDK_VERSION/examples/l2fwd
sed 's/#define RTE_TEST_RX_DESC_DEFAULT 128/#define RTE_TEST_RX_DESC_DEFAULT 1024/' -i main.c
sed 's/#define RTE_TEST_TX_DESC_DEFAULT 512/#define RTE_TEST_TX_DESC_DEFAULT 1024/' -i main.c

make RTE_SDK=$DPDK_BASE_DIR/$DPDK_VERSION
ln -s $DPDK_BASE_DIR/$DPDK_VERSION/examples/l2fwd/build/app/l2fwd  /root/dpdk-l2fwd
