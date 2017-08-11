#!/bin/bash


BRIDGE=br0

ovs-ofctl del-flows $BRIDGE
ovs-ofctl add-flow $BRIDGE arp,actions=normal
ovs-ofctl add-flow $BRIDGE ip,actions=normal
