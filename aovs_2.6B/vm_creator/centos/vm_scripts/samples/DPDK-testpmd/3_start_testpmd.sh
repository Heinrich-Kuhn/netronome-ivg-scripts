#!/bin/bash

DPDK_VERSION=dpdk-17.05

DIRECTORY=$HOME/$DPDK_VERSION/x86_64-native-linuxapp-gcc/app

pkill testpmd -9

ln -s $DIRECTORY/testpmd $HOME

cd

./testpmd -w 0000:00:0a.0 -w 0000:00:0b.0 -- --portmask 0x3 --disable-rss --disable-hw-vlan-filter --auto-start
