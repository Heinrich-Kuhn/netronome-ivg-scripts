#!/bin/bash


OVS_INSTALL=/root/ovs-dpdk/openvswitch-2.6.1

echo "1 - Exit applications"
ovs-appctl -t ovs-vswitchd exit
ovs-appctl -t ovsdb-server exit

sleep 5

pkill ovsdb-server
pkill ovs-vswitchd
killall ovsdb-server ovs-vswitchd

sleep 5

echo "2 - Recreate database"
#rm -f /etc/openvswitch/conf.db
#ovsdb-tool create /etc/openvswitch/conf.db $OVS_INSTALL/vswitchd/vswitch.ovsschema
mkdir -p /usr/local/etc/openvswitch
mkdir -p /usr/local/var/run/openvswitch
rm /usr/local/etc/openvswitch/conf.db
ovsdb-tool create /usr/local/etc/openvswitch/conf.db  \
  /usr/local/share/openvswitch/vswitch.ovsschema

echo "3 - Start ovsdb-server"
#ovsdb-server /etc/openvswitch/conf.db --remote=punix:$DB_SOCK --remote=db:Open_vSwitch,Open_vSwitch,manager_options --pidfile  --detach --log
ovsdb-server --remote=punix:/usr/local/var/run/openvswitch/db.sock \
         --remote=db:Open_vSwitch,Open_vSwitch,manager_options \
         --pidfile --detach
ovs-vsctl --no-wait init

sleep 5

echo "4 - Start ovs-vswitchd"
export DB_SOCK=/usr/local/var/run/openvswitch/db.sock
ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-hugepage-dir="/mnt/huge"
ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-init=true
ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-socket-mem="2048,2048"
ovs-vsctl --no-wait set Open_vSwitch . other_config:pmd-cpu-mask=1e
#ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-lcore-mask=18
ovs-vswitchd unix:$DB_SOCK --pidfile --detach --log

sleep 5
#ovs-vsctl get Open_vSwitch . other_config
#ovs-vsctl show


