#!/bin/bash
IVG_dir="/root/IVG_folder"
script_dir="$(dirname $(readlink -f $0))"
DPDK_VER=$1
OVS_VER=$2

$script_dir/0_uninstall_aovs.sh
#$script_dir/1_install_dpdk.sh
$IVG_dir/helper_scripts/install-dpdk.sh $DPDK_VER
$script_dir/2_install_dpdk_ovs.sh $DPDK_VER $OVS_VER

if [ $? == 1 ]; then 
echo "Could not install DPDK OVS"
exit -1
fi

$script_dir/3_install_intel.sh 

if [ $? == 1 ]; then 
echo "Could not install Intel driver"
exit -1
fi

echo "DONE(setup_test_case_12_install.sh)"

exit 0

