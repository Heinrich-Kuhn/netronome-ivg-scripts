#!/bin/bash
#Setup OVS Open Flow rules

script_dir="$(dirname $(readlink -f $0))"

COUNT=$1
PORT1=$2
PORT2=$3
BRIDGE=$4

cfgfile="$script_dir/ovs_rules.cfg"
new_file="$script_dir/edited_rules.cfg"

if [[ $COUNT -gt 64000 ]]; then
        COUNT=64000
fi

cut_lines="$COUNT"
echo $cut_lines

head -$cut_lines $cfgfile > $new_file

sleep 1

sed -i -e "s/p1/$PORT1/g" $new_file
sed -i -e "s/p2/$PORT2/g" $new_file

sleep 1

ovs-ofctl -O Openflow13 replace-flows --bundle $BRIDGE $new_file

sleep 1

ovs-ofctl -O Openflow13 add-flow $BRIDGE dl_type=0x0806,actions=NORMAL

ovs-ofctl -O Openflow13 add-flow $BRIDGE in_port=$PORT1,actions=1
ovs-ofctl -O Openflow13 add-flow $BRIDGE in_port=$PORT2,actions=1
