#!/bin/bash

cd /opt
git clone https://github.com/Netronome/nfp-drv-kmods
cd nfp-drv-kmods
make install

sleep 2

rmmod nfp
depmod -a
modprobe nfp
modinfo nfp