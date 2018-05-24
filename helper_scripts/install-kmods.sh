#!/bin/bash

cd /opt
git clone https://github.com/Netronome/nfp-drv-kmods
cd nfp-drv-kmods
make install

sleep 2

lsmod | grep -E '^nfp\s' > /dev/null
if [ $? -eq 0 ]; then
    echo "Remove kernel module 'nfp'"
    rmmod nfp \
        || exit -1
fi

depmod -a
modprobe nfp
modinfo nfp

exit 0
