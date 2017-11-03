#!/bin/bash

./1_install_prerequisites.sh || exit -1
./3_install_build_dpdk.sh || exit -1
./4_build_l2fwd.sh || exit -1
./5_build_pktgen.sh || exit -1
#./6_install_iperf3.sh || exit -1
#./7_install_netperf.sh || exit -1
#./8_build_moongen.sh || exit -1
./09_setup-hugepages.sh || exit -1

exit 0
