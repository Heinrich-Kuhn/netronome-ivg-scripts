#!/bin/bash

echo "CURRENT configuration"
cat /etc/netronome.conf

cat << 'EOF' > /etc/netronome.conf
SDN_VIRTIORELAY_ENABLE=y
SDN_VIRTIORELAY_PARAM="--cpus=1,2 --enable-tso --enable-mrgbuf --vhost-username=libvirt-qemu --vhost-groupname=kvm --huge-dir=/mnt/huge --ovsdb-sock=/var/run/openvswitch/db.sock"
SDN_FIREWALL=n
EOF

echo "NEW configuration"
cat /etc/netronome.conf

ovs-ctl status
ovs-ctl stop
ovs-ctl start
ovs-ctl status
