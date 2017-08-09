#!bin/bash
#package_install.sh

dpkg -i agilio-ovs*_2.6.A.*_amd64.deb \
    agilio-ovs*-common_2.6.A.*_amd64.deb \
    agilio-ovs-trivial_2.6.A.*_amd64.deb \
    igb-uio-dkms_*_amd64.deb \
    nfp-bsp-6000-b0-2017.02_*_amd64.deb \
    nfp-bsp-6000-b0-2017.02-dkms_*_all.deb \
    nfp-cmsg-dkms_*_amd64.deb nfp-fallback-dkms_*_amd64.deb \
    nfp-conntrack-dkms_*_amd64.deb nfp-offloads-dkms_*_amd64.deb \
    openvswitch-common_2.6.1*agilio2.6.A.*_amd64.deb \
    openvswitch-datapath-dkms_2.6.1*agilio2.6.A.*_all.deb \
    openvswitch-switch_2.6.1*agilio2.6.A.*_amd64.deb \
    netronome-dpdk_16.11.*_amd64.deb \
    virtiorelayd_2.6.A.*_amd64.deb
