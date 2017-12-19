#!/bin/bash

/root/vm_scripts/1_install_prerequisites.sh || exit -1
/root/vm_scripts/3_install_build_dpdk.sh
/root/vm_scripts/4_build_l2fwd.sh
/root/vm_scripts/5_build_pktgen.sh
#/root/vm_scripts/6_install_iperf3.sh
#/root/vm_scripts/7_install_netperf.sh
#/root/vm_scripts/8_build_moongen.sh
/root/vm_scripts/11_install_nfp_drv_kmods.sh || exit -1

sed -i '/exit 0/d' /etc/rc.local
echo "/vm_scripts/samples/2_auto_bind_igb_uio.sh || exit 1" >> /etc/rc.local
echo "exit 0" >> /etc/rc.local

# Use this keyword to identify when the VM has spawned and the
# scripts have successfully logged into the VM.
echo "WELCOME" > /etc/motd

exit 0
