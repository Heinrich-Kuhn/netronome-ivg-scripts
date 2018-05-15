#!/bin/bash

echo "Installing Intel driver - i40e"

rm -rf /usr/local/src/i40e
wget https://github.com/netronome-support/IVG/raw/master/aovs_2.6B/test_case_13_dpdk_ovs_vxlan_uni_intel/i40e-2.1.26.tar.gz -P /usr/local/src/i40e
cd /usr/local/src/i40e

tar zxf i40e*.tar.gz
cd i40e*/src
make install
rmmod i40e
modprobe i40e

exit 0
