#!/bin/bash

/root/vm_scripts/1_install_prerequisites.sh
/root/vm_scripts/2_install_build_dpdk.sh
/root/vm_scripts/3_build_l2fwd.sh
/root/vm_scripts/4_build_pktgen.sh
/root/vm_scripts/5_install_iperf3.sh
/root/vm_scripts/6_install_netperf.sh
#/root/vm_scripts/7_build_moongen.sh
