#!/bin/bash
OVS_VER=$1

OVS_INSTALL=/root/$OVS_VER

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
#mkdir -p /usr/local/etc/openvswitch
mkdir -p /usr/local/var/run/openvswitch
mkdir -p /etc/openvswitch
rm /usr/local/etc/openvswitch/conf.db

ovsdb-tool create /etc/openvswitch/conf.db $OVS_INSTALL/vswitchd/vswitch.ovsschema

echo "3 - Start ovsdb-server"
export DB_SOCK=/usr/local/var/run/openvswitch/db.sock

ovsdb-server /etc/openvswitch/conf.db --remote=punix:$DB_SOCK --remote=db:Open_vSwitch,Open_vSwitch,manager_options --pidfile  --detach --log

#ovsdb-server --remote=punix:/usr/local/var/run/openvswitch/db.sock \
#         --remote=db:Open_vSwitch,Open_vSwitch,manager_options \
#         --pidfile --detach
ovs-vsctl --no-wait init

sleep 5

echo "4 - Start ovs-vswitchd"

ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-hugepage-dir="/mnt/huge"
ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-init=true
sock=$(lscpu | grep Socket | grep -o [0-9])
if [[ $sock == "1" ]]
then 
  echo "1"
  ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-socket-mem="2048"
else
  echo "2"
  ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-socket-mem="2048","2048"
fi
read -p
ovs-vsctl --no-wait set Open_vSwitch . other_config:pmd-cpu-mask=81
ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-lcore-mask=02
ovs-vswitchd unix:$DB_SOCK --pidfile --detach --log

sleep 5
#ovs-vsctl get Open_vSwitch . other_config
ovs-vsctl show


