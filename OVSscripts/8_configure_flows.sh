#!/bin/bash

BRIDGE=br-fo

ovs-ofctl del-flows br-fo
ovs-ofctl -O OpenFlow13 add-flow $BRIDGE in_port=1,actions=output:2
ovs-ofctl -O OpenFlow13 add-flow $BRIDGE in_port=2,actions=output:1
