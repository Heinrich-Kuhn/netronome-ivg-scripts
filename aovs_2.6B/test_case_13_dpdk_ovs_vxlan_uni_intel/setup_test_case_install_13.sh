#!/bin/bash

script_dir="$(dirname $(readlink -f $0))"

$script_dir/0_uninstall_aovs.sh
$script_dir/1_install_dpdk.sh
$script_dir/2_install_dpdk_ovs.sh

if [ $? == 1 ]; then 
echo "Could not install DPDK OVS"
exit -1
fi

$script_dir/3_install_intel.sh

if [ $? == 1 ]; then 
echo "Could not install Intel driver"
exit -1
fi

echo "DONE(setup_test_case_13_install.sh)"

exit 0

