#!/bin/bash

export DPDK_BASE_DIR=/root
export DPDK_VERSION=dpdk-stable-16.11.3
export DPDK_TARGET=x86_64-native-linuxapp-gcc

cd $DPDK_BASE_DIR/$DPDK_VERSION/examples/l2fwd
sed 's/#define RTE_TEST_RX_DESC_DEFAULT 128/#define RTE_TEST_RX_DESC_DEFAULT 1024/' -i main.c
sed 's/#define RTE_TEST_TX_DESC_DEFAULT 512/#define RTE_TEST_TX_DESC_DEFAULT 1024/' -i main.c
sed -E 's/(#define NB_MBUF   )8192/\116384/g' -i main.c

make RTE_SDK=$DPDK_BASE_DIR/$DPDK_VERSION 

rm -f $DPDK_BASE_DIR/dpdk-l2fwd
ln -s $DPDK_BASE_DIR/$DPDK_VERSION/examples/l2fwd/build/app/l2fwd $DPDK_BASE_DIR/dpdk-l2fwd
