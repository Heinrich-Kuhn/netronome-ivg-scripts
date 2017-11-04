#!/bin/bash

/root/vm_scripts/1_install_prerequisites.sh || exit -1
/root/vm_scripts/3_install_build_dpdk.sh || exit -1
/root/vm_scripts/4_build_l2fwd.sh || exit -1
/root/vm_scripts/5_build_pktgen.sh || exit -1
#/root/vm_scripts/6_install_iperf3.sh || exit -1
#/root/vm_scripts/7_install_netperf.sh || exit -1
#/root/vm_scripts/8_build_moongen.sh || exit -1
/root/vm_scripts/09_setup-hugepages.sh || exit -1
/root/vm_scripts/10_update_centos_vm.sh || exit -1

# Use this keyword to identify when the VM has spawned and the
# scripts have successfully logged into the VM.
echo "WELCOME" > /etc/motd

exit 0
