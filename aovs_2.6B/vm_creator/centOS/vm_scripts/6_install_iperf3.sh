#!/bin/bash

wget https://iperf.fr/download/ubuntu/libiperf0_3.1.3-1_amd64.deb
dpkg -i libiperf0_3.1.3-1_amd64.deb
sleep 1

wget https://iperf.fr/download/ubuntu/iperf3_3.1.3-1_amd64.deb
dpkg -i iperf3_3.1.3-1_amd64.deb
sleep 1