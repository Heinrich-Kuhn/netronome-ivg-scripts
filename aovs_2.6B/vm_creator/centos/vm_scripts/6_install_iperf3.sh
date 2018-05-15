#!/bin/bash

exit 0

#   NOTICE  -  NOT YET IMPLEMENTED FOR CentOS

wget https://iperf.fr/download/ubuntu/libiperf0_3.1.3-1_amd64.deb \
    || exit -1
dpkg -i libiperf0_3.1.3-1_amd64.deb \
    || exit -1

wget https://iperf.fr/download/ubuntu/iperf3_3.1.3-1_amd64.deb \
    || exit -1
dpkg -i iperf3_3.1.3-1_amd64.deb \
    || exit -1

exit 0
